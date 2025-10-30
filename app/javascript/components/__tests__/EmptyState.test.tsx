import React from 'react'
import { render, screen } from '@testing-library/react'
import EmptyState from '../EmptyState'

describe('EmptyState', () => {
  it('renders empty state message', () => {
    render(<EmptyState />)
    
    expect(screen.getByText('Select a Campaign')).toBeInTheDocument()
    expect(screen.getByText('Choose a campaign from the left to view leads')).toBeInTheDocument()
  })

  it('renders with correct styling classes', () => {
    const { container } = render(<EmptyState />)
    
    const mainDiv = container.firstChild as HTMLElement
    expect(mainDiv).toHaveClass('flex', 'items-center', 'justify-center', 'h-full')
    
    const centerDiv = mainDiv.querySelector('div.text-center')
    expect(centerDiv).toBeInTheDocument()
  })

  it('renders SVG icon', () => {
    const { container } = render(<EmptyState />)
    
    const svg = container.querySelector('svg')
    expect(svg).toBeInTheDocument()
    expect(svg).toHaveAttribute('xmlns', 'http://www.w3.org/2000/svg')
    expect(svg).toHaveAttribute('fill', 'none')
    expect(svg).toHaveAttribute('viewBox', '0 0 24 24')
  })

  it('has correct text styling', () => {
    render(<EmptyState />)
    
    const title = screen.getByText('Select a Campaign')
    expect(title).toHaveClass('text-gray-500', 'text-lg', 'font-medium')
    
    const subtitle = screen.getByText('Choose a campaign from the left to view leads')
    expect(subtitle).toHaveClass('text-gray-400', 'text-sm', 'mt-1')
  })
})

