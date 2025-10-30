import { renderHook, act } from '@testing-library/react'
import { useSelection } from '@/hooks/useSelection'

describe('useSelection', () => {
  it('initializes with empty selection', () => {
    const { result } = renderHook(() => useSelection())
    expect(result.current.selectedIds).toEqual([])
  })

  it('toggles selection', () => {
    const { result } = renderHook(() => useSelection())

    act(() => {
      result.current.toggleSelection(1)
    })
    expect(result.current.selectedIds).toEqual([1])

    act(() => {
      result.current.toggleSelection(1)
    })
    expect(result.current.selectedIds).toEqual([])
  })

  it('adds multiple items to selection', () => {
    const { result } = renderHook(() => useSelection())

    act(() => {
      result.current.toggleSelection(1)
    })
    act(() => {
      result.current.toggleSelection(2)
    })
    act(() => {
      result.current.toggleSelection(3)
    })

    expect(result.current.selectedIds).toEqual([1, 2, 3])
  })

  it('clears selection', () => {
    const { result } = renderHook(() => useSelection())

    act(() => {
      result.current.toggleSelection(1)
      result.current.toggleSelection(2)
    })

    expect(result.current.selectedIds).toEqual([1, 2])

    act(() => {
      result.current.clearSelection()
    })

    expect(result.current.selectedIds).toEqual([])
  })

  it('checks if item is selected', () => {
    const { result } = renderHook(() => useSelection())

    act(() => {
      result.current.toggleSelection(1)
    })

    expect(result.current.isSelected(1)).toBe(true)
    expect(result.current.isSelected(2)).toBe(false)
  })
})

