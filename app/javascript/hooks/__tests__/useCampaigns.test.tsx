// useCampaigns.test.tsx
import React from 'react'
import { render, screen, waitFor, act } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

// Mock the apiClient used by the hook
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
import { useCampaigns } from '../useCampaigns'
import type { Campaign } from '@/types'

const indexMock = apiClient.index as jest.Mock
const createMock = apiClient.create as jest.Mock
const updateMock = apiClient.update as jest.Mock
const destroyMock = apiClient.destroy as jest.Mock

function Harness({
  children,
}: {
  children: (api: ReturnType<typeof useCampaigns>) => React.ReactNode
}) {
  const api = useCampaigns()
  return <>{children(api)}</>
}

function renderHookUI(
  renderFn: (api: ReturnType<typeof useCampaigns>) => React.ReactNode = () => null
) {
  return render(
    <Harness>
      {(api) => (
        <div>
          <div data-testid="campaigns">{JSON.stringify(api.campaigns)}</div>
          <div data-testid="loading">{String(api.loading)}</div>
          <div data-testid="error">{api.error ?? ''}</div>
          <button onClick={() => api.refreshCampaigns?.()}>refresh</button>
          <button
            onClick={() =>
              api.createCampaign({
                title: 'Test Campaign',
                tone: 'professional',
                persona: 'founder',
                primaryGoal: 'book_call',
              })
            }
          >
            create
          </button>
          <button
            onClick={() =>
              api.updateCampaign(0, {
                title: 'Updated Campaign',
                tone: 'professional',
                persona: 'founder',
                primaryGoal: 'book_call',
              })
            }
          >
            update
          </button>
          <button onClick={() => api.deleteCampaign(0)}>delete</button>
          {renderFn(api)}
        </div>
      )}
    </Harness>
  )
}

