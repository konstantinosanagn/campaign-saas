import { renderHook, act } from '@testing-library/react'
import { waitFor } from '@testing-library/dom'
import { useCampaigns } from '../useCampaigns'
import apiClient from '@/libs/utils/apiClient'
import type { Campaign } from '@/types'

jest.mock('@/libs/utils/apiClient')

describe('useCampaigns', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    jest.useFakeTimers()
    window.confirm = jest.fn(() => true)
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  it('initializes with empty campaigns and loading state', () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    expect(result.current.campaigns).toEqual([])
    expect(result.current.loading).toBe(true)
    expect(result.current.error).toBeNull()
  })

  it('loads campaigns on mount', async () => {
    const mockCampaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
      { id: 2, title: 'Campaign 2', basePrompt: 'Prompt 2' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: mockCampaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.campaigns).toEqual(mockCampaigns)
    expect(result.current.error).toBeNull()
  })

  it('handles error when loading campaigns fails', async () => {
    const errorMessage = 'Network error';
    (apiClient.index as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 500,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe(errorMessage)
    expect(result.current.campaigns).toEqual([])
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to load campaigns:', errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when loading campaigns', async () => {
    const error = new Error('Network failure');
    (apiClient.index as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe('Network failure')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error loading campaigns:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles non-Error exception when loading', async () => {
    (apiClient.index as jest.Mock).mockRejectedValue('String error')

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe('Failed to load campaigns')

    consoleErrorSpy.mockRestore()
  })

  it('creates campaign successfully', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const newCampaign: Campaign = { id: 1, title: 'New Campaign', basePrompt: 'New Prompt' };
    (apiClient.create as jest.Mock).mockResolvedValue({
      data: newCampaign,
      status: 201,
    })

    let createdCampaign: Campaign | null = null
    await act(async () => {
      createdCampaign = await result.current.createCampaign({ title: 'New Campaign', basePrompt: 'New Prompt' })
    })

    expect(createdCampaign).toEqual(newCampaign)
    expect(result.current.campaigns).toContainEqual(newCampaign)
    expect(result.current.error).toBeNull()
  })

  it('handles error when creating campaign fails', async () => {
    const errorMessage = 'Validation failed';
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 422,
      data: { errors: ['Title is required'] },
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let createdCampaign: Campaign | null = { id: 999 } as Campaign
    await act(async () => {
      createdCampaign = await result.current.createCampaign({ title: '', basePrompt: '' })
    })

    expect(createdCampaign).toBeNull()
    expect(result.current.error).toBe('Title is required')
    expect(consoleErrorSpy).toHaveBeenCalled()

    consoleErrorSpy.mockRestore()
  })

  it('handles creation error without errors array', async () => {
    const errorMessage = 'Creation failed';
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 422,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let createdCampaign: Campaign | null = { id: 999 } as Campaign
    await act(async () => {
      createdCampaign = await result.current.createCampaign({ title: 'Test', basePrompt: 'Test' })
    })

    expect(createdCampaign).toBeNull()
    expect(result.current.error).toBe(errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when creating campaign', async () => {
    const error = new Error('Create exception');
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let createdCampaign: Campaign | null = { id: 999 } as Campaign
    await act(async () => {
      createdCampaign = await result.current.createCampaign({ title: 'Test', basePrompt: 'Test' })
    })

    expect(createdCampaign).toBeNull()
    expect(result.current.error).toBe('Create exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error creating campaign:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles null data when creating campaign', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.create as jest.Mock).mockResolvedValue({
      data: null,
      status: 201,
    })

    let createdCampaign: Campaign | null = { id: 999 } as Campaign
    await act(async () => {
      createdCampaign = await result.current.createCampaign({ title: 'Test', basePrompt: 'Test' })
    })

    expect(createdCampaign).toBeNull()
  })

  it('updates campaign successfully', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const updatedCampaign: Campaign = { id: 1, title: 'Updated Campaign', basePrompt: 'Updated Prompt' };
    (apiClient.update as jest.Mock).mockResolvedValue({
      data: updatedCampaign,
      status: 200,
    })

    let updateResult = false
    await act(async () => {
      updateResult = await result.current.updateCampaign(0, { title: 'Updated Campaign', basePrompt: 'Updated Prompt' })
    })

    expect(updateResult).toBe(true)
    expect(result.current.campaigns[0]).toEqual(updatedCampaign)
    expect(result.current.error).toBeNull()
  })

  it('handles error when updating campaign with missing ID', async () => {
    const campaigns: Campaign[] = [
      { title: 'Campaign without ID', basePrompt: 'Prompt' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    let updateResult = true
    await act(async () => {
      updateResult = await result.current.updateCampaign(0, { title: 'Updated', basePrompt: 'Updated' })
    })

    expect(updateResult).toBe(false)
    expect(result.current.error).toBe('Campaign ID not found')
  })

  it('handles error when campaign index is out of bounds', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: [],
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    let updateResult = true
    await act(async () => {
      updateResult = await result.current.updateCampaign(999, { title: 'Updated', basePrompt: 'Updated' })
    })

    expect(updateResult).toBe(false)
    expect(result.current.error).toBe('Campaign ID not found')
  })

  it('handles error when updating campaign fails', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

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
      updateResult = await result.current.updateCampaign(0, { title: 'Updated', basePrompt: 'Updated' })
    })

    expect(updateResult).toBe(false)
    expect(result.current.error).toBe('Update failed')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to update campaign:', 'Update failed')

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when updating campaign', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const error = new Error('Update exception');
    (apiClient.update as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let updateResult = true
    await act(async () => {
      updateResult = await result.current.updateCampaign(0, { title: 'Updated', basePrompt: 'Updated' })
    })

    expect(updateResult).toBe(false)
    expect(result.current.error).toBe('Update exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error updating campaign:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles null data when updating campaign', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.update as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    let updateResult = false
    await act(async () => {
      updateResult = await result.current.updateCampaign(0, { title: 'Updated', basePrompt: 'Updated' })
    })

    expect(updateResult).toBe(true)
    // Campaign should remain unchanged when data is null
  })

  it('deletes campaign successfully', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
      { id: 2, title: 'Campaign 2', basePrompt: 'Prompt 2' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.destroy as jest.Mock).mockResolvedValue({
      status: 204,
    })

    let deleteResult = false
    await act(async () => {
      deleteResult = await result.current.deleteCampaign(0)
    })

    expect(deleteResult).toBe(true)
    expect(result.current.campaigns).toHaveLength(1)
    expect(result.current.campaigns[0].id).toBe(2)
    expect(result.current.error).toBeNull()
  })

  it('handles error when deleting campaign with missing ID', async () => {
    const campaigns: Campaign[] = [
      { title: 'Campaign without ID', basePrompt: 'Prompt' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteCampaign(0)
    })

    expect(deleteResult).toBe(false)
    expect(result.current.error).toBe('Campaign ID not found')
  })

  it('handles cancel when deleting campaign', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    window.confirm = jest.fn(() => false)

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteCampaign(0)
    })

    expect(deleteResult).toBe(false)
    expect(result.current.campaigns).toHaveLength(1)
  })

  it('handles error when deleting campaign fails', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.destroy as jest.Mock).mockResolvedValue({
      error: 'Delete failed',
      status: 500,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteCampaign(0)
    })

    expect(deleteResult).toBe(false)
    expect(result.current.error).toBe('Delete failed')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to delete campaign:', 'Delete failed')

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when deleting campaign', async () => {
    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: campaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    const error = new Error('Delete exception');
    (apiClient.destroy as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let deleteResult = true
    await act(async () => {
      deleteResult = await result.current.deleteCampaign(0)
    })

    expect(deleteResult).toBe(false)
    expect(result.current.error).toBe('Delete exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error deleting campaign:', error)

    consoleErrorSpy.mockRestore()
  })

  it('provides refreshCampaigns method that reloads campaigns', async () => {
    const mockCampaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: mockCampaigns,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    // Update mock for refresh
    const newCampaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: 'Prompt 1' },
      { id: 2, title: 'Campaign 2', basePrompt: 'Prompt 2' },
    ];
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: newCampaigns,
      status: 200,
    })

    await act(async () => {
      await result.current.refreshCampaigns()
      await jest.runAllTimersAsync()
    })

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.campaigns).toEqual(newCampaigns)
  })

  it('handles null data when loading campaigns', async () => {
    (apiClient.index as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    const { result } = renderHook(() => useCampaigns())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.campaigns).toEqual([])
  })
})

