'use client'

import React from 'react'
import { AgentOutput as AgentOutputType } from '@/types'

interface AgentOutputModalProps {
  isOpen: boolean
  onClose: () => void
  leadName: string
  leadId?: number
  outputs: AgentOutputType[]
  loading: boolean
  onUpdateOutput?: (leadId: number, agentName: string, newContent: string) => Promise<void>
  onUpdateSearchOutput?: (leadId: number, agentName: string, updatedData: any) => Promise<void>
}

export default function AgentOutputModal({ isOpen, onClose, leadName, leadId, outputs, loading, onUpdateOutput, onUpdateSearchOutput }: AgentOutputModalProps) {
  const [activeTab, setActiveTab] = React.useState<'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE' | 'ALL'>('ALL')
  const [editingWriterOutput, setEditingWriterOutput] = React.useState(false)
  const [editingDesignOutput, setEditingDesignOutput] = React.useState(false)
  const [editedEmail, setEditedEmail] = React.useState('')
  const [editedDesignEmail, setEditedDesignEmail] = React.useState('')
  const [saving, setSaving] = React.useState(false)
  const [searchOutputData, setSearchOutputData] = React.useState<any>(null)
  const textareaRef = React.useRef<HTMLTextAreaElement>(null)

  React.useEffect(() => {
    if (isOpen) {
      setEditingWriterOutput(false)
      setEditingDesignOutput(false)
      setEditedEmail('')
      setEditedDesignEmail('')
      // Initialize search output data
      const searchOutput = outputs.find(o => o.agentName === 'SEARCH')
      if (searchOutput && searchOutput.outputData) {
        setSearchOutputData(searchOutput.outputData)
      }
    }
  }, [isOpen, outputs])

  if (!isOpen) return null

  const getTabOutputs = () => {
    if (activeTab === 'ALL') return outputs
    return outputs.filter(o => o.agentName === activeTab)
  }

  const handleRemoveSource = async (index: number) => {
    if (!leadId || !searchOutputData || !onUpdateSearchOutput) return
    
    // Create updated sources array without the removed item
    const updatedSources = [...(searchOutputData.sources || [])]
    updatedSources.splice(index, 1)
    
    // Create updated search output data
    const updatedData = {
      ...searchOutputData,
      sources: updatedSources
    }
    
    // Update local state immediately for better UX
    setSearchOutputData(updatedData)
    
    try {
      // Save to backend
      await onUpdateSearchOutput(leadId, 'SEARCH', updatedData)
    } catch (error) {
      console.error('Failed to remove source:', error)
      // Revert on error
      setSearchOutputData(searchOutputData)
      alert('Failed to remove source. Please try again.')
    }
  }

  const formatSearchOutput = (output: any) => {
    // Use local state if available, otherwise use output prop
    const data = searchOutputData || output
    if (!data || typeof data !== 'object') return null
    
    const sources = data.sources || []
    const domain = data.domain || 'N/A'
    
    return (
      <div className="space-y-4">
        <div>
          <h4 className="font-semibold text-gray-900 mb-2">Domain: {domain}</h4>
          <p className="text-sm text-gray-600">Found {sources.length} sources {sources.length > 0 && '(click X to remove)'}</p>
        </div>
        {sources.length > 0 && (
          <div className="space-y-3">
            {sources.map((source: any, idx: number) => (
              <div key={idx} className="border border-gray-200 rounded-lg p-3 bg-gray-50 relative group">
                {leadId && onUpdateSearchOutput && (
                  <button
                    onClick={() => handleRemoveSource(idx)}
                    className="absolute top-2 right-2 p-1 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors duration-200 opacity-0 group-hover:opacity-100"
                    title="Remove this source"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-5 h-5">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                )}
                <h5 className="font-medium text-gray-900 mb-1 pr-8">{source.title || 'Untitled'}</h5>
                <a href={source.url} target="_blank" rel="noopener noreferrer" className="text-sm text-blue-600 hover:underline truncate block">
                  {source.url}
                </a>
                {source.content && (
                  <p className="text-sm text-gray-600 mt-2 line-clamp-3">{source.content}</p>
                )}
              </div>
            ))}
          </div>
        )}
        {sources.length === 0 && (
          <div className="text-center py-4 text-gray-500">
            <p>All sources have been removed</p>
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

  const formatWriterOutput = (output: any) => {
    if (!output || typeof output !== 'object') return null
    
    const email = output.email || ''
    
    if (editingWriterOutput) {
      return (
        <div className="space-y-4">
          <textarea
            value={editedEmail}
            onChange={(e) => setEditedEmail(e.target.value)}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-sm text-gray-900 font-mono resize-y min-h-[200px]"
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
    const parts: (string | JSX.Element)[] = []
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

  const formatDesignOutput = (output: any) => {
    if (!output || typeof output !== 'object') return null
    
    const email = output.formatted_email || output.email || ''
    
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
                "
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
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-sm text-gray-900 font-mono resize-y min-h-[200px]"
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

  const formatCritiqueOutput = (output: any) => {
    if (!output || typeof output !== 'object') return null
    
    const critique = output.critique
    
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
    const data = output.outputData || {}
    
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
        return formatSearchOutput(data)
      case 'WRITER':
        return formatWriterOutput(data)
      case 'DESIGN':
        return formatDesignOutput(data)
      case 'CRITIQUE':
        return formatCritiqueOutput(data)
      default:
        return <pre className="text-sm">{JSON.stringify(data, null, 2)}</pre>
    }
  }

  const tabs = [
    { id: 'ALL' as const, label: 'All Outputs', count: outputs.length },
    { id: 'SEARCH' as const, label: 'Search', count: outputs.filter(o => o.agentName === 'SEARCH').length },
    { id: 'WRITER' as const, label: 'Writer', count: outputs.filter(o => o.agentName === 'WRITER').length },
    { id: 'DESIGN' as const, label: 'Design', count: outputs.filter(o => o.agentName === 'DESIGN').length },
    { id: 'CRITIQUE' as const, label: 'Critique', count: outputs.filter(o => o.agentName === 'CRITIQUE').length },
  ]

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
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
          ) : outputs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-gray-500">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-12 h-12 mb-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h11.25c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z" />
              </svg>
              <p>No agent outputs available for this lead</p>
            </div>
          ) : (
            <div className="space-y-6">
              {getTabOutputs().map((output, idx) => (
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
                      {new Date(output.createdAt).toLocaleString()}
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