describe('useCampaigns', () => {
  const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
  
  // Helper for default sharedSettings
  const defaultSharedSettings = {
    brand_voice: {
      tone: 'professional',
      persona: 'founder',
    },
    primary_goal: 'book_call',
  }

  beforeEach(() => {
    jest.clearAllMocks()
    window.confirm = jest.fn(() => true)
  })

  afterAll(() => {
    consoleErrorSpy.mockRestore()
  })

  const readState = () => {
    const campaigns = JSON.parse(screen.getByTestId('campaigns').textContent || '[]') as Campaign[]
    const loading = screen.getByTestId('loading').textContent === 'true'
    const error = screen.getByTestId('error').textContent || ''
    return { campaigns, loading, error }
  }

  // ---------- LOAD / MOUNT ----------
  it('loads campaigns on mount: success with data', async () => {
    indexMock.mockResolvedValueOnce({
      data: [{ id: 1, title: 'Campaign 1', sharedSettings: defaultSharedSettings }],
    })

    renderHookUI()

    expect(readState().loading).toBe(true)

    await waitFor(() => {
      const { campaigns, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(campaigns).toHaveLength(1)
      expect(campaigns[0].title).toBe('Campaign 1')
    })
    expect(indexMock).toHaveBeenCalledWith('campaigns')
  })

  it('loads campaigns on mount: success with undefined data → fallback empty', async () => {
    indexMock.mockResolvedValueOnce({ data: undefined })

    renderHookUI()

    await waitFor(() => {
      const { campaigns, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(campaigns).toEqual([])
    })
  })

  it('loads campaigns on mount: response.error branch', async () => {
    indexMock.mockResolvedValueOnce({ error: 'boom-load' })

    renderHookUI()

    await waitFor(() => {
      const { campaigns, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('boom-load')
      expect(campaigns).toEqual([])
    })
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to load campaigns:', 'boom-load')
  })

  it('loads campaigns on mount: Error exception branch', async () => {
    indexMock.mockRejectedValueOnce(new Error('network down'))

    renderHookUI()

    await waitFor(() => {
      const { loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('network down')
    })
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error loading campaigns:',
      expect.any(Error)
    )
  })

  it('loads campaigns on mount: non-Error exception branch', async () => {
    indexMock.mockRejectedValueOnce('weird string')

    renderHookUI()

    await waitFor(() => {
      const { loading, error } = readState()
      // hook uses default message in non-Error case
      expect(error).toBe('Failed to load campaigns')
    })
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error loading campaigns:', 'weird string')
  })

  // ---------- REFRESH ----------
  it('refreshCampaigns: re-fetches and updates state', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
    indexMock.mockResolvedValueOnce({
      data: [{ id: 1, title: 'Campaign 1', sharedSettings: defaultSharedSettings }],
    })

    renderHookUI()

    await waitFor(() => expect(readState().loading).toBe(false))
    expect(readState().campaigns).toEqual([])

    await act(async () => {
      await userEvent.click(screen.getByText('refresh'))
    })

    await waitFor(() => {
      expect(readState().campaigns).toHaveLength(1)
    })

    expect(indexMock).toHaveBeenNthCalledWith(1, 'campaigns')
    expect(indexMock).toHaveBeenNthCalledWith(2, 'campaigns')
  })

  // ---------- CREATE ----------
  it('createCampaign: success with returned data → updates state, returns campaign', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
    createMock.mockResolvedValueOnce({
      data: { id: 1, title: 'New Campaign', sharedSettings: defaultSharedSettings },
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createCampaign({
        title: 'New Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toEqual({ id: 1, title: 'New Campaign', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } })
    expect(createMock).toHaveBeenCalledWith('campaigns', {
      title: 'New Campaign',
      sharedSettings: {
        brand_voice: {
          tone: 'professional',
          persona: 'founder',
        },
        primary_goal: 'book_call',
      },
    })
    expect(readState().campaigns).toHaveLength(1)
    expect(readState().error).toBe('')
  })

  it('createCampaign: success without data → returns null, does not change state', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
    createMock.mockResolvedValueOnce({ data: null })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createCampaign({
        title: 'New Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBeNull()
    expect(readState().campaigns).toEqual([])
  })

  it('createCampaign: response.error branch → sets error, logs, returns null', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
    createMock.mockResolvedValueOnce({
      error: 'Validation failed',
      data: { errors: ['Title is required'] },
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createCampaign({
        title: '',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBeNull()
    expect(readState().error).toBe('Title is required')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Failed to create campaign:',
      'Validation failed',
      { errors: ['Title is required'] }
    )
  })

  it('createCampaign: response.error without errors array → uses error message', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
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
      return await apiRef.createCampaign({
        title: 'New Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBeNull()
    expect(readState().error).toBe('Server error')
  })

  it('createCampaign: Error exception → sets message, logs, returns null', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
    createMock.mockRejectedValueOnce(new Error('create-crash'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createCampaign({
        title: 'New Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBeNull()
    expect(readState().error).toBe('create-crash')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error creating campaign:',
      expect.any(Error)
    )
  })

  it('createCampaign: non-Error exception → default message, logs, returns null', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })
    createMock.mockRejectedValueOnce('weird create string')

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.createCampaign({
        title: 'New Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBeNull()
    expect(readState().error).toBe('Failed to create campaign')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error creating campaign:', 'weird create string')
  })

  // ---------- UPDATE ----------
  it('updateCampaign: success with returned data → updates state, returns true', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Original Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    updateMock.mockResolvedValueOnce({
      data: { ...existingCampaign, title: 'Updated Campaign', sharedSettings: { brand_voice: { tone: 'friendly', persona: 'sales' }, primary_goal: 'demo_request' } },
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateCampaign(0, {
        title: 'Updated Campaign',
        tone: 'friendly',
        persona: 'sales',
        primaryGoal: 'demo_request',
      })
    })

    expect(result).toBe(true)
    expect(updateMock).toHaveBeenCalledWith('campaigns', 1, {
      title: 'Updated Campaign',
      sharedSettings: expect.objectContaining({
        brand_voice: expect.objectContaining({
          tone: 'friendly',
          persona: 'sales',
        }),
        primary_goal: 'demo_request',
      }),
    })
    expect(readState().campaigns[0].title).toBe('Updated Campaign')
    expect(readState().error).toBe('')
  })

  it('updateCampaign: campaign not found → sets error, returns false', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateCampaign(0, {
        title: 'Updated Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Campaign ID not found')
    expect(updateMock).not.toHaveBeenCalled()
  })

  it('updateCampaign: campaign without ID → sets error, returns false', async () => {
    const campaignWithoutId = { title: 'No ID Campaign', sharedSettings: defaultSharedSettings } as Campaign

    indexMock.mockResolvedValueOnce({ data: [campaignWithoutId] })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateCampaign(0, {
        title: 'Updated Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Campaign ID not found')
    expect(updateMock).not.toHaveBeenCalled()
  })

  it('updateCampaign: response.error branch → sets error, logs, returns false', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Original Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    updateMock.mockResolvedValueOnce({ error: 'Update failed' })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateCampaign(0, {
        title: 'Updated Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Update failed')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to update campaign:', 'Update failed')
  })

  it('updateCampaign: Error exception → sets message, logs, returns false', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Original Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    updateMock.mockRejectedValueOnce(new Error('update-crash'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateCampaign(0, {
        title: 'Updated Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('update-crash')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error updating campaign:',
      expect.any(Error)
    )
  })

  it('updateCampaign: non-Error exception → default message, logs, returns false', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Original Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    updateMock.mockRejectedValueOnce('weird update string')

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.updateCampaign(0, {
        title: 'Updated Campaign',
        tone: 'professional',
        persona: 'founder',
        primaryGoal: 'book_call',
      })
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Failed to update campaign')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error updating campaign:', 'weird update string')
  })

  // ---------- DELETE ----------
  it('deleteCampaign: success → removes campaign, returns true', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Test Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    destroyMock.mockResolvedValueOnce({})

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteCampaign(0)
    })

    expect(result).toBe(true)
    expect(destroyMock).toHaveBeenCalledWith('campaigns', 1)
    expect(readState().campaigns).toHaveLength(0)
    expect(readState().error).toBe('')
  })

  it('deleteCampaign: cancel confirmation → returns false, does not delete', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Test Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    ;(window.confirm as jest.Mock).mockReturnValueOnce(false)

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteCampaign(0)
    })

    expect(result).toBe(false)
    expect(destroyMock).not.toHaveBeenCalled()
    expect(readState().campaigns).toHaveLength(1)
  })

  it('deleteCampaign: campaign not found → sets error, returns false', async () => {
    indexMock.mockResolvedValueOnce({ data: [] })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteCampaign(0)
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Campaign ID not found')
    expect(destroyMock).not.toHaveBeenCalled()
  })

  it('deleteCampaign: response.error branch → sets error, logs, returns false', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Test Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    destroyMock.mockResolvedValueOnce({ error: 'Delete failed' })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteCampaign(0)
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Delete failed')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to delete campaign:', 'Delete failed')
    expect(readState().campaigns).toHaveLength(1)
  })

  it('deleteCampaign: Error exception → sets message, logs, returns false', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Test Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    destroyMock.mockRejectedValueOnce(new Error('delete-crash'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteCampaign(0)
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('delete-crash')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error deleting campaign:',
      expect.any(Error)
    )
    expect(readState().campaigns).toHaveLength(1)
  })

  it('deleteCampaign: non-Error exception → default message, logs, returns false', async () => {
    const existingCampaign: Campaign = {
      id: 1,
      title: 'Test Campaign',
      sharedSettings: defaultSharedSettings,
    }

    indexMock.mockResolvedValueOnce({ data: [existingCampaign] })
    destroyMock.mockRejectedValueOnce('weird delete string')

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const result = await act(async () => {
      return await apiRef.deleteCampaign(0)
    })

    expect(result).toBe(false)
    expect(readState().error).toBe('Failed to delete campaign')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error deleting campaign:', 'weird delete string')
    expect(readState().campaigns).toHaveLength(1)
  })
})
