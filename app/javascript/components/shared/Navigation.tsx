'use client'

import React, { useEffect, useRef, useState } from 'react'
import Cube from '@/components/shared/Cube'
import { useApiKeys } from '@/hooks/useApiKeys'
import tavilyLogo from '@/images/tavily-trans.png'
import geminiLogo from '@/images/gemini-trans.png'

type DropdownType = 'tavily' | 'gemini'

export default function Navigation() {
  const { keys: apiKeys, saveKeys } = useApiKeys()
  const [activeDropdown, setActiveDropdown] = useState<DropdownType | null>(null)
  const [inputValues, setInputValues] = useState({ tavily: '', gemini: '' })
  const [saving, setSaving] = useState({ tavily: false, gemini: false })
  const [status, setStatus] = useState<{ tavily: 'idle' | 'saved' | 'error'; gemini: 'idle' | 'saved' | 'error' }>({
    tavily: 'idle',
    gemini: 'idle'
  })
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const dropdownRefs = {
    tavily: useRef<HTMLDivElement>(null),
    gemini: useRef<HTMLDivElement>(null)
  }
  const inputRefs = {
    tavily: useRef<HTMLInputElement>(null),
    gemini: useRef<HTMLInputElement>(null)
  }
  const closeDelay = 3000

  const clearCloseTimer = () => {
    if (closeTimerRef.current) {
      clearTimeout(closeTimerRef.current)
      closeTimerRef.current = null
    }
  }

  const scheduleClose = (type: DropdownType, delay = closeDelay) => {
    clearCloseTimer()
    closeTimerRef.current = setTimeout(() => {
      const dropdownEl = dropdownRefs[type].current
      const activeEl = document.activeElement as HTMLElement | null
      if (dropdownEl && activeEl && dropdownEl.contains(activeEl)) {
        return
      }
      setActiveDropdown(current => (current === type ? null : current))
    }, delay)
  }

  const openDropdown = (type: DropdownType) => {
    clearCloseTimer()
    setActiveDropdown(type)
  }

  useEffect(() => {
    return () => {
      clearCloseTimer()
    }
  }, [])

  useEffect(() => {
    setInputValues({
      tavily: apiKeys.tavilyApiKey || '',
      gemini: apiKeys.llmApiKey || ''
    })
    setStatus(prev => ({
      tavily: apiKeys.tavilyApiKey ? (prev.tavily === 'error' ? 'error' : 'saved') : 'idle',
      gemini: apiKeys.llmApiKey ? (prev.gemini === 'error' ? 'error' : 'saved') : 'idle'
    }))
  }, [apiKeys.llmApiKey, apiKeys.tavilyApiKey])

  const handleInputChange = (type: DropdownType, value: string) => {
    setInputValues(prev => ({
      ...prev,
      [type]: value
    }))
    setStatus(prev => ({
      ...prev,
      [type]: 'idle'
    }))
  }

  const handleDropdownSubmit = async (type: DropdownType, event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const value = inputValues[type]
    setSaving(prev => ({ ...prev, [type]: true }))
    const payload = {
      llmApiKey: type === 'gemini' ? value : apiKeys.llmApiKey,
      tavilyApiKey: type === 'tavily' ? value : apiKeys.tavilyApiKey
    }

    const success = await saveKeys(payload)
    setSaving(prev => ({ ...prev, [type]: false }))

    if (success) {
      setStatus(prev => ({ ...prev, [type]: 'saved' }))
      clearCloseTimer()
      setActiveDropdown(null)
    } else {
      setStatus(prev => ({ ...prev, [type]: 'error' }))
    }
  }

  const handleLogoKeyDown = (type: DropdownType, event: React.KeyboardEvent<HTMLButtonElement>) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      openDropdown(type)
      setTimeout(() => {
        inputRefs[type].current?.focus()
      }, 100)
    }
  }

  const handleLogoBlur = (type: DropdownType) => {
    setTimeout(() => {
      const dropdownEl = dropdownRefs[type].current
      const activeEl = document.activeElement as HTMLElement | null
      if (dropdownEl && activeEl && dropdownEl.contains(activeEl)) {
        return
      }
      scheduleClose(type)
    }, 10)
  }

  const renderDropdown = (
    type: DropdownType,
    label: string,
    placeholder: string,
    description: string
  ) => {
    const isOpen = activeDropdown === type
    const isSaving = saving[type]
    const storedValue = type === 'tavily' ? apiKeys.tavilyApiKey : apiKeys.llmApiKey
    const inputValue = inputValues[type]
    const hasStoredValue = Boolean(storedValue)
    const isDirty = inputValue !== (storedValue || '')
    const showSaved = !isDirty && hasStoredValue && status[type] !== 'error'
    const showError = status[type] === 'error'

    if (!isOpen) {
      return null
    }

    return (
      <div
        ref={dropdownRefs[type]}
        className="absolute left-1/2 top-full z-50 mt-3 w-72 -translate-x-1/2 rounded-xl border border-gray-200 bg-white p-4 shadow-lg"
        onMouseEnter={() => openDropdown(type)}
        onMouseLeave={() => scheduleClose(type)}
      >
        <form onSubmit={(event) => handleDropdownSubmit(type, event)} className="space-y-3">
          <div className="space-y-1">
            <p className="text-sm font-semibold text-gray-900">{label}</p>
            <p className="text-xs text-gray-500">{description}</p>
          </div>
          <div className="space-y-2">
            <input
              ref={inputRefs[type]}
              type="password"
              value={inputValue}
              onFocus={() => openDropdown(type)}
              onBlur={() => scheduleClose(type)}
              onChange={(event) => handleInputChange(type, event.target.value)}
              placeholder={placeholder}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm text-gray-900 placeholder-gray-500 outline-none ring-1 ring-transparent transition-colors duration-150 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
            />
            <div className="flex items-center justify-between">
              {showSaved ? (
                <span className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-600">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    className="h-3.5 w-3.5"
                  >
                    <path
                      fillRule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 10-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clipRule="evenodd"
                    />
                  </svg>
                  Saved
                </span>
              ) : showError ? (
                <span className="inline-flex items-center gap-1 rounded-full bg-red-50 px-2 py-0.5 text-xs font-medium text-red-600">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    strokeWidth="1.5"
                    stroke="currentColor"
                    className="h-3.5 w-3.5"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  Save failed
                </span>
              ) : (
                <span className="text-xs text-gray-400">
                  {hasStoredValue ? 'Editing key' : 'Key not saved yet'}
                </span>
              )}
              <button
                type="submit"
                disabled={isSaving}
                className="rounded-full bg-blue-600 px-4 py-1 text-xs font-semibold text-white transition-colors duration-200 hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {isSaving ? 'Saving…' : 'Save'}
              </button>
            </div>
          </div>
        </form>
      </div>
    )
  }

  return (
    <>
      <nav className="bg-transparent shadow-sm relative z-10">
        <div className="w-full px-2 sm:px-4 lg:px-12 xl:px-16">
          <div className="flex justify-between">
            <div className="flex items-center">
              <a href="/" className="flex-shrink-0 flex items-center px-6 sm:px-8 md:px-10">
                <Cube />
              </a>
            </div>
            <div className="flex items-center px-6 py-4 sm:px-8 sm:py-4 md:px-10 md:py-5 border-l border-r border-gray-200 relative">
              <div className="flex items-center gap-6">
                <div
                  className="relative"
                  onMouseEnter={() => openDropdown('tavily')}
                  onMouseLeave={() => scheduleClose('tavily')}
                >
                  <button
                    type="button"
                    onFocus={() => openDropdown('tavily')}
                    onBlur={() => handleLogoBlur('tavily')}
                    onKeyDown={(event) => handleLogoKeyDown('tavily', event)}
                    className="rounded-full p-1 transition-transform duration-150 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:ring-offset-2 focus:ring-offset-white hover:scale-105"
                    aria-haspopup="true"
                    aria-expanded={activeDropdown === 'tavily'}
                    aria-label="Manage Tavily API key"
                  >
                    <img
                      src={tavilyLogo}
                      alt="Tavily logo"
                      className="h-8 w-auto object-contain drop-shadow-sm"
                    />
                  </button>
                  {renderDropdown(
                    'tavily',
                    'Tavily Search API Key',
                    'Enter your Tavily API key',
                    'Required for search agent lookups.'
                  )}
                </div>

                <div
                  className="relative"
                  onMouseEnter={() => openDropdown('gemini')}
                  onMouseLeave={() => scheduleClose('gemini')}
                >
                  <button
                    type="button"
                    onFocus={() => openDropdown('gemini')}
                    onBlur={() => handleLogoBlur('gemini')}
                    onKeyDown={(event) => handleLogoKeyDown('gemini', event)}
                    className="rounded-full p-1 transition-transform duration-150 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:ring-offset-2 focus:ring-offset-white hover:scale-105"
                    aria-haspopup="true"
                    aria-expanded={activeDropdown === 'gemini'}
                    aria-label="Manage Gemini API key"
                  >
                    <img
                      src={geminiLogo}
                      alt="Gemini logo"
                      className="h-8 w-auto object-contain drop-shadow-sm"
                    />
                  </button>
                  {renderDropdown(
                    'gemini',
                    'Gemini LLM API Key',
                    'Enter your Gemini API key',
                    'Used for AI writing and critiques.'
                  )}
                </div>

                <div className="flex items-center space-x-4">
                  <div className="text-right">
                    <div className="text-sm font-medium text-gray-900">John Doe</div>
                    <div className="text-xs text-gray-500">Software Engineer @ TechCorp</div>
                  </div>
                  <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center text-sm font-semibold text-gray-600">
                    JD
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </nav>
    </>
  )
}
