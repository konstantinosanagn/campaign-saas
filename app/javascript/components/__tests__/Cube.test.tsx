import React from 'react'
import { render } from '@testing-library/react'

// Mock the CSS import
jest.mock('@/styles/cube.css', () => ({}))

import Cube from '../Cube'

describe('Cube', () => {
  it('renders cube spinner with 6 div elements', () => {
    const { container } = render(<Cube />)
    
    const cubeSpinner = container.querySelector('.cube-spinner')
    expect(cubeSpinner).toBeInTheDocument()
    
    // Check for 6 child divs
    const divs = cubeSpinner?.querySelectorAll('div')
    expect(divs).toHaveLength(6)
  })

  it('has correct CSS class', () => {
    const { container } = render(<Cube />)
    
    const cubeSpinner = container.querySelector('.cube-spinner')
    expect(cubeSpinner).toHaveClass('cube-spinner')
  })
})

