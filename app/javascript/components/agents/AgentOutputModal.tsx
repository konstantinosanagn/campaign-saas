'use client'

import React from 'react'
import { AgentOutput as AgentOutputType } from '@/types'

type SearchSource = {
  title?: string
  url?: string
  content?: string
  snippet?: string
  publishedAt?: string
  score?: number
}

type SearchEntityData = {
  domain?: string
  name?: string
  sources?: Array<Record<string, unknown> | string | null>
  [key: string]: unknown
}

type SearchOutputData = {
  domain?: string | SearchEntityData | null
  recipient?: string | SearchEntityData | null
  sources?: Array<Record<string, unknown> | string | null>
  [key: string]: unknown
}

interface AgentOutputModalProps {
  isOpen: boolean
  onClose: () => void
  leadName: string
  leadId?: number
  outputs: AgentOutputType[]
  loading: boolean
  onUpdateOutput?: (leadId: number, agentName: string, newContent: string) => Promise<void>
  onUpdateSearchOutput?: (leadId: number, agentName: string, updatedData: SearchOutputData) => Promise<void>
  initialTab?: 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE' | 'ALL'
}

const formatTimestamp = (timestamp: string) => {
  if (!timestamp) {
    return 'N/A'
  }

  const date = new Date(timestamp)
  if (Number.isNaN(date.getTime())) {
    return timestamp
  }

  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
  }).format(date)
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value)

const isValidSourcesArray = (value: unknown): value is Array<Record<string, unknown> | string | null> => {
  if (!Array.isArray(value)) return false
  return value.every((item) => item == null || typeof item === 'string' || isRecord(item))
}

const isSearchOutputData = (data: unknown): data is SearchOutputData => {
  if (!isRecord(data)) return false
  const candidate = data as Record<string, unknown>

  if (candidate.sources !== undefined && !isValidSourcesArray(candidate.sources)) {
    return false
  }

  const domain = candidate.domain
  if (domain !== undefined && domain !== null && !(typeof domain === 'string' || isRecord(domain))) {
    return false
  }
  if (isRecord(domain) && domain.sources !== undefined && !isValidSourcesArray(domain.sources)) {
    return false
  }

  const recipient = candidate.recipient
  if (recipient !== undefined && recipient !== null && !(typeof recipient === 'string' || isRecord(recipient))) {
    return false
  }
  if (isRecord(recipient) && recipient.sources !== undefined && !isValidSourcesArray(recipient.sources)) {
    return false
  }

  return true
}

const toRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' ? (value as Record<string, unknown>) : {}

const getStringValue = (record: Record<string, unknown>, key: string): string => {
  const value = record[key]
  return typeof value === 'string' ? value : ''
}

const extractTextValue = (value: unknown, preferredKeys: string[]): string | undefined => {
  if (typeof value === 'string') {
    const trimmed = value.trim()
    return trimmed.length > 0 ? trimmed : undefined
  }

  if (!isRecord(value)) return undefined

  for (const key of preferredKeys) {
    const candidate = value[key]
    if (typeof candidate === 'string' && candidate.trim().length > 0) {
      return candidate
    }
  }

  return undefined
}

const toSourcesArray = (value: unknown): Array<Record<string, unknown> | string | null> => {
  if (!Array.isArray(value)) return []
  return value
}

const sanitizeSource = (source: unknown): SearchSource => {
  if (source == null) {
    return {}
  }

  if (typeof source === 'string') {
    return { title: source }
  }

  if (!isRecord(source)) {
    return {}
  }

  const record = source as Record<string, unknown>
  const rawTitle = record['title'] ?? record['domain'] ?? record['name']
  const rawUrl = record['url'] ?? record['link']
  const rawContent = record['content'] ?? record['snippet'] ?? record['description']
  const rawPublishedAt = record['published_at'] ?? record['publishedAt'] ?? record['date']
  const rawScore = record['score']

  return {
    title: typeof rawTitle === 'string' ? rawTitle : undefined,
    url: typeof rawUrl === 'string' ? rawUrl : undefined,
    content: typeof rawContent === 'string' ? rawContent : undefined,
    snippet: typeof record['snippet'] === 'string' ? record['snippet'] : undefined,
    publishedAt: typeof rawPublishedAt === 'string' ? rawPublishedAt : undefined,
    score: typeof rawScore === 'number' ? rawScore : undefined
  }
}

