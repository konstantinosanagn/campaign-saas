'use client'

import React from 'react'
import * as XLSX from 'xlsx'

type SingleLeadPayload = { name: string; email: string; title: string; company: string }

type ImportedLead = {
  firstName: string
  lastName: string
  email: string
  title: string
  company: string
}

interface LeadFormProps {
  isOpen: boolean
  onClose: () => void
  onSubmit: (data: SingleLeadPayload) => void
  onBulkSubmit?: (leads: ImportedLead[]) => Promise<{ success: true } | { success: false; error?: string }>
  initialData?: SingleLeadPayload
  isEdit?: boolean
}

type LocalFormData = {
  firstName: string
  lastName: string
  email: string
  title: string
  company: string
}

const REQUIRED_HEADERS = ['First Name', 'Last Name', 'Company Email', 'Position/Title', 'Company Name']
const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/

const parseCsvText = (text: string): string[][] => {
  const rows: string[][] = []
  let currentField = ''
  let currentRow: string[] = []
  let insideQuotes = false

  const pushField = () => {
    currentRow.push(currentField)
    currentField = ''
  }

  const pushRow = () => {
    rows.push(currentRow)
    currentRow = []
  }

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i]

    if (char === '"') {
      const nextChar = text[i + 1]
      if (insideQuotes && nextChar === '"') {
        currentField += '"'
        i += 1
      } else {
        insideQuotes = !insideQuotes
      }
    } else if (char === ',' && !insideQuotes) {
      pushField()
    } else if ((char === '\n' || char === '\r') && !insideQuotes) {
      if (char === '\r' && text[i + 1] === '\n') {
        i += 1
      }
      pushField()
      pushRow()
    } else {
      currentField += char
    }
  }

  pushField()
  if (currentRow.length > 0) {
    pushRow()
  }

  return rows.filter((row) => row.length > 0)
}

const mapRowsToLeads = (rows: string[][]): { leads?: ImportedLead[]; error?: string } => {
  if (rows.length === 0) {
    return { error: 'Uploaded file is empty.' }
  }

  const headers = rows[0].map((header) => header.trim().replace(/^\ufeff/, ''))
  const normalizedHeaders = headers.map((header) => header.toLowerCase())
  const headerIndexMap: Record<string, number> = {}

  for (const requiredHeader of REQUIRED_HEADERS) {
    const normalizedHeader = requiredHeader.toLowerCase()
    const index = normalizedHeaders.indexOf(normalizedHeader)
    if (index === -1) {
      return { error: `Missing required column "${requiredHeader}".` }
    }
    headerIndexMap[normalizedHeader] = index
  }

  const dataRows = rows.slice(1)
  const leads: ImportedLead[] = []
  const errors: string[] = []

  dataRows.forEach((row, idx) => {
    const rowNumber = idx + 2
    const getValue = (header: string) => (row[headerIndexMap[header.toLowerCase()]] ?? '').trim()

    const firstName = getValue('First Name')
    const lastName = getValue('Last Name')
    const email = getValue('Company Email')
    const title = getValue('Position/Title')
    const company = getValue('Company Name')

    const hasValues = [firstName, lastName, email, title, company].some((value) => value.length > 0)
    if (!hasValues) {
      return
    }

    if (!firstName || !lastName || !email || !title || !company) {
      errors.push(`Row ${rowNumber}: All fields are required.`)
      return
    }

    if (!EMAIL_REGEX.test(email)) {
      errors.push(`Row ${rowNumber}: Invalid email format "${email}".`)
      return
    }

    leads.push({
      firstName,
      lastName,
      email,
      title,
      company
    })
  })

  if (errors.length > 0) {
    return { error: errors.join('\n') }
  }

  if (leads.length === 0) {
    return { error: 'No valid lead rows found in the uploaded file.' }
  }

  return { leads }
}

const convertFileToCsv = async (file: File): Promise<string> => {
  const lowerName = file.name.toLowerCase()
  if (lowerName.endsWith('.csv')) {
    return file.text()
  }

  if (lowerName.endsWith('.xlsx')) {
    const data = await file.arrayBuffer()
    const workbook = XLSX.read(data, { type: 'array' })
    if (!workbook.SheetNames.length) {
      throw new Error('Uploaded spreadsheet does not contain any sheets.')
    }
    const worksheet = workbook.Sheets[workbook.SheetNames[0]]
    return XLSX.utils.sheet_to_csv(worksheet)
  }

  throw new Error('Unsupported file type. Please upload a .csv or .xlsx file.')
}

