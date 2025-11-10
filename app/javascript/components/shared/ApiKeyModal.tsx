import React, { useState, useEffect, useRef } from 'react'

interface ApiKeys {
  llmApiKey: string
  tavilyApiKey: string
}

interface ApiKeyModalProps {
  isOpen: boolean
  onClose: () => void
  onSave: (keys: ApiKeys) => void
  initialKeys: ApiKeys
}

export default function ApiKeyModal({ isOpen, onClose, onSave, initialKeys }: ApiKeyModalProps) {
  const [keys, setKeys] = useState<ApiKeys>(initialKeys)
  const [isLoading, setIsLoading] = useState(false)
  const [isEditing, setIsEditing] = useState(false)
  const llmInputRef = useRef<HTMLInputElement>(null)

  const hasKeys = initialKeys.llmApiKey || initialKeys.tavilyApiKey

  useEffect(() => {
    if (isOpen) {
      setKeys(initialKeys)
      setIsEditing(false)
      if (!hasKeys && llmInputRef.current) {
        llmInputRef.current.focus()
      }
    }
  }, [isOpen, initialKeys, hasKeys])

  const handleClose = () => {
    setKeys(initialKeys)
    setIsEditing(false)
    onClose()
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    try {
      await onSave(keys)
      setIsEditing(false)
      handleClose()
    } catch (error) {
      console.error('Failed to save API keys:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleEdit = () => {
    setIsEditing(true)
    setTimeout(() => {
      if (llmInputRef.current) {
        llmInputRef.current.focus()
      }
    }, 100)
  }

  const handleKeyChange = (keyType: keyof ApiKeys, value: string) => {
    setKeys(prev => ({
      ...prev,
      [keyType]: value
    }))
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-gray-900">
            API Key Settings
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

        {hasKeys && !isEditing ? (
          <div className="space-y-4">
            <div className="bg-green-50 border border-green-200 rounded-md p-4">
              <div className="flex items-center">
                <svg className="w-5 h-5 text-green-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span className="text-sm font-medium text-green-800">API Keys Saved</span>
              </div>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  LLM API Key
                </label>
                <div className="flex items-center justify-between bg-gray-50 border border-gray-200 rounded-md px-3 py-2">
                  <span className="text-sm text-gray-600">
                    {initialKeys.llmApiKey ? '••••••••••••' + initialKeys.llmApiKey.slice(-4) : 'Not provided'}
                  </span>
                  {initialKeys.llmApiKey && (
                    <span className="text-xs text-green-600 font-medium">Saved</span>
                  )}
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tavily Search API Key
                </label>
                <div className="flex items-center justify-between bg-gray-50 border border-gray-200 rounded-md px-3 py-2">
                  <span className="text-sm text-gray-600">
                    {initialKeys.tavilyApiKey ? '••••••••••••' + initialKeys.tavilyApiKey.slice(-4) : 'Not provided'}
                  </span>
                  {initialKeys.tavilyApiKey && (
                    <span className="text-xs text-green-600 font-medium">Saved</span>
                  )}
                </div>
              </div>
            </div>

            <div className="flex justify-end pt-4">
              <button
                type="button"
                onClick={handleEdit}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200"
              >
                Edit Keys
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSave} className="space-y-4">
            <div>
              <label htmlFor="llmApiKey" className="block text-sm font-medium text-gray-700 mb-1">
                LLM API Key
              </label>
              <input
                type="password"
                id="llmApiKey"
                ref={llmInputRef}
                value={keys.llmApiKey}
                onChange={(e) => handleKeyChange('llmApiKey', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 placeholder-gray-500 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                placeholder="Enter your LLM API key"
                autoFocus
              />
            </div>
            
            <div>
              <label htmlFor="tavilyApiKey" className="block text-sm font-medium text-gray-700 mb-1">
                Tavily Search API Key
              </label>
              <input
                type="password"
                id="tavilyApiKey"
                value={keys.tavilyApiKey}
                onChange={(e) => handleKeyChange('tavilyApiKey', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 placeholder-gray-500 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                placeholder="Enter your Tavily Search API key"
              />
            </div>

            <div className="flex justify-end pt-4">
              <button
                type="submit"
                disabled={isLoading}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
              >
                {isLoading ? 'Saving...' : 'Save Keys'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
