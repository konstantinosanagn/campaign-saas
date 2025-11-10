'use client'

import React from 'react'
import { useState } from 'react'
import { useRef } from 'react'

interface CampaignFormProps {
  isOpen: boolean
  onClose: () => void
  onSubmit: (data: { title: string; basePrompt: string }) => void
  initialData?: { index: number; title: string; basePrompt: string } | null
  isEdit?: boolean
}

export default function CampaignForm({ isOpen, onClose, onSubmit, initialData, isEdit = false }: CampaignFormProps) {
  const [title, setTitle] = useState('')
  const [basePrompt, setBasePrompt] = useState('')
  const titleInputRef = useRef<HTMLInputElement>(null)

  React.useEffect(() => {
    if (isOpen && titleInputRef.current) {
      titleInputRef.current.focus()
    }
  }, [isOpen])

  React.useEffect(() => {
    if (isEdit && initialData) {
      setTitle(initialData.title)
      setBasePrompt(initialData.basePrompt)
    } else {
      setTitle('')
      setBasePrompt('')
    }
  }, [isEdit, initialData, isOpen])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit({ title, basePrompt })
    setTitle('')
    setBasePrompt('')
    onClose()
  }

  const handleClose = () => {
    setTitle('')
    setBasePrompt('')
    onClose()
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
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
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 transition-all duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
              placeholder="Enter campaign title"
              required
            />
          </div>
          
          <div>
            <label htmlFor="basePrompt" className="block text-sm font-medium text-gray-700 mb-1">
              Base Prompt
            </label>
            <textarea
              id="basePrompt"
              value={basePrompt}
              onChange={(e) => setBasePrompt(e.target.value)}
              rows={4}
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 transition-all duration-150 resize-none focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
              placeholder="Provide information about your product, campaign, and/or company."
              required
            />
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


