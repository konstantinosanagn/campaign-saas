'use client'

import React, { useState } from 'react'
import Cube from '@/components/Cube'
import ApiKeyModal from '@/components/ApiKeyModal'
import { useApiKeys } from '@/hooks/useApiKeys'

export default function Navigation() {
  const [isApiKeyModalOpen, setIsApiKeyModalOpen] = useState(false)
  const { keys: apiKeys, saveKeys } = useApiKeys()
  
  const handleSaveApiKeys = async (keys: { llmApiKey: string; tavilyApiKey: string }) => {
    const success = await saveKeys(keys)
    if (!success) {
      console.error('Failed to save API keys')
    }
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
              <div className="flex items-center space-x-4">
                <div className="text-right">
                  <div className="text-sm font-medium text-gray-900">John Doe</div>
                  <div className="text-xs text-gray-500">Software Engineer @ TechCorp</div>
                </div>
                <button
                  onClick={() => setIsApiKeyModalOpen(true)}
                  className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center hover:bg-gray-300 transition-colors duration-200 cursor-pointer"
                >
                  <div className="w-6 h-6 bg-gray-400 rounded-full"></div>
                </button>
              </div>
            </div>
          </div>
        </div>
      </nav>
      
      <ApiKeyModal
        isOpen={isApiKeyModalOpen}
        onClose={() => setIsApiKeyModalOpen(false)}
        onSave={handleSaveApiKeys}
        initialKeys={apiKeys}
      />
    </>
  )
}
