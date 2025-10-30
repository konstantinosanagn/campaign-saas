// useLeads.test.tsx
import React from 'react'
import { render, screen, waitFor, act } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

// IMPORTANT: mock the apiClient module used by the hook
jest.mock('@/libs/utils/apiClient', () => ({
  __esModule: true,
  default: {
    index: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    destroy: jest.fn(),
  },
}))

import apiClient from '@/libs/utils/apiClient'
import { useLeads } from '../useLeads'
import type { Lead } from '@/types'

const indexMock = apiClient.index as jest.Mock
const createMock = apiClient.create as jest.Mock
const updateMock = apiClient.update as jest.Mock
const destroyMock = apiClient.destroy as jest.Mock

// A tiny harness to consume the hook and expose state + actions for assertions
function HookHarness({
  children,
}: {
  children: (api: ReturnType<typeof useLeads>) => React.ReactNode
}) {
  const api = useLeads()
  return <>{children(api)}</>
}

function renderHookUI(renderFn: (api: ReturnType<typeof useLeads>) => React.ReactNode) {
  return render(
    <HookHarness>
      {(api) => (
        <div>
          {/* Render state in DOM for assertions */}
          <div data-testid="leads">{JSON.stringify(api.leads)}</div>
          <div data-testid="loading">{String(api.loading)}</div>
          <div data-testid="error">{api.error ?? ''}</div>

          {/* Buttons to invoke actions */}
          <button onClick={() => api.refreshLeads?.()}>refresh</button>
          <button
            onClick={() =>
              api.createLead({
                name: 'Test Lead',
                email: 'test@example.com',
                title: 'Manager',
                company: 'Test Company',
                website: 'https://test.com',
                campaignId: 1,
              })
            }
          >
            create
          </button>
          <button
            onClick={() =>
              api.updateLead(1, {
                name: 'Updated Lead',
                email: 'updated@example.com',
                title: 'Senior Manager',
                company: 'Updated Company',
                website: 'https://updated.com',
              })
            }
          >
            update
          </button>
          <button onClick={() => api.deleteLeads([1, 2])}>delete</button>

          {/* Allow test to do custom interactions too */}
          {renderFn(api)}
        </div>
      )}
    </HookHarness>
  )
}

