import React from 'react'

export function useSelection() {
  const [selectedIds, setSelectedIds] = React.useState<number[]>([])

  const toggleSelection = (id: number) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]))
  }

  const toggleMultiple = (ids: number[], shouldSelect: boolean) => {
    setSelectedIds((prev) => {
      if (shouldSelect) {
        // Add all ids that aren't already selected
        const newIds = ids.filter(id => !prev.includes(id))
        return [...prev, ...newIds]
      } else {
        // Remove all ids that are selected
        return prev.filter(id => !ids.includes(id))
      }
    })
  }

  const clearSelection = () => setSelectedIds([])

  const isSelected = (id: number) => selectedIds.includes(id)

  return { selectedIds, toggleSelection, toggleMultiple, clearSelection, isSelected }
}


