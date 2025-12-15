// useApiKeys.test.tsx
import React from 'react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

// Mock the apiClient used by the hook
jest.mock('@/libs/utils/apiClient', () => ({
  __esModule: true,
  default: {
    get: jest.fn(),
    put: jest.fn(),
  },
}))

import apiClient from '@/libs/utils/apiClient'
import { useApiKeys } from '../useApiKeys'

type ApiKeys = { llmApiKey: string; tavilyApiKey: string }

const getMock = apiClient.get as jest.Mock
const putMock = apiClient.put as jest.Mock

function Harness({
  children,
}: {
  children: (api: ReturnType<typeof useApiKeys>) => React.ReactNode
}) {
  const api = useApiKeys()
  return <>{children(api)}</>
}

function renderHookUI(
  renderFn: (api: ReturnType<typeof useApiKeys>) => React.ReactNode = () => null
) {
  return render(
    <Harness>
      {(api) => (
        <div>
          <div data-testid="keys">{JSON.stringify(api.keys)}</div>
          <div data-testid="loading">{String(api.loading)}</div>
          <div data-testid="error">{api.error ?? ''}</div>
          <button onClick={() => api.refreshKeys?.()}>refresh</button>
          <button
            onClick={() =>
              api.saveKeys({
                llmApiKey: 'LLM_NEW',
                tavilyApiKey: 'TAV_NEW',
              })
            }
          >
            save
          </button>
          <button onClick={() => api.clearKeys()}>clear</button>
          {renderFn(api)}
        </div>
      )}
    </Harness>
  )
}

