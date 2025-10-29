'use client'

import React from 'react'

export default function Background() {
  const [screenSize, setScreenSize] = React.useState({ width: 0, height: 0 })

  React.useEffect(() => {
    const updateScreenSize = () => {
      setScreenSize({
        width: window.screen.width,
        height: window.screen.height
      })
    }

    updateScreenSize()
    window.addEventListener('resize', updateScreenSize)
    window.addEventListener('orientationchange', updateScreenSize)

    return () => {
      window.removeEventListener('resize', updateScreenSize)
      window.removeEventListener('orientationchange', updateScreenSize)
    }
  }, [])

  return (
    <div 
      className="fixed inset-0 z-0"
      style={{
        width: `${screenSize.width}px`,
        height: `${screenSize.height}px`,
        backgroundColor: '#F8FAFC'
      }}
    />
  )
}


