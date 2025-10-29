import React from 'react'

export function useSelection() {
  const [selectedIds, setSelectedIds] = React.useState<number[]>([])

  const toggleSelection = (id: number) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]))
  }

  const clearSelection = () => setSelectedIds([])

  const isSelected = (id: number) => selectedIds.includes(id)

  return { selectedIds, toggleSelection, clearSelection, isSelected }
}


