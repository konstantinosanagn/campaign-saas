'use client'

import React from 'react'
import { AgentConfig } from '@/types'

interface AgentSettingsModalProps {
  isOpen: boolean
  onClose: () => void
  agentName: 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE'
  config: AgentConfig | null
  onSave: (config: AgentConfig) => Promise<void>
  loading: boolean
}

export default function AgentSettingsModal({ 
  isOpen, 
  onClose, 
  agentName, 
  config, 
  onSave, 
  loading 
}: AgentSettingsModalProps) {
  const [enabled, setEnabled] = React.useState(true)
  const [productInfo, setProductInfo] = React.useState('')
  const [senderCompany, setSenderCompany] = React.useState('')
  const [saving, setSaving] = React.useState(false)

  React.useEffect(() => {
    if (config) {
      setEnabled(config.enabled)
      setProductInfo(config.settings?.product_info || '')
      setSenderCompany(config.settings?.sender_company || '')
    } else {
      setEnabled(true)
      setProductInfo('')
      setSenderCompany('')
    }
  }, [config, isOpen])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    setSaving(true)
    try {
      const settings: Record<string, unknown> = { ...(config?.settings ?? {}) }
      
      // Only include settings for WRITER agent
      if (agentName === 'WRITER') {
        if (productInfo.trim()) {
          settings['product_info'] = productInfo
        } else {
          delete settings['product_info']
        }

        if (senderCompany.trim()) {
          settings['sender_company'] = senderCompany
        } else {
          delete settings['sender_company']
        }
      } else {
        delete settings['product_info']
        delete settings['sender_company']
      }
      
      const configToSave: AgentConfig = {
        id: config?.id,
        agentName,
        enabled,
        settings
      }
      
      await onSave(configToSave)
      onClose()
    } catch (error) {
      console.error('Failed to save agent config:', error)
    } finally {
      setSaving(false)
    }
  }

  const handleClose = () => {
    if (config) {
      setEnabled(config.enabled)
      setProductInfo(config.settings?.product_info || '')
      setSenderCompany(config.settings?.sender_company || '')
    }
    onClose()
  }

  const getAgentDescription = () => {
    switch (agentName) {
      case 'SEARCH':
        return 'Search agent researches information about target companies using web search.'
      case 'WRITER':
        return 'Writer agent generates personalized email content based on research findings.'
      case 'DESIGN':
        return 'Design agent applies formatting (bold, italic, links, etc.) to email content.'
      case 'CRITIQUE':
        return 'Critique agent reviews and provides feedback on generated emails.'
      default:
        return ''
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-4">
          <div>
            <h2 className="text-xl font-semibold text-gray-900">
              {agentName} Agent Settings
            </h2>
            <p className="text-sm text-gray-600 mt-1">
              {getAgentDescription()}
            </p>
          </div>
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
          {/* Enable/Disable Toggle */}
          <div className="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
            <div>
              <label htmlFor="enabled" className="text-sm font-medium text-gray-900">
                Enable {agentName} Agent
              </label>
              <p className="text-xs text-gray-500 mt-0.5">
                {enabled ? 'Agent will run during execution' : 'Agent will be skipped'}
              </p>
            </div>
            <button
              type="button"
              onClick={() => setEnabled(!enabled)}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                enabled ? 'bg-blue-600' : 'bg-gray-300'
              }`}
            >
              <span
                className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                  enabled ? 'translate-x-6' : 'translate-x-1'
                }`}
              />
            </button>
          </div>

          {/* Agent-specific settings */}
          {agentName === 'WRITER' && (
            <>
              <div>
                <label htmlFor="productInfo" className="block text-sm font-medium text-gray-700 mb-1">
                  Product Information
                </label>
                <textarea
                  id="productInfo"
                  value={productInfo}
                  onChange={(e) => setProductInfo(e.target.value)}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 resize-none transition-all duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                  placeholder="Describe your product or service..."
                />
                <p className="text-xs text-gray-500 mt-1">
                  This information will be used to personalize the email content
                </p>
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
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 transition-all duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                  placeholder="Enter your company name"
                />
              </div>
            </>
          )}

          {agentName !== 'WRITER' && (
            <div className="text-center py-4 text-gray-500 text-sm">
              No configurable settings available for {agentName} agent
            </div>
          )}

          <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
            <button
              type="button"
              onClick={handleClose}
              className="px-4 py-2 text-gray-700 bg-gray-100 rounded-full hover:bg-gray-200 transition-colors duration-200 font-medium"
              disabled={saving}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving || loading}
              className="px-4 py-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-colors duration-200 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? 'Saving...' : 'Save Settings'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

