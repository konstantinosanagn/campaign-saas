import { renderHook, act } from '@testing-library/react'
import { waitFor } from '@testing-library/react'
import { useApiKeys } from '../useApiKeys'
import apiClient from '@/libs/utils/apiClient'

jest.mock('@/libs/utils/apiClient')

describe('useApiKeys', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('initializes with empty keys and loading state', () => {
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    expect(result.current.keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
    expect(result.current.loading).toBe(true)
    expect(result.current.error).toBeNull()
  })

  it('loads API keys on mount', async () => {
    const mockKeys = { llmApiKey: 'sk-test123', tavilyApiKey: 'tv-test456' }
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: mockKeys,
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.keys).toEqual(mockKeys)
    expect(result.current.error).toBeNull()
  })

  it('handles error when loading API keys fails', async () => {
    const errorMessage = 'Network error'
    (apiClient.get as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 500,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe(errorMessage)
    expect(result.current.keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to load API keys:', errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when loading API keys', async () => {
    const error = new Error('Network failure')
    (apiClient.get as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe('Network failure')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error loading API keys:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles non-Error exception when loading', async () => {
    (apiClient.get as jest.Mock).mockRejectedValue('String error')

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.error).toBe('Failed to load API keys')

    consoleErrorSpy.mockRestore()
  })

  it('saves API keys successfully', async () => {
    const initialKeys = { llmApiKey: 'sk-old', tavilyApiKey: 'tv-old' }
    const newKeys = { llmApiKey: 'sk-new', tavilyApiKey: 'tv-new' }

    (apiClient.get as jest.Mock).mockResolvedValue({
      data: initialKeys,
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockResolvedValue({
      data: newKeys,
      status: 200,
    })

    let saveResult = false
    await act(async () => {
      saveResult = await result.current.saveKeys(newKeys)
    })

    expect(saveResult).toBe(true)
    expect(result.current.keys).toEqual(newKeys)
    expect(result.current.error).toBeNull()
  })

  it('handles error when saving API keys fails', async () => {
    const errorMessage = 'Save failed'
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 422,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let saveResult = true
    await act(async () => {
      saveResult = await result.current.saveKeys({ llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' })
    })

    expect(saveResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to save API keys:', errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when saving API keys', async () => {
    const error = new Error('Save exception')
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let saveResult = true
    await act(async () => {
      saveResult = await result.current.saveKeys({ llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' })
    })

    expect(saveResult).toBe(false)
    expect(result.current.error).toBe('Save exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error saving API keys:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles non-Error exception when saving', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockRejectedValue('String error')

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let saveResult = true
    await act(async () => {
      saveResult = await result.current.saveKeys({ llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' })
    })

    expect(saveResult).toBe(false)
    expect(result.current.error).toBe('Failed to save API keys')

    consoleErrorSpy.mockRestore()
  })

  it('handles save response with null data', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    let saveResult = false
    await act(async () => {
      saveResult = await result.current.saveKeys({ llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' })
    })

    expect(saveResult).toBe(true)
    // Keys should remain unchanged when data is null
  })

  it('clears API keys successfully', async () => {
    const initialKeys = { llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' }
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: initialKeys,
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    let clearResult = false
    await act(async () => {
      clearResult = await result.current.clearKeys()
    })

    expect(clearResult).toBe(true)
    expect(result.current.keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
    expect(result.current.error).toBeNull()
  })

  it('handles error when clearing API keys fails', async () => {
    const errorMessage = 'Clear failed'
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockResolvedValue({
      error: errorMessage,
      status: 500,
    })

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let clearResult = true
    await act(async () => {
      clearResult = await result.current.clearKeys()
    })

    expect(clearResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to clear API keys:', errorMessage)

    consoleErrorSpy.mockRestore()
  })

  it('handles exception when clearing API keys', async () => {
    const error = new Error('Clear exception')
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockRejectedValue(error)

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let clearResult = true
    await act(async () => {
      clearResult = await result.current.clearKeys()
    })

    expect(clearResult).toBe(false)
    expect(result.current.error).toBe('Clear exception')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error clearing API keys:', error)

    consoleErrorSpy.mockRestore()
  })

  it('handles non-Error exception when clearing', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { llmApiKey: '', tavilyApiKey: '' },
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    (apiClient.put as jest.Mock).mockRejectedValue('String error')

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    let clearResult = true
    await act(async () => {
      clearResult = await result.current.clearKeys()
    })

    expect(clearResult).toBe(false)
    expect(result.current.error).toBe('Failed to clear API keys')

    consoleErrorSpy.mockRestore()
  })

  it('provides refreshKeys method that reloads keys', async () => {
    const mockKeys = { llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' }
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: mockKeys,
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    // Update mock for refresh
    const newKeys = { llmApiKey: 'sk-new', tavilyApiKey: 'tv-new' }
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: newKeys,
      status: 200,
    })

    await act(async () => {
      await result.current.refreshKeys()
      await jest.runAllTimersAsync()
    })

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.keys).toEqual(newKeys)
  })

  it('handles null data when loading keys', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: null,
      status: 200,
    })

    const { result } = renderHook(() => useApiKeys())

    await waitFor(() => {
      expect(result.current.loading).toBe(false)
    })

    expect(result.current.keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
  })
})

