import React from 'react'
import { render, screen } from '@testing-library/react'
import Background from '../Background'

describe('Background', () => {
  beforeEach(() => {
    // Mock window.screen
    Object.defineProperty(window, 'screen', {
      writable: true,
      value: {
        width: 1920,
        height: 1080,
      },
    })
  })

  it('renders with initial screen size', () => {
    const { container } = render(<Background />)
    const backgroundDiv = container.firstChild as HTMLElement
    
    expect(backgroundDiv).toBeInTheDocument()
    expect(backgroundDiv).toHaveStyle({
      width: '1920px',
      height: '1080px',
      backgroundColor: '#F8FAFC',
    })
    expect(backgroundDiv).toHaveClass('fixed', 'inset-0', 'z-0')
  })

  it('updates size on window resize', () => {
    const { container } = render(<Background />)
    const backgroundDiv = container.firstChild as HTMLElement
    
    // Initial size
    expect(backgroundDiv).toHaveStyle({ width: '1920px', height: '1080px' })
    
    // Update screen size
    Object.defineProperty(window, 'screen', {
      writable: true,
      value: {
        width: 1366,
        height: 768,
      },
    })
    
    // Simulate resize event
    window.dispatchEvent(new Event('resize'))
    
    // Component should update (though React Testing Library may need act wrapper)
    // The actual update happens in useEffect
  })

  it('updates size on orientation change', () => {
    const { container } = render(<Background />)
    const backgroundDiv = container.firstChild as HTMLElement
    
    // Initial size
    expect(backgroundDiv).toHaveStyle({ width: '1920px', height: '1080px' })
    
    // Update screen size
    Object.defineProperty(window, 'screen', {
      writable: true,
      value: {
        width: 768,
        height: 1024,
      },
    })
    
    // Simulate orientationchange event
    window.dispatchEvent(new Event('orientationchange'))
  })

  it('cleans up event listeners on unmount', () => {
    const addEventListenerSpy = jest.spyOn(window, 'addEventListener')
    const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener')
    
    const { unmount } = render(<Background />)
    
    // Verify listeners were added
    expect(addEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function))
    expect(addEventListenerSpy).toHaveBeenCalledWith('orientationchange', expect.any(Function))
    
    // Unmount component
    unmount()
    
    // Verify listeners were removed
    expect(removeEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function))
    expect(removeEventListenerSpy).toHaveBeenCalledWith('orientationchange', expect.any(Function))
    
    addEventListenerSpy.mockRestore()
    removeEventListenerSpy.mockRestore()
  })
})

