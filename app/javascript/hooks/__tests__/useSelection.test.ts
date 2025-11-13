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

  describe('toggleMultiple', () => {
    it('selects multiple items at once', () => {
      const { result } = renderHook(() => useSelection())

      act(() => {
        result.current.toggleMultiple([1, 2, 3], true)
      })

      expect(result.current.selectedIds).toEqual([1, 2, 3])
      expect(result.current.isSelected(1)).toBe(true)
      expect(result.current.isSelected(2)).toBe(true)
      expect(result.current.isSelected(3)).toBe(true)
    })

    it('deselects multiple items at once', () => {
      const { result } = renderHook(() => useSelection())

      // First select some items
      act(() => {
        result.current.toggleSelection(1)
        result.current.toggleSelection(2)
        result.current.toggleSelection(3)
      })

      expect(result.current.selectedIds).toEqual([1, 2, 3])

      // Then deselect them all
      act(() => {
        result.current.toggleMultiple([1, 2, 3], false)
      })

      expect(result.current.selectedIds).toEqual([])
      expect(result.current.isSelected(1)).toBe(false)
      expect(result.current.isSelected(2)).toBe(false)
      expect(result.current.isSelected(3)).toBe(false)
    })

    it('only selects items that are not already selected', () => {
      const { result } = renderHook(() => useSelection())

      // First select item 1
      act(() => {
        result.current.toggleSelection(1)
      })

      expect(result.current.selectedIds).toEqual([1])

      // Then select multiple items including 1
      act(() => {
        result.current.toggleMultiple([1, 2, 3], true)
      })

      // Should not duplicate item 1
      expect(result.current.selectedIds).toEqual([1, 2, 3])
      expect(result.current.selectedIds.filter(id => id === 1).length).toBe(1)
    })

    it('only deselects items that are selected', () => {
      const { result } = renderHook(() => useSelection())

      // First select item 1
      act(() => {
        result.current.toggleSelection(1)
      })

      expect(result.current.selectedIds).toEqual([1])

      // Try to deselect multiple items including unselected ones
      act(() => {
        result.current.toggleMultiple([1, 2, 3], false)
      })

      // Should only deselect item 1
      expect(result.current.selectedIds).toEqual([])
    })

    it('handles empty array', () => {
      const { result } = renderHook(() => useSelection())

      act(() => {
        result.current.toggleSelection(1)
      })

      expect(result.current.selectedIds).toEqual([1])

      act(() => {
        result.current.toggleMultiple([], true)
      })

      // Should not change selection
      expect(result.current.selectedIds).toEqual([1])
    })

    it('handles selecting when some items are already selected', () => {
      const { result } = renderHook(() => useSelection())

      // First select item 1
      act(() => {
        result.current.toggleSelection(1)
      })

      // Then select multiple items
      act(() => {
        result.current.toggleMultiple([2, 3, 4], true)
      })

      // Should have all items
      expect(result.current.selectedIds).toEqual([1, 2, 3, 4])
    })

    it('handles deselecting when some items are not selected', () => {
      const { result } = renderHook(() => useSelection())

      // First select items 1 and 2
      act(() => {
        result.current.toggleSelection(1)
        result.current.toggleSelection(2)
      })

      // Then deselect multiple items including unselected ones
      act(() => {
        result.current.toggleMultiple([1, 2, 3, 4], false)
      })

      // Should only deselect selected items
      expect(result.current.selectedIds).toEqual([])
    })
  })
})