describe('useApiKeys', () => {
  const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterAll(() => {
    consoleErrorSpy.mockRestore()
  })

  const readState = () => {
    const keys = JSON.parse(screen.getByTestId('keys').textContent || '{}') as ApiKeys
    const loading = screen.getByTestId('loading').textContent === 'true'
    const error = screen.getByTestId('error').textContent || ''
    return { keys, loading, error }
  }

  // ---------- LOAD / MOUNT ----------
  it('loads keys on mount: success with data', async () => {
    getMock.mockResolvedValueOnce({
      data: { llmApiKey: 'LLM_1', tavilyApiKey: 'TAV_1' },
    })

    renderHookUI()

    expect(readState().loading).toBe(true)

    await waitFor(() => {
      const { keys, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(keys).toEqual({ llmApiKey: 'LLM_1', tavilyApiKey: 'TAV_1' })
    })
    expect(getMock).toHaveBeenCalledWith('api_keys')
  })

  it('loads keys on mount: success with undefined data → fallback empty', async () => {
    getMock.mockResolvedValueOnce({ data: undefined })

    renderHookUI()

    await waitFor(() => {
      const { keys, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('')
      expect(keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
    })
  })

  it('loads keys on mount: response.error branch', async () => {
    getMock.mockResolvedValueOnce({ error: 'boom-load' })

    renderHookUI()

    await waitFor(() => {
      const { keys, loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('boom-load')
      expect(keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
    })
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to load API keys:', 'boom-load')
  })

  it('loads keys on mount: Error exception branch', async () => {
    getMock.mockRejectedValueOnce(new Error('network down'))

    renderHookUI()

    await waitFor(() => {
      const { loading, error } = readState()
      expect(loading).toBe(false)
      expect(error).toBe('network down')
    })
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error loading API keys:',
      expect.any(Error)
    )
  })

  it('loads keys on mount: non-Error exception branch', async () => {
    getMock.mockRejectedValueOnce('weird string')

    renderHookUI()

    await waitFor(() => {
      const { loading, error } = readState()
      // hook uses default message in non-Error case
      expect(error).toBe('Failed to load API keys')
    })
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error loading API keys:', 'weird string')
  })

  // ---------- REFRESH ----------
  it('refreshKeys: re-fetches and updates state', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: '', tavilyApiKey: '' } })
    getMock.mockResolvedValueOnce({ data: { llmApiKey: 'LLM_R', tavilyApiKey: 'TAV_R' } })

    renderHookUI()

    await waitFor(() => expect(readState().loading).toBe(false))
    expect(readState().keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })

    await userEvent.click(screen.getByText('refresh'))

    await waitFor(() => {
      expect(readState().keys).toEqual({ llmApiKey: 'LLM_R', tavilyApiKey: 'TAV_R' })
    })

    expect(getMock).toHaveBeenNthCalledWith(1, 'api_keys')
    expect(getMock).toHaveBeenNthCalledWith(2, 'api_keys')
  })

  // ---------- SAVE ----------
  it('saveKeys: success with returned data → updates state, returns true', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: '', tavilyApiKey: '' } })
    putMock.mockResolvedValueOnce({
      data: { llmApiKey: 'LLM_NEW', tavilyApiKey: 'TAV_NEW' },
    })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.saveKeys({ llmApiKey: 'LLM_NEW', tavilyApiKey: 'TAV_NEW' })
    expect(ok).toBe(true)
    expect(putMock).toHaveBeenCalledWith('api_keys', {
      api_key: {
        llmApiKey: 'LLM_NEW',
        tavilyApiKey: 'TAV_NEW',
      },
    })
    expect(readState().keys).toEqual({ llmApiKey: 'LLM_NEW', tavilyApiKey: 'TAV_NEW' })
    expect(readState().error).toBe('')
  })

  it('saveKeys: success without data → returns true, does not change state', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: 'BASE', tavilyApiKey: 'BASE' } })
    putMock.mockResolvedValueOnce({ data: undefined })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))
    expect(readState().keys).toEqual({ llmApiKey: 'BASE', tavilyApiKey: 'BASE' })

    const ok = await apiRef.saveKeys({ llmApiKey: 'X', tavilyApiKey: 'Y' })
    expect(ok).toBe(true)
    expect(readState().keys).toEqual({ llmApiKey: 'BASE', tavilyApiKey: 'BASE' })
  })

  it('saveKeys: response.error branch → sets error, logs, returns false', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: '', tavilyApiKey: '' } })
    putMock.mockResolvedValueOnce({ error: 'boom-save' })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.saveKeys({ llmApiKey: 'A', tavilyApiKey: 'B' })
    expect(ok).toBe(false)
    expect(readState().error).toBe('boom-save')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to save API keys:', 'boom-save')
  })

  it('saveKeys: Error exception → sets message, logs, returns false', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: '', tavilyApiKey: '' } })
    putMock.mockRejectedValueOnce(new Error('save-crash'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.saveKeys({ llmApiKey: 'A', tavilyApiKey: 'B' })
    expect(ok).toBe(false)
    expect(readState().error).toBe('save-crash')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error saving API keys:',
      expect.any(Error)
    )
  })

  it('saveKeys: non-Error exception → default message, logs, returns false', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: '', tavilyApiKey: '' } })
    putMock.mockRejectedValueOnce('weird save string')

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.saveKeys({ llmApiKey: 'A', tavilyApiKey: 'B' })
    expect(ok).toBe(false)
    expect(readState().error).toBe('Failed to save API keys')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Error saving API keys:', 'weird save string')
  })

  // ---------- CLEAR ----------
  it('clearKeys: success → sets empty and returns true', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: 'SOME', tavilyApiKey: 'VAL' } })
    putMock.mockResolvedValueOnce({ data: {} })

    renderHookUI()

    await waitFor(() => expect(readState().loading).toBe(false))
    expect(readState().keys).toEqual({ llmApiKey: 'SOME', tavilyApiKey: 'VAL' })

    await userEvent.click(screen.getByText('clear'))

    await waitFor(() => {
      expect(putMock).toHaveBeenCalledWith('api_keys', { api_key: { llmApiKey: '', tavilyApiKey: '' } })
      expect(readState().keys).toEqual({ llmApiKey: '', tavilyApiKey: '' })
    })
  })

  it('clearKeys: response.error branch → sets error, logs, returns false, state unchanged', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: '1', tavilyApiKey: '2' } })
    putMock.mockResolvedValueOnce({ error: 'boom-clear' })

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.clearKeys()
    expect(ok).toBe(false)
    expect(readState().keys).toEqual({ llmApiKey: '1', tavilyApiKey: '2' })
    expect(readState().error).toBe('boom-clear')
    expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to clear API keys:', 'boom-clear')
  })

  it('clearKeys: Error exception → sets message, logs, returns false, state unchanged', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: 'AA', tavilyApiKey: 'BB' } })
    putMock.mockRejectedValueOnce(new Error('clear-crash'))

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.clearKeys()
    expect(ok).toBe(false)
    expect(readState().keys).toEqual({ llmApiKey: 'AA', tavilyApiKey: 'BB' })
    expect(readState().error).toBe('clear-crash')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error clearing API keys:',
      expect.any(Error)
    )
  })

  it('clearKeys: non-Error exception → default message, logs, returns false, state unchanged', async () => {
    getMock.mockResolvedValueOnce({ data: { llmApiKey: 'CC', tavilyApiKey: 'DD' } })
    putMock.mockRejectedValueOnce('weird clear string')

    let apiRef: any
    renderHookUI((api) => {
      apiRef = api
      return null
    })

    await waitFor(() => expect(readState().loading).toBe(false))

    const ok = await apiRef.clearKeys()
    expect(ok).toBe(false)
    expect(readState().keys).toEqual({ llmApiKey: 'CC', tavilyApiKey: 'DD' })
    expect(readState().error).toBe('Failed to clear API keys')
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error clearing API keys:',
      'weird clear string'
    )
  })
})
