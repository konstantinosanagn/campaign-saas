'use client'

import React from 'react'

interface LeadFormProps {
  isOpen: boolean
  onClose: () => void
  onSubmit: (data: { name: string; email: string; title: string; company: string }) => void
  initialData?: { name: string; email: string; title: string; company: string }
  isEdit?: boolean
}

export default function LeadForm({ isOpen, onClose, onSubmit, initialData, isEdit = false }: LeadFormProps) {
  const [formData, setFormData] = React.useState({
    name: '',
    email: '',
    title: '',
    company: ''
  })

  const nameInputRef = React.useRef<HTMLInputElement>(null)

  React.useEffect(() => {
    if (isOpen && nameInputRef.current) {
      nameInputRef.current.focus()
    }
  }, [isOpen])

  React.useEffect(() => {
    if (isEdit && initialData) {
      setFormData(initialData)
    } else {
      setFormData({ name: '', email: '', title: '', company: '' })
    }
  }, [isEdit, initialData, isOpen])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit(formData)
    setFormData({ name: '', email: '', title: '', company: '' })
    onClose()
  }

  const handleClose = () => {
    setFormData({ name: '', email: '', title: '', company: '' })
    onClose()
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-gray-900">
            {isEdit ? 'Edit Lead' : 'Add New Lead'}
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
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
              Full Name
            </label>
            <input
              ref={nameInputRef}
              type="text"
              id="name"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-gray-900"
              placeholder="Enter full name"
              required
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
              Company Email
            </label>
            <input
              type="email"
              id="email"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-gray-900"
              placeholder="Enter company email"
              required
            />
          </div>

          <div>
            <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">
              Position/Title
            </label>
            <input
              type="text"
              id="title"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-gray-900"
              placeholder="Enter position or title"
              required
            />
          </div>

          <div>
            <label htmlFor="company" className="block text-sm font-medium text-gray-700 mb-1">
              Company Name
            </label>
            <input
              type="text"
              id="company"
              value={formData.company}
              onChange={(e) => setFormData({ ...formData, company: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-gray-900"
              placeholder="Enter company name"
              required
            />
          </div>

          <div className="flex justify-end space-x-3 pt-4">
            <button
              type="submit"
              className="px-4 py-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-colors duration-200 font-medium"
            >
              {isEdit ? 'Save Changes' : 'Add Lead'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}


