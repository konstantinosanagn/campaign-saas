import { renderHook, waitFor, act } from '@testing-library/react'
import { useTypewriter } from '@/hooks/useTypewriter'

describe('useTypewriter', () => {
  beforeEach(() => {
    jest.useFakeTimers()
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  it('initializes with empty string', () => {
    const { result } = renderHook(() => useTypewriter('Hello'))
    expect(result.current).toBe('')
  })

  it('types out text character by character', async () => {
    const { result } = renderHook(() => useTypewriter('Hello', 50))

    // Advance timers to simulate typing
    for (let i = 0; i <= 5; i++) {
      act(() => {
        jest.advanceTimersByTime(50)
      })
      await waitFor(() => {
        expect(result.current.length).toBe(i)
      })
    }

    expect(result.current).toBe('Hello')
  })

  it('resets when text changes', async () => {
    const { result, rerender } = renderHook(
      ({ text }) => useTypewriter(text, 50),
      { initialProps: { text: 'Hello' } }
    )

    // Type out first text
    act(() => {
      jest.advanceTimersByTime(250)
    })
    await waitFor(() => expect(result.current).toBe('Hello'))

    // Change text
    rerender({ text: 'World' })

    // Should reset
    expect(result.current).toBe('')

    // Type out new text
    act(() => {
      jest.advanceTimersByTime(250)
    })
    await waitFor(() => expect(result.current).toBe('World'))
  })

  it('cleans up interval on unmount', () => {
    const clearIntervalSpy = jest.spyOn(global, 'clearInterval')
    const { unmount } = renderHook(() => useTypewriter('Hello', 50))

    unmount()

    expect(clearIntervalSpy).toHaveBeenCalled()
    clearIntervalSpy.mockRestore()
  })
})