export default function AgentOutputModal({
  isOpen,
  onClose,
  leadName,
  leadId,
  outputs,
  loading,
  onUpdateOutput,
  onUpdateSearchOutput,
  initialTab = 'ALL'
}: AgentOutputModalProps) {
  const [activeTab, setActiveTab] = React.useState<'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE' | 'ALL'>(initialTab)
  const [editingWriterOutput, setEditingWriterOutput] = React.useState(false)
  const [editingDesignOutput, setEditingDesignOutput] = React.useState(false)
  const [editedEmail, setEditedEmail] = React.useState('')
  const [editedDesignEmail, setEditedDesignEmail] = React.useState('')
  const [saving, setSaving] = React.useState(false)
  const [searchOutputData, setSearchOutputData] = React.useState<SearchOutputData | null>(null)
  const [removingSourceIndex, setRemovingSourceIndex] = React.useState<number | null>(null)
  const textareaRef = React.useRef<HTMLTextAreaElement>(null)
  const removeSourceTimeoutRef = React.useRef<ReturnType<typeof setTimeout> | null>(null)
  const hasLocalChangesRef = React.useRef(false) // Track if we have local changes that shouldn't be overwritten
  const isInitialLoadRef = React.useRef(true) // Track if this is the initial load when modal opens


  React.useEffect(() => {
    if (isOpen) {
      // Reset flags when modal opens for the first time
      if (isInitialLoadRef.current) {
        hasLocalChangesRef.current = false
        isInitialLoadRef.current = false
      }
      
      // Set the active tab based on initialTab prop
      setActiveTab(initialTab)
      
      setEditingWriterOutput(false)
      setEditingDesignOutput(false)
      setEditedEmail('')
      setEditedDesignEmail('')
      
      // Only update search output data if:
      // 1. We don't have local changes (hasLocalChangesRef is false)
      // 2. We're not currently removing a source
      // 3. We don't already have searchOutputData (initial load only)
      // This prevents overwriting user's local edits when outputs changes
      if (!hasLocalChangesRef.current && removingSourceIndex === null && searchOutputData === null) {
        const searchOutput = outputs.find(o => o.agentName === 'SEARCH')
        setSearchOutputData(
          searchOutput && isSearchOutputData(searchOutput.outputData)
            ? searchOutput.outputData
            : null
        )
      }
    } else {
      // Reset flags when modal closes
      hasLocalChangesRef.current = false
      isInitialLoadRef.current = true
      setSearchOutputData(null) // Clear data when modal closes
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen, initialTab, outputs, removingSourceIndex]) // Removed searchOutputData from deps to prevent loops

  // Cleanup timeout on unmount
  React.useEffect(() => {
    return () => {
      if (removeSourceTimeoutRef.current) {
        clearTimeout(removeSourceTimeoutRef.current)
      }
    }
  }, [])

  if (!isOpen) return null

  const getTabOutputs = () => {
    if (activeTab === 'ALL') return outputs
    return outputs.filter(o => o.agentName === activeTab)
  }

  const handleRemoveSource = async (index: number) => {
    if (!leadId || !searchOutputData || !onUpdateSearchOutput) return
    if (removingSourceIndex !== null) return // Prevent concurrent removals
    if (!Array.isArray(searchOutputData.sources)) {
      console.warn('Search output data does not include a removable sources array.')
      return
    }
    
    // Clear any pending timeout
    if (removeSourceTimeoutRef.current) {
      clearTimeout(removeSourceTimeoutRef.current)
      removeSourceTimeoutRef.current = null
    }
    
    setRemovingSourceIndex(index)
    const previousData = searchOutputData

    // Create updated sources array without the removed item
    const updatedSources = [...searchOutputData.sources]
    updatedSources.splice(index, 1)

    // Create updated search output data
    const updatedData: SearchOutputData = {
      ...searchOutputData,
      sources: updatedSources
    }
    
    // Mark that we have local changes to prevent useEffect from overwriting
    hasLocalChangesRef.current = true
    
    // Update local state immediately for better UX
    setSearchOutputData(updatedData)
    
    // Save to backend with debouncing to prevent rate limiting
    removeSourceTimeoutRef.current = setTimeout(async () => {
      try {
        await onUpdateSearchOutput(leadId, 'SEARCH', updatedData)
        // Keep the flag set - we have local changes that are now saved
        // The flag will be reset when the modal closes or when we explicitly want to sync
        // This prevents the useEffect from overwriting our local state if outputs changes
      } catch (error) {
        console.error('Failed to remove source:', error)
        // Revert on error
        setSearchOutputData(previousData)
        hasLocalChangesRef.current = false
        
        // Check if it's a rate limit error
        const errorMessage = error instanceof Error ? error.message : String(error)
        if (errorMessage.includes('429') || errorMessage.includes('Too Many Requests')) {
          alert('Too many requests. Please wait a moment before removing more sources.')
        } else {
          alert('Failed to remove source. Please try again.')
        }
      } finally {
        setRemovingSourceIndex(null)
        removeSourceTimeoutRef.current = null
      }
    }, 500) // 500ms debounce to prevent rate limiting
  }

  const formatSearchOutput = (output: SearchOutputData | null) => {
    const data = searchOutputData || output
    if (!data) return null
    
    if (!data.sources && (data.title || data.url || data.content)) {
      data.sources = [data]
    }

    if (!Array.isArray(data.sources)) {
      const ps = data.personalization_signals
      if (ps && typeof ps === "object" && ps !== null) {
        const psRecord = ps as Record<string, unknown>
        const recipientSources = Array.isArray(psRecord.recipient) ? psRecord.recipient : []
        const companySources = Array.isArray(psRecord.company) ? psRecord.company : []
        const combined = [...recipientSources, ...companySources]
        if (combined.length > 0) {
          data.sources = combined
        } else {
          data.sources = []
        }
      } else {
        data.sources = []
      }
    }

    const company =
      extractTextValue(data.target_identity, ['company', 'organization', 'domain']) ??
      extractTextValue(data.domain, ['name', 'company']) ??
      'Not provided'

    const recipientName =
      extractTextValue(data.target_identity, ['name', 'full_name', 'recipient']) ??
      extractTextValue(data.recipient, ['name']) ??
      'Not provided'

    const recipientTitle =
      extractTextValue(data.target_identity, ['job_title', 'title']) ?? ''

    const recipientLabel = recipientTitle
      ? `${recipientName} (${recipientTitle})`
      : recipientName


    const summary = extractTextValue(data, ['summary', 'notes', 'description'])

    const outputDataRecord = data.outputData as Record<string, unknown> | null | undefined
    const primarySources = Array.isArray(data.sources) ? data.sources : Array.isArray(outputDataRecord?.sources)
      ? outputDataRecord?.sources
      : null

    const domainRecord = typeof data.domain === 'string' || data.domain == null ? null : toRecord(data.domain)
    const recipientRecord = typeof data.recipient === 'string' || data.recipient == null ? null : toRecord(data.recipient)

    const personalizationRecord = isRecord(data.personalization_signals)
      ? toRecord(data.personalization_signals)
      : null

    const fallbackSources = [
      ...(domainRecord ? toSourcesArray(domainRecord['sources']) : []),
      ...(recipientRecord ? toSourcesArray(recipientRecord['sources']) : []),
      ...(personalizationRecord
        ? [
            ...toSourcesArray(personalizationRecord['recipient']),
            ...toSourcesArray(personalizationRecord['company']),
          ]
        : [])
    ]


    const rawSources = primarySources ?? fallbackSources
    // Cap sources at 10 to prevent displaying more than the limit
    const cappedRawSources = rawSources.slice(0, 10)
    const sources = cappedRawSources.map(sanitizeSource)
    const sourcesCount = sources.length
    const hasRemovableSources = Boolean(primarySources && leadId && onUpdateSearchOutput)

    return (
      <div className="space-y-4">
        <div className="space-y-1">
          <h4 className="font-semibold text-gray-900">Search Summary</h4>
          <p className="text-sm text-gray-600">
            <span className="font-medium text-gray-700">Domain:</span>{' '}
            {company}
          </p>
          <p className="text-sm text-gray-600">
            <span className="font-medium text-gray-700">Recipient:</span>{' '}
            {recipientLabel}
          </p>
          <p className="text-sm text-gray-600">
            Found {sourcesCount} source{sourcesCount === 1 ? '' : 's'}
            {hasRemovableSources && sourcesCount > 0 ? ' (click X to remove)' : ''}
          </p>
          {summary && (
            <p className="text-sm text-gray-600 whitespace-pre-wrap">
              {summary}
            </p>
          )}
        </div>

        {Array.isArray(data.inferred_focus_areas) && data.inferred_focus_areas.length > 0 && (
          <div className="mb-3">
            <h4 className="font-semibold text-gray-900">Focus Areas</h4>
            <ul className="list-disc list-inside text-sm text-gray-700">
              {data.inferred_focus_areas.map((area: string, i: number) => (
                <li key={i}>{area}</li>
              ))}
            </ul>
          </div>
        )}

        {sourcesCount > 0 ? (
          <div className="space-y-3">
            {sources.map((source: Record<string, unknown>, idx: number) => {
              const title = (typeof source.title === 'string' && source.title.trim().length > 0) ? source.title : undefined
              const url = (typeof source.url === 'string' && source.url.trim().length > 0) ? source.url : undefined
              const description = (typeof source.content === 'string' && source.content.trim().length > 0)
                ? source.content
                : (typeof source.snippet === 'string' && source.snippet.trim().length > 0)
                  ? source.snippet
                  : undefined
              const publishedAt = (typeof source.publishedAt === 'string' && source.publishedAt.trim().length > 0)
                ? source.publishedAt
                : undefined
              const scoreDisplay = typeof source.score === 'number' ? source.score.toFixed(2) : undefined
              // Always include index to ensure unique keys even when URLs are duplicated
              const key = `${url ?? title ?? 'source'}-${idx}`

              return (
                <div
                  key={key}
                  className="border border-gray-200 rounded-lg p-3 bg-gray-50 relative hover:shadow-md transition-shadow"
                >
                  {hasRemovableSources && (
                    <button
                      onClick={() => handleRemoveSource(idx)}
                      disabled={removingSourceIndex !== null}
                      className={`absolute top-2 right-2 p-1 rounded transition-colors duration-200 ${
                        removingSourceIndex === idx
                          ? 'text-gray-400 cursor-wait'
                          : 'text-gray-500 hover:text-red-600 hover:bg-red-50 cursor-pointer'
                      }`}
                      title={removingSourceIndex === idx ? 'Removing...' : 'Remove this source'}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth="1.5"
                        stroke="currentColor"
                        className="w-5 h-5"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M6 18L18 6M6 6l12 12"
                        />
                      </svg>
                    </button>
                  )}
                  <h5 className="font-medium text-gray-900 mb-1 pr-8">{title ?? `Source ${idx + 1}`}</h5>
                  {url ? (
                    <a
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm text-blue-600 hover:underline truncate block"
                    >
                      {url}
                    </a>
                  ) : (
                    <span className="text-sm text-gray-500">No link provided</span>
                  )}
                  {description && (
                    <p className="text-sm text-gray-600 mt-2 whitespace-pre-wrap line-clamp-4">
                      {description}
                    </p>
                  )}
                  {(publishedAt || scoreDisplay) && (
                    <div className="mt-2 text-xs text-gray-500 flex flex-wrap gap-3">
                      {publishedAt && <span>Published: {publishedAt}</span>}
                      {scoreDisplay && <span>Score: {scoreDisplay}</span>}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        ) : (
          <div className="text-center py-4 text-gray-500">
            <p>No sources were returned for this search.</p>
            {!hasRemovableSources && fallbackSources.length > 0 && (
              <p className="text-xs text-gray-400 mt-1">
                Displaying combined sources from domain and recipient context.
              </p>
            )}
          </div>
        )}
      </div>
    )
  }

  const handleSaveWriterOutput = async () => {
    if (!leadId || !onUpdateOutput) return
    
    setSaving(true)
    try {
      await onUpdateOutput(leadId, 'WRITER', editedEmail)
      setEditingWriterOutput(false)
    } catch (error) {
      console.error('Failed to save writer output:', error)
      // You could add error state here
    } finally {
      setSaving(false)
    }
  }

  const handleSaveDesignOutput = async () => {
    if (!leadId || !onUpdateOutput) return
    
    setSaving(true)
    try {
      await onUpdateOutput(leadId, 'DESIGN', editedDesignEmail)
      setEditingDesignOutput(false)
    } catch (error) {
      console.error('Failed to save design output:', error)
    } finally {
      setSaving(false)
    }
  }

  // Helper function to apply formatting
  const applyFormatting = (format: 'bold' | 'italic' | 'strikethrough' | 'code' | 'link' | 'quote', textarea: HTMLTextAreaElement) => {
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const selectedText = editedDesignEmail.substring(start, end)
    
    let formatted = ''
    let newPos = start
    
    if (selectedText) {
      switch (format) {
        case 'bold':
          formatted = `**${selectedText}**`
          newPos = start + selectedText.length + 4
          break
        case 'italic':
          formatted = `*${selectedText}*`
          newPos = start + selectedText.length + 2
          break
        case 'strikethrough':
          formatted = `~~${selectedText}~~`
          newPos = start + selectedText.length + 4
          break
        case 'code':
          formatted = `\`${selectedText}\``
          newPos = start + selectedText.length + 2
          break
        case 'link':
          formatted = `[${selectedText}](url)`
          newPos = start + selectedText.length + 3 // Position after "url)"
          break
        case 'quote':
          formatted = `> ${selectedText}`
          newPos = start + selectedText.length + 2
          break
      }
      const newText = editedDesignEmail.substring(0, start) + formatted + editedDesignEmail.substring(end)
      setEditedDesignEmail(newText)
      
      setTimeout(() => {
        textarea.focus()
        if (format === 'link') {
          textarea.setSelectionRange(newPos - 4, newPos - 1) // Select "url" part
        } else {
          textarea.setSelectionRange(newPos, newPos)
        }
      }, 0)
    } else {
      // Insert formatting markers at cursor
      let marker = ''
      switch (format) {
        case 'bold':
          marker = '****'
          newPos = start + 2
          break
        case 'italic':
          marker = '**'
          newPos = start + 1
          break
        case 'strikethrough':
          marker = '~~~~'
          newPos = start + 2
          break
        case 'code':
          marker = '``'
          newPos = start + 1
          break
        case 'link':
          marker = '[]()'
          newPos = start + 1
          break
        case 'quote':
          marker = '> '
          newPos = start + 2
          break
      }
      const newText = editedDesignEmail.substring(0, start) + marker + editedDesignEmail.substring(start)
      setEditedDesignEmail(newText)
      
      setTimeout(() => {
        textarea.focus()
        if (format === 'link') {
          textarea.setSelectionRange(start + 1, start + 1) // Position inside []
        } else {
          textarea.setSelectionRange(newPos, newPos)
        }
      }, 0)
    }
  }

  const formatWriterOutput = (output: Record<string, unknown>) => {
    const email = getStringValue(output, 'email')
    
    if (editingWriterOutput) {
      return (
        <div className="space-y-4">
          <textarea
            value={editedEmail}
            onChange={(e) => setEditedEmail(e.target.value)}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg text-sm text-gray-900 font-mono resize-y min-h-[200px] outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
            placeholder="Edit email content..."
          />
          <div className="flex justify-end space-x-3">
            <button
              onClick={() => {
                setEditingWriterOutput(false)
                setEditedEmail('')
              }}
              className="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 transition-colors duration-200 text-sm font-medium"
              disabled={saving}
            >
              Cancel
            </button>
            <button
              onClick={handleSaveWriterOutput}
              disabled={saving || !editedEmail.trim()}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </div>
      )
    }
    
    return (
      <div className="space-y-4">
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 relative group">
          <pre className="whitespace-pre-wrap text-sm text-gray-900 font-mono">{email}</pre>
          {leadId && onUpdateOutput && (
            <button
              onClick={() => {
                setEditedEmail(email)
                setEditingWriterOutput(true)
              }}
              className="absolute top-2 right-2 p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors duration-200 opacity-0 group-hover:opacity-100"
              title="Edit email"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-5 h-5">
                <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125" />
              </svg>
            </button>
          )}
        </div>
      </div>
    )
  }

  // Helper to render markdown formatted text
  const renderMarkdown = (text: string) => {
    // Enhanced markdown rendering: **bold**, *italic*, ~~strikethrough~~, `code`, [links](url), >quotes
    const parts: Array<string | React.ReactNode> = []
    let lastIndex = 0
    let key = 0
    
    // Match patterns in order of specificity (most specific first)
    const patterns = [
      { regex: /\*\*(.+?)\*\*/g, type: 'bold' },
      { regex: /~~(.+?)~~/g, type: 'strikethrough' },
      { regex: /`(.+?)`/g, type: 'code' },
      { regex: /\[(.+?)\]\((.+?)\)/g, type: 'link' },
      { regex: /^>\s+(.+)$/gm, type: 'quote' },
      { regex: /(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, type: 'italic' }
    ]
    
    const matches: Array<{start: number, end: number, text: string, type: string, url?: string}> = []
    
    // Collect all matches
    patterns.forEach(({ regex, type }) => {
      let match
      regex.lastIndex = 0 // Reset regex
      while ((match = regex.exec(text)) !== null) {
        const isOverlapping = matches.some(m => 
          (match!.index >= m.start && match!.index < m.end) ||
          (match!.index + match![0].length > m.start && match!.index + match![0].length <= m.end)
        )
        if (!isOverlapping) {
          matches.push({
            start: match.index,
            end: match.index + match[0].length,
            text: type === 'link' ? match[1] : match[1],
            type: type,
            url: type === 'link' ? match[2] : undefined
          })
        }
      }
    })
    
    // Sort matches by position
    matches.sort((a, b) => a.start - b.start)
    
    // Build parts array
    matches.forEach(m => {
      if (m.start > lastIndex) {
        // Check if this is a quote line
        const beforeText = text.substring(lastIndex, m.start)
        const lines = beforeText.split('\n')
        lines.forEach((line, idx) => {
          if (idx < lines.length - 1 || beforeText.endsWith('\n')) {
            parts.push(line + (idx < lines.length - 1 ? '\n' : ''))
          } else if (line) {
            parts.push(line)
          }
        })
      }
      
      switch (m.type) {
        case 'bold':
          parts.push(<strong key={key++}>{m.text}</strong>)
          break
        case 'italic':
          parts.push(<em key={key++}>{m.text}</em>)
          break
        case 'strikethrough':
          parts.push(<del key={key++}>{m.text}</del>)
          break
        case 'code':
          parts.push(<code key={key++} className="bg-gray-200 px-1 rounded text-sm font-mono">{m.text}</code>)
          break
        case 'link':
          parts.push(<a key={key++} href={m.url} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">{m.text}</a>)
          break
        case 'quote':
          parts.push(
            <blockquote key={key++} className="border-l-4 border-gray-300 pl-4 italic text-gray-700 my-2">
              {m.text}
            </blockquote>
          )
          break
        default:
          parts.push(m.text)
      }
      lastIndex = m.end
    })
    
    if (lastIndex < text.length) {
      parts.push(text.substring(lastIndex))
    }
    
    return parts.length > 0 ? parts : text
  }

  const formatDesignOutput = (output: Record<string, unknown>) => {
    const formattedEmail = getStringValue(output, 'formatted_email')
    const emailFallback = getStringValue(output, 'email')
    const email = formattedEmail || emailFallback
    
    if (editingDesignOutput) {
      return (
        <div className="space-y-4">
          {/* Formatting Toolbar */}
          <div className="flex flex-wrap items-center gap-2 p-3 bg-gray-100 rounded-lg border border-gray-300">
            <div className="flex items-center space-x-1 border-r border-gray-300 pr-2">
              <button
                type="button"
                onClick={() => textareaRef.current && applyFormatting('bold', textareaRef.current)}
                className="px-3 py-1.5 text-sm font-bold bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                title="Bold: **text**"
              >
                <strong>B</strong>
              </button>
              <button
                type="button"
                onClick={() => textareaRef.current && applyFormatting('italic', textareaRef.current)}
                className="px-3 py-1.5 text-sm italic bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                title="Italic: *text*"
              >
                <em>I</em>
              </button>
              <button
                type="button"
                onClick={() => textareaRef.current && applyFormatting('strikethrough', textareaRef.current)}
                className="px-3 py-1.5 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors line-through"
                title="Strikethrough: ~~text~~"
              >
                S
              </button>
            </div>
            <div className="flex items-center space-x-1 border-r border-gray-300 pr-2">
              <button
                type="button"
                onClick={() => textareaRef.current && applyFormatting('code', textareaRef.current)}
                className="px-3 py-1.5 text-sm font-mono bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                title="Code: `text`"
              >
                &lt;/&gt;
              </button>
              <button
                type="button"
                onClick={() => textareaRef.current && applyFormatting('link', textareaRef.current)}
                className="px-3 py-1.5 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                title="Link: [text](url)"
              >
                🔗
              </button>
              <button
                type="button"
                onClick={() => textareaRef.current && applyFormatting('quote', textareaRef.current)}
                className="px-3 py-1.5 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                title="Quote: > text"
              >
                &quot;
              </button>
            </div>
            <div className="text-xs text-gray-500">
              <strong>B</strong>old <em>I</em>talic <span className="line-through">S</span>trike <code>`code`</code> 🔗link &gt;quote
            </div>
          </div>
          
          <textarea
            ref={textareaRef}
            value={editedDesignEmail}
            onChange={(e) => setEditedDesignEmail(e.target.value)}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg text-sm text-gray-900 font-mono resize-y min-h-[200px] outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white"
            placeholder="Edit formatted email content... Use markdown: **bold** *italic* ~~strike~~ `code` [link](url) >quote"
          />
          <div className="flex justify-end space-x-3">
            <button
              onClick={() => {
                setEditingDesignOutput(false)
                setEditedDesignEmail('')
              }}
              className="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 transition-colors duration-200 text-sm font-medium"
              disabled={saving}
            >
              Cancel
            </button>
            <button
              onClick={handleSaveDesignOutput}
              disabled={saving || !editedDesignEmail.trim()}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </div>
      )
    }
    
    return (
      <div className="space-y-4">
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 relative group">
          <div className="whitespace-pre-wrap text-sm text-gray-900">
            {renderMarkdown(email)}
          </div>
          {leadId && onUpdateOutput && (
            <button
              onClick={() => {
                setEditedDesignEmail(email)
                setEditingDesignOutput(true)
              }}
              className="absolute top-2 right-2 p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors duration-200 opacity-0 group-hover:opacity-100"
              title="Edit formatted email"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-5 h-5">
                <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125" />
              </svg>
            </button>
          )}
        </div>
      </div>
    )
  }

  const formatCritiqueOutput = (output: Record<string, unknown>) => {
    const critique = getStringValue(output, 'critique') || null
    
    if (!critique) {
      return (
        <div className="flex items-center space-x-2 text-green-600">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="font-medium">Email approved - no feedback provided</span>
        </div>
      )
    }
    
    return (
      <div className="space-y-4">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div className="flex items-start space-x-2">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6 text-yellow-600 flex-shrink-0 mt-0.5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
            </svg>
            <div>
              <h4 className="font-semibold text-yellow-900 mb-2">Feedback Required</h4>
              <p className="text-sm text-yellow-800 whitespace-pre-wrap">{critique}</p>
            </div>
          </div>
        </div>
      </div>
    )
  }

  const renderOutput = (output: AgentOutputType) => {
    const agentType = output.agentName
    const dataRecord = toRecord(output.outputData)
    
    if (output.status === 'failed') {
      return (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-start space-x-2">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6 text-red-600 flex-shrink-0 mt-0.5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div>
              <h4 className="font-semibold text-red-900 mb-1">Agent Failed</h4>
              <p className="text-sm text-red-800">{output.errorMessage || 'Unknown error occurred'}</p>
            </div>
          </div>
        </div>
      )
    }
    
    switch (agentType) {
      case 'SEARCH':
        return formatSearchOutput(isSearchOutputData(output.outputData) ? output.outputData : null)
      case 'WRITER':
        return formatWriterOutput(dataRecord)
      case 'DESIGN':
        return formatDesignOutput(dataRecord)
      case 'CRITIQUE':
        return formatCritiqueOutput(dataRecord)
      default:
        return <pre className="text-sm">{JSON.stringify(output.outputData, null, 2)}</pre>
    }
  }

  const tabs = [
    { id: 'ALL' as const, label: 'All Outputs', count: outputs.length },
    { id: 'SEARCH' as const, label: 'Search', count: outputs.filter(o => o.agentName === 'SEARCH').length },
    { id: 'WRITER' as const, label: 'Writer', count: outputs.filter(o => o.agentName === 'WRITER').length },
    { id: 'CRITIQUE' as const, label: 'Critique', count: outputs.filter(o => o.agentName === 'CRITIQUE').length },
    { id: 'DESIGN' as const, label: 'Design', count: outputs.filter(o => o.agentName === 'DESIGN').length },
  ]

  // Sort outputs: Group by agent, show newest first within each group
  // For ALL tab: Sort groups by agent execution order, then newest first within each
  // For specific agent tabs: Show newest first
  const agentOrder = ['SEARCH', 'WRITER', 'CRITIQUE', 'DESIGN']
  const sortOutputs = (outputs: AgentOutputType[]) => {
    if (activeTab === 'ALL') {
      // Group by agent name, then sort by agent order and within group by date (newest first)
      const grouped = outputs.reduce((acc, output) => {
        if (!acc[output.agentName]) {
          acc[output.agentName] = []
        }
        acc[output.agentName].push(output)
        return acc
      }, {} as Record<string, AgentOutputType[]>)

      // Sort each group by created_at DESC (newest first)
      Object.keys(grouped).forEach(agentName => {
        grouped[agentName].sort((a, b) => {
          const aDate = a.createdAt ? new Date(a.createdAt).getTime() : 0
          const bDate = b.createdAt ? new Date(b.createdAt).getTime() : 0
          return bDate - aDate // DESC order (newest first)
        })
      })

      // Flatten back to array in agent order, with newest first within each agent
      const sorted: AgentOutputType[] = []
      agentOrder.forEach(agentName => {
        if (grouped[agentName]) {
          sorted.push(...grouped[agentName])
        }
      })
      // Add any agents not in the order list at the end
      Object.keys(grouped).forEach(agentName => {
        if (!agentOrder.includes(agentName)) {
          sorted.push(...grouped[agentName])
        }
      })

      return sorted
    } else {
      // For specific agent tabs, just sort by created_at DESC (newest first)
      return [...outputs].sort((a, b) => {
        const aDate = a.createdAt ? new Date(a.createdAt).getTime() : 0
        const bDate = b.createdAt ? new Date(b.createdAt).getTime() : 0
        return bDate - aDate // DESC order (newest first)
      })
    }
  }

  const tabOutputs = sortOutputs(getTabOutputs())
  const fallbackTabLabel =
    activeTab === 'ALL'
      ? 'All Outputs'
      : `${activeTab.slice(0, 1)}${activeTab.slice(1).toLowerCase()}`
  const activeTabLabel = tabs.find(tab => tab.id === activeTab)?.label ?? fallbackTabLabel
  const emptyStateMessage =
    activeTab === 'ALL'
      ? 'No agent outputs available for this lead'
      : `No ${activeTabLabel} agent output for this lead`

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[10001]">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl mx-4 max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex justify-between items-center p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Agent Outputs - {leadName}</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-red-500 transition-colors duration-200"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Tabs */}
        <div className="flex space-x-1 px-6 border-b border-gray-200">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-3 text-sm font-medium transition-colors duration-200 border-b-2 ${
                activeTab === tab.id
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab.label} {tab.count > 0 && `(${tab.count})`}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="text-gray-600">Loading outputs...</div>
            </div>
          ) : tabOutputs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-gray-500">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-12 h-12 mb-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h11.25c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z" />
              </svg>
              <p>{emptyStateMessage}</p>
            </div>
          ) : (
            <div className="space-y-6">
              {tabOutputs.map((output, idx) => (
                <div key={idx} className="border border-gray-200 rounded-lg p-4">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center space-x-2">
                      <h3 className="text-lg font-semibold text-gray-900">{output.agentName}</h3>
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        output.status === 'completed' ? 'bg-green-100 text-green-800' :
                        output.status === 'failed' ? 'bg-red-100 text-red-800' :
                        'bg-yellow-100 text-yellow-800'
                      }`}>
                        {output.status}
                      </span>
                    </div>
                    <span className="text-xs text-gray-500">
                      {formatTimestamp(output.createdAt)}
                    </span>
                  </div>
                  {renderOutput(output)}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

