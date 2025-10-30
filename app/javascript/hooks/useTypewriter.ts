import React from 'react'

export function useTypewriter(text: string, speed: number = 50) {
  const [displayedText, setDisplayedText] = React.useState('')

  React.useEffect(() => {
    setDisplayedText('')
    let currentIndex = 0

    const typeInterval = setInterval(() => {
      if (currentIndex <= text.length) {
        setDisplayedText(text.slice(0, currentIndex))
        currentIndex++
      } else {
        clearInterval(typeInterval)
      }
    }, speed)

    return () => clearInterval(typeInterval)
  }, [text, speed])

  return displayedText
}