export default function LeadForm({ isOpen, onClose, onSubmit, onBulkSubmit, initialData, isEdit = false }: LeadFormProps) {
  const [formData, setFormData] = React.useState<LocalFormData>({
    firstName: '',
    lastName: '',
    email: '',
    title: '',
    company: ''
  })
  const [uploadedFileName, setUploadedFileName] = React.useState<string | null>(null)
  const [fileError, setFileError] = React.useState<string | null>(null)
  const [isProcessingFile, setIsProcessingFile] = React.useState(false)

  const firstNameInputRef = React.useRef<HTMLInputElement>(null)
  const fileInputRef = React.useRef<HTMLInputElement>(null)

  React.useEffect(() => {
    if (isOpen && firstNameInputRef.current) {
      firstNameInputRef.current.focus()
    }
  }, [isOpen])

  React.useEffect(() => {
    if (isEdit && initialData) {
      const trimmedName = (initialData.name || '').trim()
      const nameParts = trimmedName.length > 0 ? trimmedName.split(/\s+/) : []
      const firstName = nameParts.shift() ?? ''
      const lastName = nameParts.join(' ')
      setFormData({
        firstName,
        lastName,
        email: initialData.email,
        title: initialData.title,
        company: initialData.company
      })
    } else {
      setFormData({ firstName: '', lastName: '', email: '', title: '', company: '' })
    }
  }, [isEdit, initialData, isOpen])

  React.useEffect(() => {
    if (!isOpen) {
      setUploadedFileName(null)
      setFileError(null)
      setIsProcessingFile(false)
    }
  }, [isOpen])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const trimmedFirst = formData.firstName.trim()
    const trimmedLast = formData.lastName.trim()
    const fullName = [trimmedFirst, trimmedLast].filter(Boolean).join(' ')
    onSubmit({
      name: fullName,
      email: formData.email.trim(),
      title: formData.title.trim(),
      company: formData.company.trim()
    })
    setFormData({ firstName: '', lastName: '', email: '', title: '', company: '' })
    setUploadedFileName(null)
    setFileError(null)
    onClose()
  }

  const handleClose = () => {
    setFormData({ firstName: '', lastName: '', email: '', title: '', company: '' })
    setUploadedFileName(null)
    setFileError(null)
    onClose()
  }

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
    if (!file || isEdit || !onBulkSubmit) {
      return
    }

    setFileError(null)
    setUploadedFileName(file.name)
    setIsProcessingFile(true)

    try {
      const csvText = await convertFileToCsv(file)
      const rows = parseCsvText(csvText)
      const { leads, error } = mapRowsToLeads(rows)

      if (error || !leads) {
        const message = error ?? 'Failed to parse uploaded file.'
        setFileError(message)
        window.alert(message)
        return
      }

      const result = await onBulkSubmit(leads)
      if (result.success) {
        handleClose()
      } else {
        const message = result.error ?? 'Failed to import leads.'
        setFileError(message)
        window.alert(message)
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to process uploaded file.'
      setFileError(message)
      window.alert(message)
    } finally {
      setIsProcessingFile(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-2">
            <h2 className="text-xl font-semibold text-gray-900">
              {isEdit ? 'Edit Lead' : 'Add Lead'}
            </h2>
            {!isEdit && (
              <>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv,.xlsx"
                  className="hidden"
                  data-testid="lead-import-input"
                  onChange={handleFileChange}
                />
                <button
                  type="button"
                  onClick={() => !isProcessingFile && fileInputRef.current?.click()}
                  className={`ml-3 text-blue-600 hover:text-blue-700 transition-colors duration-200 ${isProcessingFile ? 'opacity-50 cursor-not-allowed' : ''}`}
                  title="Upload CSV or Excel file"
                  disabled={isProcessingFile}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    className="w-4 h-4"
                    fill="currentColor"
                  >
                    <path d="M19.31 12.051c.381 0 .69.314.69.7v4.918c-.006.67-.127 1.2-.399 1.594c-.328.476-.908.692-1.747.737l-15.903-.002c-.646-.046-1.168-.302-1.507-.777c-.302-.423-.446-.95-.444-1.558V12.75c0-.386.309-.7.69-.7c.38 0 .688.314.688.7v4.913c0 .333.065.572.182.736c.081.114.224.184.44.201l15.817.001c.42-.023.627-.1.655-.14c.084-.123.146-.393.15-.8V12.75c0-.386.308-.7.689-.7ZM9.99 0c.224 0 .423.108.549.276l4.281 4.308c.27.272.272.715.004.99a.682.682 0 0 1-.974.003l-3.171-3.189v9.643c0 .387-.308.7-.689.7a.694.694 0 0 1-.69-.7V2.383L6.172 5.574a.682.682 0 0 1-.89.076l-.085-.074a.707.707 0 0 1-.002-.989L9.49.207a.682.682 0 0 1 .404-.202h.011A.462.462 0 0 1 9.977 0h.013Z" />
                  </svg>
                </button>
              </>
            )}
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

        {uploadedFileName && (
          <p className="text-sm text-blue-600 mb-4">Selected file: {uploadedFileName}</p>
        )}
        {isProcessingFile && (
          <p className="text-sm text-gray-600 mb-4">Processing file...</p>
        )}
        {fileError && (
          <p className="text-sm text-red-600 mb-4 whitespace-pre-line">{fileError}</p>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label htmlFor="first-name" className="block text-sm font-medium text-gray-700 mb-1">
                First Name
              </label>
              <input
                ref={firstNameInputRef}
                type="text"
                id="first-name"
                value={formData.firstName}
                onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                placeholder="Enter first name"
                required
              />
            </div>
            <div>
              <label htmlFor="last-name" className="block text-sm font-medium text-gray-700 mb-1">
                Last Name
              </label>
              <input
                type="text"
                id="last-name"
                value={formData.lastName}
                onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
                placeholder="Enter last name"
                required
              />
            </div>
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
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
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
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
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
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
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


