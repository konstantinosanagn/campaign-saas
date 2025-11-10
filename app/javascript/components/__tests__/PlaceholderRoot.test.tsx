import React from 'react'
import { render, screen } from '@testing-library/react'
import PlaceholderRoot from '@/components/shared/PlaceholderRoot'

describe('PlaceholderRoot', () => {
  it('renders default message when no message prop provided', () => {
    render(<PlaceholderRoot />)
    
    expect(screen.getByText('Placeholder component loaded')).toBeInTheDocument()
  })

  it('renders custom message when message prop provided', () => {
    render(<PlaceholderRoot message="Custom placeholder text" />)
    
    expect(screen.getByText('Custom placeholder text')).toBeInTheDocument()
    expect(screen.queryByText('Placeholder component loaded')).not.toBeInTheDocument()
  })

  it('has correct styling classes', () => {
    const { container } = render(<PlaceholderRoot />)
    
    const div = container.firstChild as HTMLElement
    expect(div).toHaveClass('p-6', 'text-center', 'text-gray-700')
  })
})

