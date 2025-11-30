'use client'

import React from 'react'
import { useState } from 'react'
import { useRef } from 'react'

interface CampaignFormProps {
  isOpen: boolean
  onClose: () => void
  onSubmit: (data: { title: string; productInfo?: string; senderCompany?: string; tone?: string; persona?: string; primaryGoal?: string }) => void
  initialData?: { index: number; title: string; productInfo?: string; senderCompany?: string; tone?: string; persona?: string; primaryGoal?: string } | null
  isEdit?: boolean
}

export default function CampaignForm({ isOpen, onClose, onSubmit, initialData, isEdit = false }: CampaignFormProps) {
  const [title, setTitle] = useState('')
  const [productInfo, setProductInfo] = useState('')
  const [senderCompany, setSenderCompany] = useState('')
  const [tone, setTone] = useState<'formal' | 'professional' | 'friendly'>('professional')
  const [persona, setPersona] = useState<'founder' | 'sales' | 'cs'>('founder')
  const [primaryGoal, setPrimaryGoal] = useState<'book_call' | 'get_reply' | 'get_click'>('book_call')
  const [toneOpen, setToneOpen] = useState(false)
  const [personaOpen, setPersonaOpen] = useState(false)
  const [primaryGoalOpen, setPrimaryGoalOpen] = useState(false)
  const titleInputRef = useRef<HTMLInputElement>(null)
  const toneRef = useRef<HTMLDivElement>(null)
  const personaRef = useRef<HTMLDivElement>(null)
  const primaryGoalRef = useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    if (isOpen && titleInputRef.current) {
      titleInputRef.current.focus()
    }
  }, [isOpen])

  React.useEffect(() => {
    if (isEdit && initialData) {
      setTitle(initialData.title)
      setProductInfo(initialData.productInfo || '')
      setSenderCompany(initialData.senderCompany || '')
      setTone((initialData.tone || 'professional') as 'professional' | 'formal' | 'friendly')
      setPersona((initialData.persona || 'founder') as 'founder' | 'sales' | 'cs')
      setPrimaryGoal((initialData.primaryGoal || 'book_call') as 'book_call' | 'get_reply' | 'get_click')
    } else {
      setTitle('')
      setProductInfo('')
      setSenderCompany('')
      setTone('professional')
      setPersona('founder')
      setPrimaryGoal('book_call')
    }
  }, [isEdit, initialData, isOpen])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit({ title, productInfo, senderCompany, tone, persona, primaryGoal })
    setTitle('')
    setProductInfo('')
    setSenderCompany('')
    setTone('professional')
    setPersona('founder')
    setPrimaryGoal('book_call')
    onClose()
  }

  // Close dropdowns when clicking outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      // Check if click is on scrollbar area (right edge of scrollable container)
      const scrollableDiv = document.querySelector('.scrollbar-visible') as HTMLElement
      if (scrollableDiv) {
        const rect = scrollableDiv.getBoundingClientRect()
        const clickX = event.clientX
        // If click is within 20px of the right edge, assume it's the scrollbar
        if (clickX >= rect.right - 20 && clickX <= rect.right) {
          return // Don't close dropdowns when clicking scrollbar area
        }
      }
      
      if (toneRef.current && !toneRef.current.contains(event.target as Node)) {
        setToneOpen(false)
      }
      if (personaRef.current && !personaRef.current.contains(event.target as Node)) {
        setPersonaOpen(false)
      }
      if (primaryGoalRef.current && !primaryGoalRef.current.contains(event.target as Node)) {
        setPrimaryGoalOpen(false)
      }
    }

    // Use a slight delay to allow scrollbar interaction
    const timeoutId = setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside)
    }, 100)

    return () => {
      clearTimeout(timeoutId)
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  // Ticker icon component
  const TickerIcon = ({ className = "w-4 h-4" }: { className?: string }) => (
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 24 24" className={className}>
      <path fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M5 14.5s1.5 0 3.5 3.5c0 0 5.559-9.167 10.5-11" color="currentColor"/>
    </svg>
  )

  const handleClose = () => {
    setTitle('')
    setProductInfo('')
    setSenderCompany('')
    setTone('professional')
    setPersona('founder')
    setPrimaryGoal('book_call')
    setToneOpen(false)
    setPersonaOpen(false)
    setPrimaryGoalOpen(false)
    onClose()
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[10001]">
      <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-gray-900">
            {isEdit ? 'Edit Campaign' : 'Create New Campaign'}
          </h2>
          <button
            onClick={handleClose}
            className="text-gray-400 hover:text-red-500 transition-colors duration-200"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">
              Title
            </label>
            <input
              type="text"
              id="title"
              ref={titleInputRef}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
              placeholder="Enter campaign title"
              required
            />
          </div>
          
          {/* Optional Fields for Writer Agent */}
          <div className="border-t border-gray-200 pt-4">
            <h3 className="text-sm font-medium text-gray-700 mb-3">Writer Agent Defaults</h3>
            <p className="text-xs text-gray-500 mb-4">
              These settings will be used as defaults by the Writer agent for all leads in this campaign.
            </p>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div ref={toneRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tone
                  </label>
                  <button
                    type="button"
                    onClick={() => setToneOpen(!toneOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700 capitalize">{tone}</span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${toneOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {toneOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'formal', label: 'Formal' },
                        { value: 'professional', label: 'Professional' },
                        { value: 'friendly', label: 'Friendly' }
                      ].map((option) => {
                        const isSelected = tone === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setTone(option.value as 'formal' | 'professional' | 'friendly')
                              setToneOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>

                <div ref={personaRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Sender Persona
                  </label>
                  <button
                    type="button"
                    onClick={() => setPersonaOpen(!personaOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {persona === 'founder' && 'Founder'}
                      {persona === 'sales' && 'Sales'}
                      {persona === 'cs' && 'Customer Success'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${personaOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {personaOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'founder', label: 'Founder' },
                        { value: 'sales', label: 'Sales' },
                        { value: 'cs', label: 'Customer Success' }
                      ].map((option) => {
                        const isSelected = persona === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setPersona(option.value as 'founder' | 'sales' | 'cs')
                              setPersonaOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>
              </div>

              <div ref={primaryGoalRef} className="relative">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Primary Goal
                </label>
                <button
                  type="button"
                  onClick={() => setPrimaryGoalOpen(!primaryGoalOpen)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                >
                  <span className="text-gray-700">
                    {primaryGoal === 'book_call' && 'Book Call - Propose a short intro meeting'}
                    {primaryGoal === 'get_reply' && 'Get Reply - Ask for a quick email response'}
                    {primaryGoal === 'get_click' && 'Get Click - Drive to a link/demo/landing page'}
                  </span>
                  <svg
                    className={`w-5 h-5 text-gray-400 transition-transform ${primaryGoalOpen ? 'transform rotate-180' : ''}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {primaryGoalOpen && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                    {[
                      { value: 'book_call', label: 'Book Call - Propose a short intro meeting' },
                      { value: 'get_reply', label: 'Get Reply - Ask for a quick email response' },
                      { value: 'get_click', label: 'Get Click - Drive to a link/demo/landing page' }
                    ].map((option) => {
                      const isSelected = primaryGoal === option.value
                      return (
                        <button
                          key={option.value}
                          type="button"
                          onClick={() => {
                            setPrimaryGoal(option.value as 'book_call' | 'get_reply' | 'get_click')
                            setPrimaryGoalOpen(false)
                          }}
                          className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                        >
                          <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                            <TickerIcon className="w-4 h-4" />
                          </span>
                          <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                        </button>
                      )
                    })}
                  </div>
                )}
              </div>

              <div>
                <label htmlFor="productInfo" className="block text-sm font-medium text-gray-700 mb-1">
                  Product Information
                </label>
                <textarea
                  id="productInfo"
                  value={productInfo}
                  onChange={(e) => setProductInfo(e.target.value)}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 resize-none outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                  placeholder="Describe your product or service..."
                />
              </div>

              <div>
                <label htmlFor="senderCompany" className="block text-sm font-medium text-gray-700 mb-1">
                  Your Company Name
                </label>
                <input
                  type="text"
                  id="senderCompany"
                  value={senderCompany}
                  onChange={(e) => setSenderCompany(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                  placeholder="Enter your company name"
                />
              </div>
            </div>
          </div>
          
          <div className="flex justify-end space-x-3 pt-4">
            <button
              type="submit"
              className="px-4 py-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-colors duration-200 font-medium"
            >
              {isEdit ? 'Save Changes' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}


