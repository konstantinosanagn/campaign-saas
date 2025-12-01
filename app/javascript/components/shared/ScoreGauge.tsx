'use client'

import React from 'react'

interface ScoreGaugeProps {
  score: number | null | undefined
  size?: 'small' | 'medium' | 'large'
}

/**
 * ScoreGauge displays a score (0-10) as a circular gauge/speedometer
 * with color-coded visualization based on score range.
 */
export default function ScoreGauge({ score, size = 'medium' }: ScoreGaugeProps) {
  // Handle missing score
  if (score === null || score === undefined) {
    return (
      <div className="flex items-center justify-center">
        <span className="text-sm text-gray-400">-</span>
      </div>
    )
  }

  // Ensure score is between 0 and 10
  const normalizedScore = Math.max(0, Math.min(10, score))
  
  // Calculate percentage for gauge arc (0-75% of circle for visual appeal)
  // Map 0-10 score to 0-75% of circle
  const percentage = (normalizedScore / 10) * 75
  const strokeDasharray = `${percentage} 100`
  
  // Determine color scheme based on score range
  const getColorScheme = (score: number) => {
    if (score >= 8) {
      return {
        bg: 'text-green-200 dark:text-neutral-700',
        stroke: 'text-green-600 dark:text-green-500',
        text: 'text-green-600 dark:text-green-500'
      }
    } else if (score >= 6) {
      return {
        bg: 'text-orange-100 dark:text-neutral-700',
        stroke: 'text-orange-600 dark:text-orange-500',
        text: 'text-orange-600 dark:text-orange-500'
      }
    } else {
      return {
        bg: 'text-purple-200 dark:text-neutral-700',
        stroke: 'text-purple-600 dark:text-purple-500',
        text: 'text-purple-600 dark:text-purple-500'
      }
    }
  }

  const colors = getColorScheme(normalizedScore)
  
  // Size configurations
  const sizeConfig = {
    small: { container: 'size-12', text: 'text-lg', label: 'text-xs' },
    medium: { container: 'size-16', text: 'text-xl', label: 'text-xs' },
    large: { container: 'size-24', text: 'text-3xl', label: 'text-sm' }
  }
  
  const config = sizeConfig[size]

  return (
    <div className={`relative ${config.container} flex items-center justify-center`}>
      <svg 
        className={`rotate-[135deg] size-full`} 
        viewBox="0 0 36 36" 
        xmlns="http://www.w3.org/2000/svg"
      >
        {/* Background Circle (Gauge) */}
        <circle
          cx="18"
          cy="18"
          r="16"
          fill="none"
          className={`stroke-current ${colors.bg}`}
          strokeWidth="1"
          strokeDasharray="75 100"
          strokeLinecap="round"
        />
        {/* Gauge Progress */}
        <circle
          cx="18"
          cy="18"
          r="16"
          fill="none"
          className={`stroke-current ${colors.stroke}`}
          strokeWidth="2"
          strokeDasharray={strokeDasharray}
          strokeLinecap="round"
        />
      </svg>
      {/* Value Text */}
      <div className="absolute top-1/2 start-1/2 transform -translate-x-1/2 -translate-y-1/2 text-center">
        <span className={`${config.text} font-bold ${colors.text}`}>
          {Math.round(normalizedScore)}
        </span>
        <span className={`${colors.text} block ${config.label}`}>/10</span>
      </div>
    </div>
  )
}