describe('useLeads', () => {
  const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

  beforeEach(() => {
    jest.clearAllMocks()
    window.confirm = jest.fn(() => true)
  })

  afterAll(() => {
    consoleErrorSpy.mockRestore()
  })

  const readState = () => {
    const leads = JSON.parse(screen.getByTestId('leads').textContent || '[]') as Lead[]
    const loading = screen.getByTestId('loading').textContent === 'true'
    const error = screen.getByTestId('error').textContent || ''
    return { leads, loading, error }
  }

  it('initializes with empty leads and loading state', async () => {
    indexMock.mockResolvedValueOnce({
      data: [],
      status: 200,
    })

    renderHookUI(() => null)

    // At first render effect starts -> loading true
    expect(readState().loading).toBe(true)

    await waitFor(() => {
      const { leads, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(leads).toEqual([])
    })

    expect(indexMock).toHaveBeenCalledWith('leads')
  })

  it('loads leads on mount', async () => {
    const mockLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
    ]

    indexMock.mockResolvedValueOnce({
      data: mockLeads,
      status: 200,
    })

    renderHookUI(() => null)

    await waitFor(() => {
      const { leads, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(leads).toEqual(mockLeads)
    })

    expect(indexMock).toHaveBeenCalledWith('leads')
  })

  it('handles error when loading leads fails', async () => {
    indexMock.mockResolvedValueOnce({
      error: 'Failed to load leads',
    })

    renderHookUI(() => null)

    await waitFor(() => {
      const { leads, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('Failed to load leads')
      expect(leads).toEqual([])
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Failed to load leads:',
      'Failed to load leads'
    )
  })

  it('handles exception when loading leads', async () => {
    indexMock.mockRejectedValueOnce(new Error('Network error'))

    renderHookUI(() => null)

    await waitFor(() => {
      const { leads, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('Network error')
      expect(leads).toEqual([])
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error loading leads:',
      expect.any(Error)
    )
  })

  it('creates lead successfully', async () => {
    // initial load
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    // create success
    createMock.mockResolvedValueOnce({
      data: {
        id: 1,
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
        stage: 'queued',
        quality: null,
      },
      status: 201,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createLead({
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
      })
    })

    expect(result).toBe(true)

    expect(createMock).toHaveBeenCalledWith('leads', {
      name: 'Test Lead',
      email: 'test@example.com',
      title: 'Manager',
      company: 'Test Company',
      website: 'https://test.com',
      stage: 'queued',
      quality: '-',
      campaignId: 1,
    })

    // state updated
    expect(readState().leads).toHaveLength(1)
    expect(readState().error).toBe('')
  })

  it('generates website from email when creating lead', async () => {
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    createMock.mockResolvedValueOnce({
      data: {
        id: 1,
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: null,
      },
      status: 201,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    await act(async () => {
      await apiRef.createLead({
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: '',
        campaignId: 1,
      })
    })

    expect(createMock).toHaveBeenCalledWith('leads', {
      name: 'Test Lead',
      email: 'test@example.com',
      title: 'Manager',
      company: 'Test Company',
      website: 'https://example.com',
      stage: 'queued',
      quality: '-',
      campaignId: 1,
    })
  })

  it('handles email without @ symbol when creating lead', async () => {
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    createMock.mockResolvedValueOnce({
      data: {
        id: 1,
        name: 'Test Lead',
        email: 'invalid-email',
        title: 'Manager',
        company: 'Test Company',
        website: '',
        campaignId: 1,
        stage: 'queued',
        quality: null,
      },
      status: 201,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    await act(async () => {
      await apiRef.createLead({
        name: 'Test Lead',
        email: 'invalid-email',
        title: 'Manager',
        company: 'Test Company',
        website: '',
        campaignId: 1,
      })
    })

    expect(createMock).toHaveBeenCalledWith('leads', {
      lead: {
        name: 'Test Lead',
        email: 'invalid-email',
        title: 'Manager',
        company: 'Test Company',
        website: '',
        campaignId: 1,
      },
    })
  })

  it('handles error when creating lead fails', async () => {
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    createMock.mockResolvedValueOnce({
      error: 'Validation failed',
      errors: ['Email is invalid'],
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createLead({
        name: 'Test Lead',
        email: 'invalid',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
      })
    })

    expect(result).toBe(false)

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Failed to create lead:',
      'Validation failed'
    )
  })

  it('handles creation error without errors array', async () => {
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    createMock.mockResolvedValueOnce({
      error: 'Server error',
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createLead({
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
      })
    })

    expect(result).toEqual({
      success: false,
      error: 'Server error',
      errors: [],
    })
  })

  it('handles exception when creating lead', async () => {
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    createMock.mockRejectedValueOnce(new Error('Network error'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createLead({
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
      })
    })

    expect(result).toEqual({
      success: false,
      error: 'Network error',
      errors: [],
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error creating lead:',
      expect.any(Error)
    )
  })

  it('handles null data when creating lead', async () => {
    indexMock.mockResolvedValueOnce({ data: [], status: 200 })
    createMock.mockResolvedValueOnce({
      data: null,
      status: 201,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createLead({
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Manager',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
      })
    })

    expect(result).toEqual({
      success: false,
      error: 'No data returned from server',
      errors: [],
    })
  })

  it('updates lead successfully', async () => {
    const existingLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    }

    indexMock.mockResolvedValueOnce({ data: [existingLead], status: 200 })
    updateMock.mockResolvedValueOnce({
      data: {
        ...existingLead,
        name: 'Updated Lead',
        email: 'updated@example.com',
      },
      status: 200,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateLead(1, {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: 'https://updated.com',
      })
    })

    expect(result).toEqual({
      success: true,
      data: {
        ...existingLead,
        name: 'Updated Lead',
        email: 'updated@example.com',
      },
    })

    expect(updateMock).toHaveBeenCalledWith('leads/1', {
      lead: {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: 'https://updated.com',
      },
    })

    // state updated
    expect(readState().leads[0].name).toBe('Updated Lead')
    expect(readState().error).toBe('')
  })

  it('generates website from email when updating lead', async () => {
    const existingLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    }

    indexMock.mockResolvedValueOnce({ data: [existingLead], status: 200 })
    updateMock.mockResolvedValueOnce({
      data: { ...existingLead, website: 'https://example.com' },
      status: 200,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    await act(async () => {
      await apiRef.updateLead(1, {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: '',
      })
    })

    expect(updateMock).toHaveBeenCalledWith('leads/1', {
      lead: {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: 'https://example.com',
      },
    })
  })

  it('handles error when updating lead fails', async () => {
    const existingLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    }

    indexMock.mockResolvedValueOnce({ data: [existingLead], status: 200 })
    updateMock.mockResolvedValueOnce({
      error: 'Update failed',
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateLead(1, {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: 'https://updated.com',
      })
    })

    expect(result).toEqual({
      success: false,
      error: 'Update failed',
      errors: [],
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Failed to update lead:',
      'Update failed'
    )
  })

  it('handles exception when updating lead', async () => {
    const existingLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    }

    indexMock.mockResolvedValueOnce({ data: [existingLead], status: 200 })
    updateMock.mockRejectedValueOnce(new Error('Network error'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateLead(1, {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: 'https://updated.com',
      })
    })

    expect(result).toEqual({
      success: false,
      error: 'Network error',
      errors: [],
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error updating lead:',
      expect.any(Error)
    )
  })

  it('handles null data when updating lead', async () => {
    const existingLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    }

    indexMock.mockResolvedValueOnce({ data: [existingLead], status: 200 })
    updateMock.mockResolvedValueOnce({
      data: null,
      status: 200,
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateLead(1, {
        name: 'Updated Lead',
        email: 'updated@example.com',
        title: 'Senior VP',
        company: 'Updated Company',
        website: 'https://updated.com',
      })
    })

    expect(result).toEqual({
      success: false,
      error: 'No data returned from server',
      errors: [],
    })
  })

  it('deletes leads successfully', async () => {
    const existingLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
      {
        id: 2,
        name: 'Jane Smith',
        email: 'jane@example.com',
        title: 'Manager',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'B',
      },
    ]

    indexMock.mockResolvedValueOnce({ data: existingLeads, status: 200 })
    destroyMock.mockResolvedValueOnce({ status: 204 })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteLeads([1, 2])
    })

    expect(result).toEqual({
      success: true,
      deletedIds: [1, 2],
    })

    expect(destroyMock).toHaveBeenCalledWith('leads/1')
    expect(destroyMock).toHaveBeenCalledWith('leads/2')

    // state updated - leads removed
    expect(readState().leads).toHaveLength(0)
    expect(readState().error).toBe('')
  })

  it('handles cancel when deleting leads', async () => {
    const existingLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
    ]

    indexMock.mockResolvedValueOnce({ data: existingLeads, status: 200 })
    ;(window.confirm as jest.Mock).mockReturnValueOnce(false)

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteLeads([1])
    })

    expect(result).toEqual({
      success: false,
      error: 'Deletion cancelled by user',
      deletedIds: [],
    })

    expect(destroyMock).not.toHaveBeenCalled()
    expect(readState().leads).toHaveLength(1)
  })

  it('handles partial failure when deleting leads', async () => {
    const existingLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
      {
        id: 2,
        name: 'Jane Smith',
        email: 'jane@example.com',
        title: 'Manager',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'B',
      },
    ]

    indexMock.mockResolvedValueOnce({ data: existingLeads, status: 200 })
    destroyMock
      .mockResolvedValueOnce({ status: 204 })
      .mockResolvedValueOnce({ error: 'Failed to delete lead 2' })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteLeads([1, 2])
    })

    expect(result).toEqual({
      success: false,
      error: 'Some leads could not be deleted',
      deletedIds: [1],
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Failed to delete lead 2:',
      'Failed to delete lead 2'
    )

    // Only lead 1 should be removed
    expect(readState().leads).toHaveLength(1)
    expect(readState().leads[0].id).toBe(2)
  })

  it('handles exception when deleting leads', async () => {
    const existingLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
    ]

    indexMock.mockResolvedValueOnce({ data: existingLeads, status: 200 })
    destroyMock.mockRejectedValueOnce(new Error('Network error'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteLeads([1])
    })

    expect(result).toEqual({
      success: false,
      error: 'Network error',
      deletedIds: [],
    })

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error deleting lead 1:',
      expect.any(Error)
    )
  })

  it('finds lead by ID', async () => {
    const mockLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
      {
        id: 2,
        name: 'Jane Smith',
        email: 'jane@example.com',
        title: 'Manager',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'B',
      },
    ]

    indexMock.mockResolvedValueOnce({ data: mockLeads, status: 200 })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const lead = apiRef.findLeadById(2)
    expect(lead).toEqual(mockLeads[1])

    const notFound = apiRef.findLeadById(999)
    expect(notFound).toBeUndefined()
  })

  it('provides refreshLeads method that reloads leads', async () => {
    const initialLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'A',
      },
    ]

    const updatedLeads: Lead[] = [
      ...initialLeads,
      {
        id: 2,
        name: 'Jane Smith',
        email: 'jane@example.com',
        title: 'Manager',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 1,
        stage: 'queued',
        quality: 'B',
      },
    ]

    indexMock
      .mockResolvedValueOnce({ data: initialLeads, status: 200 })
      .mockResolvedValueOnce({ data: updatedLeads, status: 200 })

    renderHookUI(() => null)

    await waitFor(() => expect(readState().loading).toBe(false))
    expect(readState().leads).toHaveLength(1)

    await act(async () => {
      await userEvent.click(screen.getByText('refresh'))
    })

    await waitFor(() => {
      expect(readState().leads).toHaveLength(2)
    })

    expect(indexMock).toHaveBeenCalledTimes(2)
  })

  it('handles null data when loading leads', async () => {
    indexMock.mockResolvedValueOnce({
      data: null,
      status: 200,
    })

    renderHookUI(() => null)

    await waitFor(() => {
      const { leads, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(leads).toEqual([])
    })
  })
})
