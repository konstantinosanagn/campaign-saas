import { renderHook, act } from '@testing-library/react'
import { waitFor } from '@testing-library/dom'
import { useLeads } from '../useLeads'
import apiClient from '@/libs/utils/apiClient'
import type { Lead } from '@/types'

jest.mock('@/libs/utils/apiClient')

describe('useLeads', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    jest.useFakeTimers()
    window.confirm = jest.fn(() => true)
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  it('initializes with empty leads and loading state', () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    expect(result.current.leads).toEqual([])
    expect(result.current.loading).toBe(true)
    expect(result.current.error).toBeNull()
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
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: mockLeads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.leads).toEqual(mockLeads)
    expect(result.current.error).toBeNull()
  })

  it('handles error when loading leads fails', async () => {
    const errorMessage = 'Network error';
    (apiClient.index as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 500,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe(errorMessage)
    expect(result.current.leads).toEqual([])
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to load leads:', errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when loading leads', async () => {
    const error = new Error('Network failure');
    (apiClient.index as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe('Network failure')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error loading leads:', error)

    consoleErrorSpy.mockRestore()
  })

  it('creates lead successfully', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const newLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'example.com',
      campaignId: 1,
      stage: 'queued',
      quality: '-',
    };
    (apiClient.create as jest.Mock).mockResolvedValue({
      data: newLead,
      status: 201,
    })

    let createResult = false
    await act(async () => {
      createResult = await result.current.createLead(
        { name: 'John Doe', email: 'john@example.com', title: 'VP', company: 'Company' },
        1
      )
    })

    expect(createResult).toBe(true)
    expect(result.current.leads).toContainEqual(newLead)
    expect(result.current.error).toBeNull()
  })

  it('generates website from email when creating lead', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const newLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'example.com',
      campaignId: 1,
      stage: 'queued',
      quality: '-',
    };
    (apiClient.create as jest.Mock).mockResolvedValue({
      data: newLead,
      status: 201,
    })

    await act(async () => {
      await result.current.createLead(
        { name: 'John Doe', email: 'john@example.com', title: 'VP', company: 'Company' },
        1
      )
    })

    expect(apiClient.create).toHaveBeenCalledWith('leads', expect.objectContaining({
      website: 'example.com',
      stage: 'queued',
      quality: '-',
      campaignId: 1,
    }))
  })

  it('handles email without @ symbol when creating lead', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const newLead: Lead = {
      id: 1,
      name: 'John Doe',
      email: 'invalid-email',
      title: 'VP',
      company: 'Company',
      website: '',
      campaignId: 1,
      stage: 'queued',
      quality: '-',
    };
    (apiClient.create as jest.Mock).mockResolvedValue({
      data: newLead,
      status: 201,
    })

    await act(async () => {
      await result.current.createLead(
        { name: 'John Doe', email: 'invalid-email', title: 'VP', company: 'Company' },
        1
      )
    })

    expect(apiClient.create).toHaveBeenCalledWith('leads', expect.objectContaining({
      website: '',
    }))
  })

  it('handles error when creating lead fails', async () => {
    const errorMessage = 'Validation failed';
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 422,
      data: { errors: ['Email is required'] },
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let createResult = true
    await act(async () => {
      createResult = await result.current.createLead(
        { name: '', email: '', title: '', company: '' },
        1
      )
    })

    expect(createResult).toBe(false)
    expect(result.current.error).toBe('Email is required')
    expect(consoleErrorSpy).toHaveBeenCalled()

    consoleErrorSpy.mockRestore()
  })

  it('handles creation error without errors array', async () => {
    const errorMessage = 'Creation failed';
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 422,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let createResult = true
    await act(async () => {
      createResult = await result.current.createLead(
        { name: 'John', email: 'john@example.com', title: 'VP', company: 'Company' },
        1
      )
    })

    expect(createResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when creating lead', async () => {
    const error = new Error('Create exception');
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let createResult = true
    await act(async () => {
      createResult = await result.current.createLead(
        { name: 'John', email: 'john@example.com', title: 'VP', company: 'Company' },
        1
      )
    })

    expect(createResult).toBe(false)
    expect(result.current.error).toBe('Create exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error creating lead:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles null data when creating lead', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockResolvedValue({
      data: null,
      status: 201,
    })

    let createResult = false
    await act(async () => {
      createResult = await result.current.createLead(
        { name: 'John', email: 'john@example.com', title: 'VP', company: 'Company' },
        1
      )
    })

    expect(createResult).toBe(true)
    // Lead should not be added when data is null
  })

  it('updates lead successfully', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const updatedLead: Lead = {
      id: 1,
      name: 'Jane Doe',
      email: 'jane@example.com',
      title: 'CEO',
      company: 'New Company',
      website: 'example.com',
      campaignId: 1,
      stage: 'queued',
      quality: '-',
    };
    (apiClient.update as jest.Mock).mockResolvedValue({
      data: updatedLead,
      status: 200,
    })

    let updateResult = false
    await act(async () => {
      updateResult = await result.current.updateLead(1, {
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'New Company',
      })
    })

    expect(updateResult).toBe(true)
    expect(result.current.leads[0]).toEqual(updatedLead)
    expect(result.current.error).toBeNull()
  })

  it('generates website from email when updating lead', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const updatedLead: Lead = {
      id: 1,
      name: 'Jane Doe',
      email: 'jane@newcompany.com',
      title: 'CEO',
      company: 'New Company',
      website: 'newcompany.com',
      campaignId: 1,
      stage: 'queued',
      quality: '-',
    };
    (apiClient.update as jest.Mock).mockResolvedValue({
      data: updatedLead,
      status: 200,
    })

    await act(async () => {
      await result.current.updateLead(1, {
        name: 'Jane Doe',
        email: 'jane@newcompany.com',
        title: 'CEO',
        company: 'New Company',
      })
    })

    expect(apiClient.update).toHaveBeenCalledWith('leads', 1, expect.objectContaining({
      website: 'newcompany.com',
    }))
  })

  it('handles error when updating lead fails', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.update as jest.Mock).mockResolvedValue({
      error: 'Update failed',
      status: 422,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let updateResult = true
    await act(async () => {
      updateResult = await result.current.updateLead(1, {
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'New Company',
      })
    })

    expect(updateResult).toBe(false)
    expect(result.current.error).toBe('Update failed')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to update lead:', 'Update failed')

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when updating lead', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const error = new Error('Update exception');
    (apiClient.update as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let updateResult = true
    await act(async () => {
      updateResult = await result.current.updateLead(1, {
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'New Company',
      })
    })

    expect(updateResult).toBe(false)
    expect(result.current.error).toBe('Update exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error updating lead:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles null data when updating lead', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.update as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    let updateResult = false
    await act(async () => {
      updateResult = await result.current.updateLead(1, {
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'New Company',
      })
    })

    expect(updateResult).toBe(true)
    // Lead should remain unchanged when data is null
  })

  it('deletes leads successfully', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
      {
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.destroy as jest.Mock).mockResolvedValue({
      status: 204,
    })

    let deleteResult = false
    await act(async () => {
      deleteResult = await result.current.deleteLeads([1])
    })

    expect(deleteResult).toBe(true)
    expect(result.current.leads).toHaveLength(1)
    expect(result.current.leads[0].id).toBe(2)
    expect(result.current.error).toBeNull()
  })

  it('handles cancel when deleting leads', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    window.confirm = jest.fn(() => false)

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteLeads([1])
    })

    expect(deleteResult).toBe(false)
    expect(result.current.leads).toHaveLength(1)
  })

  it('handles partial failure when deleting leads', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
      {
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.destroy as jest.Mock)
      .mockResolvedValueOnce({ status: 204 })
      .mockResolvedValueOnce({ error: 'Delete failed', status: 500 })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteLeads([1, 2])
    })

    expect(deleteResult).toBe(false)
    expect(result.current.error).toBe('Failed to delete 1 lead(s)')
    expect(consoleErrorSpy).toHaveBeenCalled()
    // Leads should remain unchanged on failure
    expect(result.current.leads).toHaveLength(2)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when deleting leads', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const error = new Error('Delete exception');
    (apiClient.destroy as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteLeads([1])
    })

    expect(deleteResult).toBe(false)
    expect(result.current.error).toBe('Delete exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error deleting leads:', error)

    consoleErrorSpy.mockRestore()
  })

  it('finds lead by ID', async () => {
    const leads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
      {
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: leads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const foundLead = result.current.findLead(2)
    expect(foundLead).toEqual(leads[1])

    const notFoundLead = result.current.findLead(999)
    expect(notFoundLead).toBeUndefined()
  })

  it('provides refreshLeads method that reloads leads', async () => {
    const mockLeads: Lead[] = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: mockLeads,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    // Update mock for refresh
    const newLeads: Lead[] = [
      ...mockLeads,
      {
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'CEO',
        company: 'Company',
        website: 'example.com',
        campaignId: 1,
        stage: 'queued',
        quality: '-',
      },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: newLeads,
      status: 200,
    })

    await act(async () => {
      await result.current.refreshLeads()
      await jest.runAllTimersAsync()
    })

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.leads).toEqual(newLeads)
  })

  it('handles null data when loading leads', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    const { result } = renderHook(() => useLeads())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.leads).toEqual([])
  })
})

