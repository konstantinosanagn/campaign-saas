'use client'

import React, { useEffect, useRef, useState } from 'react'
import Cube from '@/components/shared/Cube'
import { useApiKeys } from '@/hooks/useApiKeys'

type DropdownType = 'tavily' | 'gemini'

const TAVILY_LOGO_SRC = '/images/tavily-trans.png'
const GEMINI_LOGO_SRC = '/images/gemini-trans.png'

interface NavigationProps {
  user?: {
    first_name?: string | null;
    last_name?: string | null;
    name?: string | null;
    workspace_name?: string | null;
    job_title?: string | null;
  };
}

export default function Navigation({ user }: NavigationProps = {}) {
  const { keys: apiKeys, saveKeys } = useApiKeys()
  const [activeDropdown, setActiveDropdown] = useState<DropdownType | null>(null)
  const [userDropdownOpen, setUserDropdownOpen] = useState(false)
  const [inputValues, setInputValues] = useState({ tavily: '', gemini: '' })
  const [saving, setSaving] = useState({ tavily: false, gemini: false })
  const [status, setStatus] = useState<{ tavily: 'idle' | 'saved' | 'error'; gemini: 'idle' | 'saved' | 'error' }>({
    tavily: 'idle',
    gemini: 'idle'
  })
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const userDropdownRef = useRef<HTMLDivElement>(null)
  const dropdownRefs = {
    tavily: useRef<HTMLDivElement>(null),
    gemini: useRef<HTMLDivElement>(null)
  }
  const inputRefs = {
    tavily: useRef<HTMLInputElement>(null),
    gemini: useRef<HTMLInputElement>(null)
  }
  const closeDelay = 400

  const getStoredValue = (type: DropdownType) =>
    type === 'tavily' ? apiKeys.tavilyApiKey || '' : apiKeys.llmApiKey || ''

  const resetInputValue = (type: DropdownType) => {
    setInputValues(prev => ({
      ...prev,
      [type]: getStoredValue(type)
    }))
  }

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
      const isFocusInside = dropdownEl && activeEl ? dropdownEl.contains(activeEl) : false
      const isHovering = dropdownEl ? dropdownEl.matches(':hover') : false
      if (isFocusInside || isHovering) {
        return
      }
      setActiveDropdown(current => {
        if (current === type) {
          resetInputValue(type)
          return null
        }
        return current
      })
    }, delay)
  }

  const openDropdown = (type: DropdownType) => {
    clearCloseTimer()
    setActiveDropdown(current => {
      if (current && current !== type) {
        resetInputValue(current)
      }
      return type
    })
  }

  useEffect(() => {
    return () => {
      clearCloseTimer()
    }
  }, [])

  // Close user dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (userDropdownRef.current && !userDropdownRef.current.contains(event.target as Node)) {
        setUserDropdownOpen(false)
      }
    }

    if (userDropdownOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [userDropdownOpen])

  const handleSignOut = async () => {
    try {
      // Create a form and submit it to sign out (Devise uses DELETE method)
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = '/logout'
      
      // Add CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      if (csrfToken) {
        const csrfInput = document.createElement('input')
        csrfInput.type = 'hidden'
        csrfInput.name = 'authenticity_token'
        csrfInput.value = csrfToken
        form.appendChild(csrfInput)
      }
      
      // Add method override for DELETE
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'delete'
      form.appendChild(methodInput)
      
      document.body.appendChild(form)
      form.submit()
    } catch (error) {
      console.error('Error signing out:', error)
      // Fallback: redirect to logout URL
      window.location.href = '/logout'
    }
  }

  // Sync input values from API keys prop
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- Syncing state from props is intentional
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
      resetInputValue(type)
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
        className="absolute left-1/2 top-full z-[9999] mt-3 w-72 -translate-x-1/2 rounded-xl border border-gray-200 bg-white p-4 shadow-lg"
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
              autoComplete="off"
              className={`w-full rounded-md border px-3 py-2 text-sm text-gray-900 placeholder-gray-500 outline-none transition-colors duration-150 ${
                showError
                  ? 'border-red-300 focus:border-red-400 focus:ring-2 focus:ring-red-200 focus:ring-offset-1 focus:ring-offset-white'
                  : showSaved && !isDirty
                    ? 'border-emerald-300 ring-1 ring-emerald-100 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white'
                    : 'border-gray-300 ring-1 ring-transparent focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white'
              }`}
            />
            <div className="flex items-center justify-between">
              {showError ? (
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
      <nav className="bg-transparent shadow-sm relative z-[10000]">
        <div className="w-full px-2 sm:px-4 lg:px-12 xl:px-16">
          <div className="flex justify-between">
            <div className="flex items-center">
              <a 
                href="/login" 
                className="flex-shrink-0 flex items-center px-6 sm:px-8 md:px-10"
                style={{ cursor: 'pointer' }}
              >
                <Cube />
              </a>
            </div>
            <div className="flex items-center gap-6">
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
                  className="rounded-full p-0.5 transition-transform duration-150 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:ring-offset-2 focus:ring-offset-white hover:scale-105"
                    aria-haspopup="true"
                    aria-expanded={activeDropdown === 'tavily'}
                    aria-label="Manage Tavily API key"
                  >
                    <img
                      src={TAVILY_LOGO_SRC}
                      alt="Tavily logo"
                      className="h-6 w-auto object-contain drop-shadow-sm"
                    />
                  </button>
                  <div
                    className={`mx-auto mt-1 h-1.5 w-1.5 rounded-full ${
                      apiKeys.tavilyApiKey ? 'bg-emerald-500' : 'bg-red-500'
                    }`}
                  />
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
                  className="rounded-full p-0.5 transition-transform duration-150 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:ring-offset-2 focus:ring-offset-white hover:scale-105"
                    aria-haspopup="true"
                    aria-expanded={activeDropdown === 'gemini'}
                    aria-label="Manage Gemini API key"
                  >
                    <img
                      src={GEMINI_LOGO_SRC}
                      alt="Gemini logo"
                      className="h-6 w-auto object-contain drop-shadow-sm"
                    />
                  </button>
                  <div
                    className={`mx-auto mt-1 h-1.5 w-1.5 rounded-full ${
                      apiKeys.llmApiKey ? 'bg-emerald-500' : 'bg-red-500'
                    }`}
                  />
                  {renderDropdown(
                    'gemini',
                    'Gemini LLM API Key',
                    'Enter your Gemini API key',
                    'Used for AI writing and critiques.'
                  )}
                </div>
              </div>

              <div className="flex items-center px-6 py-4 sm:px-8 sm:py-4 md:px-10 md:py-5 border-l border-r border-gray-200 relative" ref={userDropdownRef}>
                <div className="flex items-center space-x-4">
                  <div className="text-right">
                    <div className="text-sm font-medium text-gray-900">
                      {user?.first_name && user?.last_name
                        ? `${user.first_name} ${user.last_name}`
                        : user?.name || 'User'}
                    </div>
                    <div className="text-xs text-gray-500">
                      {user?.job_title && user?.workspace_name
                        ? `${user.job_title} @ ${user.workspace_name}`
                        : user?.job_title
                        ? user.job_title
                        : user?.workspace_name
                        ? user.workspace_name
                        : 'User'}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setUserDropdownOpen(!userDropdownOpen)}
                    className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center text-sm font-semibold text-gray-600 hover:bg-gray-300 transition-colors cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-200 focus:ring-offset-2"
                    aria-label="User menu"
                    aria-expanded={userDropdownOpen}
                    aria-haspopup="true"
                  >
                    {user?.first_name && user?.last_name
                      ? `${user.first_name[0]}${user.last_name[0]}`.toUpperCase()
                      : user?.name
                      ? user.name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()
                      : 'U'}
                  </button>
                </div>
                
                {/* User dropdown menu */}
                {userDropdownOpen && (
                  <div className="absolute right-0 top-full mt-2 w-48 rounded-xl border border-gray-200 bg-white shadow-lg z-[9999]">
                    <div className="py-1">
                      <button
                        type="button"
                        onClick={handleSignOut}
                        className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
                      >
                        Sign out
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </nav>
    </>
  )
}
