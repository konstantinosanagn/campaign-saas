'use client'

import React from 'react'
import { AgentConfig, SearchAgentSettings, WriterAgentSettings, CritiqueAgentSettings, DesignAgentSettings, SharedSettings } from '@/types'

interface AgentSettingsModalProps {
  isOpen: boolean
  onClose: () => void
  agentName: 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE'
  config: AgentConfig | null
  sharedSettings?: SharedSettings
  onSave: (config: AgentConfig) => Promise<void>
  loading: boolean
}

export default function AgentSettingsModal({ 
  isOpen, 
  onClose, 
  agentName, 
  config, 
  sharedSettings,
  onSave, 
  loading 
}: AgentSettingsModalProps) {
  // Common state
  const [enabled, setEnabled] = React.useState(true)
  const [saving, setSaving] = React.useState(false)

  // SEARCH agent state
  const [searchDepth, setSearchDepth] = React.useState<'basic' | 'advanced'>('basic')
  const [maxQueriesPerLead, setMaxQueriesPerLead] = React.useState(2)
  const [extractedFields, setExtractedFields] = React.useState<string[]>([])
  const [onLowInfoBehavior, setOnLowInfoBehavior] = React.useState<'generic_industry' | 'light_personalization' | 'skip'>('generic_industry')
  const [hoveredTooltip, setHoveredTooltip] = React.useState<'basic' | 'advanced' | null>(null)
  const [tooltipPosition, setTooltipPosition] = React.useState<{ top: number; left: number } | null>(null)
  const [hoveredStrictnessTooltip, setHoveredStrictnessTooltip] = React.useState<'lenient' | 'moderate' | 'strict' | null>(null)
  const [strictnessTooltipPosition, setStrictnessTooltipPosition] = React.useState<{ top: number; left: number } | null>(null)
  const [hoveredLowInfoTooltip, setHoveredLowInfoTooltip] = React.useState(false)
  const [lowInfoTooltipPosition, setLowInfoTooltipPosition] = React.useState<{ top: number; left: number } | null>(null)
  const [extractedFieldsOpen, setExtractedFieldsOpen] = React.useState(false)
  const [lowInfoBehaviorOpen, setLowInfoBehaviorOpen] = React.useState(false)
  
  const basicButtonRef = React.useRef<HTMLButtonElement>(null)
  const advancedButtonRef = React.useRef<HTMLButtonElement>(null)
  const lenientButtonRef = React.useRef<HTMLButtonElement>(null)
  const moderateButtonRef = React.useRef<HTMLButtonElement>(null)
  const strictButtonRef = React.useRef<HTMLButtonElement>(null)
  const lowInfoLabelRef = React.useRef<HTMLLabelElement>(null)
  const extractedFieldsRef = React.useRef<HTMLDivElement>(null)
  const lowInfoBehaviorRef = React.useRef<HTMLDivElement>(null)

  // WRITER agent state
  const [emailLength, setEmailLength] = React.useState<'very_short' | 'short' | 'standard'>('short')
  const [personalizationLevel, setPersonalizationLevel] = React.useState<'low' | 'medium' | 'high'>('medium')
  const [ctaSoftness, setCtaSoftness] = React.useState<'soft' | 'balanced' | 'direct'>('balanced')
  const [numVariantsPerLead, setNumVariantsPerLead] = React.useState(2)
  const [emailLengthOpen, setEmailLengthOpen] = React.useState(false)
  const [ctaSoftnessOpen, setCtaSoftnessOpen] = React.useState(false)
  const [personalizationLevelOpen, setPersonalizationLevelOpen] = React.useState(false)
  
  const emailLengthRef = React.useRef<HTMLDivElement>(null)
  const ctaSoftnessRef = React.useRef<HTMLDivElement>(null)
  const personalizationLevelRef = React.useRef<HTMLDivElement>(null)

  // CRITIQUE agent state
  const [checkPersonalization, setCheckPersonalization] = React.useState(true)
  const [checkBrandVoice, setCheckBrandVoice] = React.useState(true)
  const [checkSpamminess, setCheckSpamminess] = React.useState(true)
  const [strictness, setStrictness] = React.useState<'lenient' | 'moderate' | 'strict'>('moderate')
  const [rewritePolicy, setRewritePolicy] = React.useState<'none' | 'rewrite_if_bad'>('rewrite_if_bad')
  const [minScoreForSend, setMinScoreForSend] = React.useState(6)
  const [variantSelection, setVariantSelection] = React.useState<'highest_overall_score' | 'highest_personalization_score'>('highest_overall_score')
  const [qualityChecksOpen, setQualityChecksOpen] = React.useState(false)
  const [rewritePolicyOpen, setRewritePolicyOpen] = React.useState(false)
  const [variantSelectionOpen, setVariantSelectionOpen] = React.useState(false)
  
  const qualityChecksRef = React.useRef<HTMLDivElement>(null)
  const rewritePolicyRef = React.useRef<HTMLDivElement>(null)
  const variantSelectionRef = React.useRef<HTMLDivElement>(null)

  // DESIGN agent state
  const [format, setFormat] = React.useState<'plain_text' | 'formatted'>('formatted')
  const [allowBold, setAllowBold] = React.useState(true)
  const [allowItalic, setAllowItalic] = React.useState(true)
  const [allowBullets, setAllowBullets] = React.useState(true)
  const [ctaStyle, setCtaStyle] = React.useState<'link' | 'button'>('link')
  const [fontFamily, setFontFamily] = React.useState<'system_sans' | 'serif'>('system_sans')
  const [formatOpen, setFormatOpen] = React.useState(false)
  const [ctaStyleOpen, setCtaStyleOpen] = React.useState(false)
  const [fontFamilyOpen, setFontFamilyOpen] = React.useState(false)
  
  const formatRef = React.useRef<HTMLDivElement>(null)
  const ctaStyleRef = React.useRef<HTMLDivElement>(null)
  const fontFamilyRef = React.useRef<HTMLDivElement>(null)

  // Available extracted fields for SEARCH agent
  const availableExtractedFields = [
    'company_industry',
    'company_size_range',
    'recent_announcement_or_news',
    'flagship_product_or_service'
  ]

  // Initialize state from config and sharedSettings
  React.useEffect(() => {
    if (config) {
      setEnabled(config.enabled)
      const settings = config.settings || {}

      if (agentName === 'SEARCH') {
        const searchSettings = settings as SearchAgentSettings
        setSearchDepth(searchSettings.search_depth || 'basic')
        setMaxQueriesPerLead(searchSettings.max_queries_per_lead || 2)
        setExtractedFields(searchSettings.extracted_fields || [])
        setOnLowInfoBehavior(searchSettings.on_low_info_behavior || 'generic_industry')
      } else if (agentName === 'WRITER') {
        const writerSettings = settings as WriterAgentSettings
        setEmailLength(writerSettings.email_length || 'short')
        setPersonalizationLevel(writerSettings.personalization_level || 'medium')
        setCtaSoftness(writerSettings.cta_softness || 'balanced')
        setNumVariantsPerLead(writerSettings.num_variants_per_lead || 2)
      } else if (agentName === 'CRITIQUE') {
        const critiqueSettings = settings as CritiqueAgentSettings
        setCheckPersonalization(critiqueSettings.checks?.check_personalization !== false)
        setCheckBrandVoice(critiqueSettings.checks?.check_brand_voice !== false)
        setCheckSpamminess(critiqueSettings.checks?.check_spamminess !== false)
        setStrictness(critiqueSettings.strictness || 'moderate')
        setRewritePolicy(critiqueSettings.rewrite_policy || 'rewrite_if_bad')
        setMinScoreForSend(Math.max(1, Math.min(10, critiqueSettings.min_score_for_send || 6)))
        setVariantSelection(critiqueSettings.variant_selection || 'highest_overall_score')
      } else if (agentName === 'DESIGN') {
        const designSettings = settings as DesignAgentSettings & { allow_bold?: boolean; allow_italic?: boolean; allow_bullets?: boolean; cta_style?: string; font_family?: string }
        setFormat(designSettings.format || 'formatted')
        // Handle both camelCase (new) and snake_case (backward compatibility)
        setAllowBold((designSettings.allowBold ?? designSettings.allow_bold) !== false)
        setAllowItalic((designSettings.allowItalic ?? designSettings.allow_italic) !== false)
        setAllowBullets((designSettings.allowBullets ?? designSettings.allow_bullets) !== false)
        setCtaStyle((designSettings.ctaStyle || designSettings.cta_style) || 'link')
        setFontFamily((designSettings.fontFamily || designSettings.font_family) || 'system_sans')
      }
    } else {
      // Reset to defaults
      setEnabled(true)
      if (agentName === 'SEARCH') {
        setSearchDepth('basic')
        setMaxQueriesPerLead(2)
        setExtractedFields([])
        setOnLowInfoBehavior('generic_industry')
      } else if (agentName === 'WRITER') {
        setEmailLength('short')
        setPersonalizationLevel('medium')
        setCtaSoftness('balanced')
        setNumVariantsPerLead(2)
      } else if (agentName === 'CRITIQUE') {
        setCheckPersonalization(true)
        setCheckBrandVoice(true)
        setCheckSpamminess(true)
        setStrictness('moderate')
        setRewritePolicy('rewrite_if_bad')
        setMinScoreForSend(6)
        setVariantSelection('highest_overall_score')
      } else if (agentName === 'DESIGN') {
        setFormat('formatted')
        setAllowBold(true)
        setAllowItalic(true)
        setAllowBullets(true)
        setCtaStyle('link')
        setFontFamily('system_sans')
      }
    }
  }, [config, agentName, isOpen, sharedSettings])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    setSaving(true)
    try {
      let settings: Record<string, unknown> = {}

      if (agentName === 'SEARCH') {
        settings = {
          search_depth: searchDepth,
          max_queries_per_lead: maxQueriesPerLead,
          extracted_fields: extractedFields,
          on_low_info_behavior: onLowInfoBehavior
        }
      } else if (agentName === 'WRITER') {
        settings = {
          email_length: emailLength,
          personalization_level: personalizationLevel,
          cta_softness: ctaSoftness,
          num_variants_per_lead: numVariantsPerLead
        }
      } else if (agentName === 'CRITIQUE') {
        settings = {
          checks: {
            check_personalization: checkPersonalization,
            check_brand_voice: checkBrandVoice,
            check_spamminess: checkSpamminess
          },
          strictness: strictness,
          rewrite_policy: rewritePolicy,
          min_score_for_send: minScoreForSend,
          variant_selection: variantSelection
        }
      } else if (agentName === 'DESIGN') {
        settings = {
          format: format,
          allowBold: allowBold,
          allowItalic: allowItalic,
          allowBullets: allowBullets,
          ctaStyle: ctaStyle,
          fontFamily: fontFamily
        }
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
    // Reset to config values on close
    if (config) {
      setEnabled(config.enabled)
      const settings = config.settings || {}
      if (agentName === 'SEARCH') {
        const searchSettings = settings as SearchAgentSettings
        setSearchDepth(searchSettings.search_depth || 'basic')
        setMaxQueriesPerLead(searchSettings.max_queries_per_lead || 2)
        setExtractedFields(searchSettings.extracted_fields || [])
        setOnLowInfoBehavior(searchSettings.on_low_info_behavior || 'generic_industry')
      } else if (agentName === 'WRITER') {
        const writerSettings = settings as WriterAgentSettings
        setEmailLength(writerSettings.email_length || 'short')
        setPersonalizationLevel(writerSettings.personalization_level || 'medium')
        setCtaSoftness(writerSettings.cta_softness || 'balanced')
        setNumVariantsPerLead(writerSettings.num_variants_per_lead || 2)
      } else if (agentName === 'CRITIQUE') {
        const critiqueSettings = settings as CritiqueAgentSettings
        setCheckPersonalization(critiqueSettings.checks?.check_personalization !== false)
        setCheckBrandVoice(critiqueSettings.checks?.check_brand_voice !== false)
        setCheckSpamminess(critiqueSettings.checks?.check_spamminess !== false)
        setStrictness(critiqueSettings.strictness || 'moderate')
        setRewritePolicy(critiqueSettings.rewrite_policy || 'rewrite_if_bad')
        setMinScoreForSend(Math.max(1, Math.min(10, critiqueSettings.min_score_for_send || 6)))
        setVariantSelection(critiqueSettings.variant_selection || 'highest_overall_score')
      } else if (agentName === 'DESIGN') {
        const designSettings = settings as DesignAgentSettings & { allow_bold?: boolean; allow_italic?: boolean; allow_bullets?: boolean; cta_style?: string; font_family?: string }
        setFormat(designSettings.format || 'formatted')
        // Handle both camelCase (new) and snake_case (backward compatibility)
        setAllowBold((designSettings.allowBold ?? designSettings.allow_bold) !== false)
        setAllowItalic((designSettings.allowItalic ?? designSettings.allow_italic) !== false)
        setAllowBullets((designSettings.allowBullets ?? designSettings.allow_bullets) !== false)
        setCtaStyle((designSettings.ctaStyle || designSettings.cta_style) || 'link')
        setFontFamily((designSettings.fontFamily || designSettings.font_family) || 'system_sans')
      }
    }
    onClose()
  }

  const toggleExtractedField = (field: string) => {
    setExtractedFields(prev => 
      prev.includes(field) 
        ? prev.filter(f => f !== field)
        : [...prev, field]
    )
  }

  const toggleQualityCheck = (check: 'check_personalization' | 'check_brand_voice' | 'check_spamminess') => {
    if (check === 'check_personalization') {
      setCheckPersonalization(!checkPersonalization)
    } else if (check === 'check_brand_voice') {
      setCheckBrandVoice(!checkBrandVoice)
    } else if (check === 'check_spamminess') {
      setCheckSpamminess(!checkSpamminess)
    }
  }

  const getSelectedQualityChecks = (): string[] => {
    const selected: string[] = []
    if (checkPersonalization) selected.push('Check Personalization')
    if (checkBrandVoice) selected.push('Check Brand Voice')
    if (checkSpamminess) selected.push('Check Spamminess')
    return selected
  }

  // Close dropdowns when clicking outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      // Check if click is on scrollbar area (right edge of scrollable container)
      const scrollableDiv = document.querySelector('.scrollbar-visible') as HTMLElement
      if (scrollableDiv) {
        const rect = scrollableDiv.getBoundingClientRect()
        const clickX = event.clientX
        // If click is within 20px of the right edge, assume it's the scrollbar
        if (clickX >= rect.right - 20 && clickX <= rect.right) {
          return // Don't close dropdowns when clicking scrollbar area
        }
      }
      
      if (extractedFieldsRef.current && !extractedFieldsRef.current.contains(event.target as Node)) {
        setExtractedFieldsOpen(false)
      }
      if (lowInfoBehaviorRef.current && !lowInfoBehaviorRef.current.contains(event.target as Node)) {
        setLowInfoBehaviorOpen(false)
      }
      if (emailLengthRef.current && !emailLengthRef.current.contains(event.target as Node)) {
        setEmailLengthOpen(false)
      }
      if (ctaSoftnessRef.current && !ctaSoftnessRef.current.contains(event.target as Node)) {
        setCtaSoftnessOpen(false)
      }
      if (personalizationLevelRef.current && !personalizationLevelRef.current.contains(event.target as Node)) {
        setPersonalizationLevelOpen(false)
      }
      if (qualityChecksRef.current && !qualityChecksRef.current.contains(event.target as Node)) {
        setQualityChecksOpen(false)
      }
      if (rewritePolicyRef.current && !rewritePolicyRef.current.contains(event.target as Node)) {
        setRewritePolicyOpen(false)
      }
      if (variantSelectionRef.current && !variantSelectionRef.current.contains(event.target as Node)) {
        setVariantSelectionOpen(false)
      }
      if (formatRef.current && !formatRef.current.contains(event.target as Node)) {
        setFormatOpen(false)
      }
      if (ctaStyleRef.current && !ctaStyleRef.current.contains(event.target as Node)) {
        setCtaStyleOpen(false)
      }
      if (fontFamilyRef.current && !fontFamilyRef.current.contains(event.target as Node)) {
        setFontFamilyOpen(false)
      }
    }

    // Use a slight delay to allow scrollbar interaction
    const timeoutId = setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside)
    }, 100)

    return () => {
      clearTimeout(timeoutId)
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  // Ticker icon component
  const TickerIcon = ({ className = "w-4 h-4" }: { className?: string }) => (
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 24 24" className={className}>
      <path fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M5 14.5s1.5 0 3.5 3.5c0 0 5.559-9.167 10.5-11" color="currentColor"/>
    </svg>
  )

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
    <>
      <style>{`
        .scrollbar-visible {
          scrollbar-width: thin;
          scrollbar-color: #cbd5e1 #f1f5f9;
        }
        .scrollbar-visible::-webkit-scrollbar {
          width: 12px;
          -webkit-appearance: none;
          z-index: 1;
        }
        .scrollbar-visible::-webkit-scrollbar-track {
          background: #f1f5f9;
          border-radius: 6px;
          pointer-events: auto;
        }
        .scrollbar-visible::-webkit-scrollbar-thumb {
          background: #cbd5e1;
          border-radius: 6px;
          border: 2px solid #f1f5f9;
          min-height: 20px;
          pointer-events: auto;
          cursor: grab;
        }
        .scrollbar-visible::-webkit-scrollbar-thumb:active {
          background: #64748b;
          cursor: grabbing;
        }
        .scrollbar-visible::-webkit-scrollbar-thumb:hover {
          background: #94a3b8;
        }
      `}</style>
      {/* Custom Tooltip - positioned fixed to avoid clipping */}
      {hoveredTooltip && tooltipPosition && (
        <div
          className="fixed z-[60] px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg shadow-lg transition-all duration-300 ease-in-out opacity-100 translate-y-0"
          style={{
            whiteSpace: 'nowrap',
            top: `${tooltipPosition.top}px`,
            left: `${tooltipPosition.left}px`,
            transform: 'translateX(-50%)'
          }}
          onMouseEnter={() => setHoveredTooltip(hoveredTooltip)}
          onMouseLeave={() => {
            setHoveredTooltip(null)
            setTooltipPosition(null)
          }}
        >
          <p className="text-xs text-gray-700">
            {hoveredTooltip === 'basic'
              ? 'Basic: Quick search with standard queries'
              : 'Advanced: Deeper research with more comprehensive results'}
          </p>
          {/* Tooltip arrow */}
          <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-b-4 border-transparent border-b-blue-200"></div>
          <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 -mb-[1px] w-0 h-0 border-l-4 border-r-4 border-b-4 border-transparent border-b-blue-50"></div>
        </div>
      )}
      {/* Strictness Tooltip - positioned fixed to avoid clipping */}
      {hoveredStrictnessTooltip && strictnessTooltipPosition && (
        <div
          className="fixed z-[60] px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg shadow-lg transition-all duration-300 ease-in-out opacity-100 translate-y-0"
          style={{
            whiteSpace: 'nowrap',
            top: `${strictnessTooltipPosition.top}px`,
            left: `${strictnessTooltipPosition.left}px`,
            transform: 'translateX(-50%)'
          }}
          onMouseEnter={() => setHoveredStrictnessTooltip(hoveredStrictnessTooltip)}
          onMouseLeave={() => {
            setHoveredStrictnessTooltip(null)
            setStrictnessTooltipPosition(null)
          }}
        >
          <p className="text-xs text-gray-700">
            {hoveredStrictnessTooltip === 'lenient'
              ? 'Lenient: Only flag extreme issues'
              : hoveredStrictnessTooltip === 'moderate'
              ? 'Moderate: Enforce basic quality & tone'
              : 'Strict: Require strong personalization & adherence'}
          </p>
          {/* Tooltip arrow */}
          <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-b-4 border-transparent border-b-blue-200"></div>
          <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 -mb-[1px] w-0 h-0 border-l-4 border-r-4 border-b-4 border-transparent border-b-blue-50"></div>
        </div>
      )}

      {/* On Low Info Behavior Tooltip */}
      {hoveredLowInfoTooltip && lowInfoTooltipPosition && (
        <div
          className="fixed z-[60] px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg shadow-lg transition-all duration-300 ease-in-out opacity-100 translate-y-0"
          style={{
            whiteSpace: 'normal',
            maxWidth: '300px',
            top: `${lowInfoTooltipPosition.top}px`,
            left: `${lowInfoTooltipPosition.left}px`,
            transform: 'translateX(-50%)'
          }}
          onMouseEnter={() => setHoveredLowInfoTooltip(true)}
          onMouseLeave={() => {
            setHoveredLowInfoTooltip(false)
            setLowInfoTooltipPosition(null)
          }}
        >
          <p className="text-xs text-gray-700">
            What to do when insufficient information is found about the lead
          </p>
          {/* Tooltip arrow */}
          <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-b-4 border-transparent border-b-blue-200"></div>
          <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 -mb-[1px] w-0 h-0 border-l-4 border-r-4 border-b-4 border-transparent border-b-blue-50"></div>
        </div>
      )}
      
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl mx-4 my-8 max-h-[90vh] flex flex-col">
          {/* Fixed Header */}
          <div className="flex justify-between items-center p-6 pb-4 border-b border-gray-200 flex-shrink-0">
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

          {/* Scrollable Content */}
          <form onSubmit={handleSubmit} className="flex-1 flex flex-col min-h-0 overflow-hidden">
            <div 
              className="flex-1 overflow-y-scroll p-6 space-y-4 scrollbar-visible" 
              style={{ 
                maxHeight: 'calc(90vh - 200px)',
                WebkitOverflowScrolling: 'touch'
              }}
            >
              {/* Enable/Disable Toggle */}
              <div className="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
                <div>
                  <label htmlFor="enabled" className="text-sm font-medium text-gray-900">
                    Enable {agentName} Agent
                  </label>
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

              {/* SEARCH Agent Settings */}
              {agentName === 'SEARCH' && (
                <div className="space-y-4">
              <div>
                <div className="flex items-center gap-3 mb-1 flex-nowrap">
                  <label className="text-sm font-medium text-gray-700 whitespace-nowrap">
                    Search Depth
                  </label>
                  <div className="inline-flex rounded-full shadow-sm border border-gray-300 relative flex-shrink-0" role="group">
                    <button
                      ref={basicButtonRef}
                      type="button"
                      onClick={() => setSearchDepth('basic')}
                      onMouseEnter={(e) => {
                        const rect = e.currentTarget.getBoundingClientRect()
                        setTooltipPosition({
                          top: rect.bottom + 8,
                          left: rect.left + rect.width / 2
                        })
                        setHoveredTooltip('basic')
                      }}
                      onMouseLeave={() => {
                        setHoveredTooltip(null)
                        setTooltipPosition(null)
                      }}
                      className={`px-4 py-2 text-sm font-medium transition-all duration-200 ${
                        searchDepth === 'basic'
                          ? 'bg-white text-blue-600 outline outline-2 outline-blue-600 outline-offset-[-2px] rounded-full'
                          : 'bg-white text-gray-700 hover:bg-gray-50 rounded-l-full'
                      }`}
                    >
                      Basic
                    </button>
                    <button
                      ref={advancedButtonRef}
                      type="button"
                      onClick={() => setSearchDepth('advanced')}
                      onMouseEnter={(e) => {
                        const rect = e.currentTarget.getBoundingClientRect()
                        setTooltipPosition({
                          top: rect.bottom + 8,
                          left: rect.left + rect.width / 2
                        })
                        setHoveredTooltip('advanced')
                      }}
                      onMouseLeave={() => {
                        setHoveredTooltip(null)
                        setTooltipPosition(null)
                      }}
                      className={`px-4 py-2 text-sm font-medium transition-all duration-200 ${
                        searchDepth === 'advanced'
                          ? 'bg-white text-blue-600 outline outline-2 outline-blue-600 outline-offset-[-2px] rounded-full'
                          : 'bg-white text-gray-700 hover:bg-gray-50 rounded-r-full'
                      }`}
                    >
                      Advanced
                    </button>
                  </div>
                  
                  <div className="flex items-center gap-2 ml-8 flex-shrink-0">
                    <label htmlFor="maxQueriesPerLead" className="text-sm font-medium text-gray-700 whitespace-nowrap">
                      Search Queries
                    </label>
                    <div className="flex items-center gap-2 w-32">
                      <input
                        type="range"
                        id="maxQueriesPerLead"
                        min="1"
                        max="5"
                        value={maxQueriesPerLead}
                        onChange={(e) => setMaxQueriesPerLead(parseInt(e.target.value) || 2)}
                        className="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer range-slider"
                        style={{
                          background: `linear-gradient(to right, #2563eb 0%, #2563eb ${((maxQueriesPerLead - 1) / 4) * 100}%, #e5e7eb ${((maxQueriesPerLead - 1) / 4) * 100}%, #e5e7eb 100%)`
                        }}
                      />
                      <span className="text-sm font-medium text-gray-700 min-w-[1.5rem] text-right">
                        {maxQueriesPerLead}
                      </span>
                    </div>
                    <style>{`
                      #maxQueriesPerLead::-webkit-slider-thumb {
                        appearance: none;
                        width: 18px;
                        height: 18px;
                        border-radius: 50%;
                        background: #2563eb;
                        cursor: pointer;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
                      }
                      #maxQueriesPerLead::-moz-range-thumb {
                        width: 18px;
                        height: 18px;
                        border-radius: 50%;
                        background: #2563eb;
                        cursor: pointer;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
                      }
                    `}</style>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div ref={extractedFieldsRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Extracted Fields
                  </label>
                  <button
                    type="button"
                    onClick={() => setExtractedFieldsOpen(!extractedFieldsOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {extractedFields.length === 0
                        ? 'Select fields...'
                        : extractedFields.length === 1
                        ? extractedFields[0].replace(/_/g, ' ')
                        : `${extractedFields.length} fields selected`}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${extractedFieldsOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {extractedFieldsOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto">
                      {availableExtractedFields.map((field) => {
                        const isSelected = extractedFields.includes(field)
                        return (
                          <button
                            key={field}
                            type="button"
                            onClick={() => toggleExtractedField(field)}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={`capitalize ${isSelected ? 'text-blue-600' : 'text-gray-700'}`}>{field.replace(/_/g, ' ')}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>

                <div ref={lowInfoBehaviorRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    <span
                      ref={lowInfoLabelRef}
                      className="inline-block cursor-help"
                      onMouseEnter={(e) => {
                        const rect = e.currentTarget.getBoundingClientRect()
                        setLowInfoTooltipPosition({
                          top: rect.bottom + 8,
                          left: rect.left + rect.width / 2
                        })
                        setHoveredLowInfoTooltip(true)
                      }}
                      onMouseLeave={() => {
                        setHoveredLowInfoTooltip(false)
                        setLowInfoTooltipPosition(null)
                      }}
                    >
                      On Low Info Behavior
                    </span>
                  </label>
                  <button
                    type="button"
                    onClick={() => setLowInfoBehaviorOpen(!lowInfoBehaviorOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {onLowInfoBehavior === 'generic_industry' && 'Generic Industry Email'}
                      {onLowInfoBehavior === 'light_personalization' && 'Light Personalization'}
                      {onLowInfoBehavior === 'skip' && 'Skip (Flag for Manual Review)'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${lowInfoBehaviorOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {lowInfoBehaviorOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'generic_industry', label: 'Generic Industry Email' },
                        { value: 'light_personalization', label: 'Light Personalization' },
                        { value: 'skip', label: 'Skip (Flag for Manual Review)' }
                      ].map((option) => {
                        const isSelected = onLowInfoBehavior === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setOnLowInfoBehavior(option.value as 'generic_industry' | 'light_personalization' | 'skip')
                              setLowInfoBehaviorOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

              {/* WRITER Agent Settings */}
              {agentName === 'WRITER' && (
                <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div ref={emailLengthRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Email Length
                  </label>
                  <button
                    type="button"
                    onClick={() => setEmailLengthOpen(!emailLengthOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {emailLength === 'very_short' && 'Very Short (50-100 words)'}
                      {emailLength === 'short' && 'Short (100-200 words)'}
                      {emailLength === 'standard' && 'Standard (200-300 words)'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${emailLengthOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {emailLengthOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'very_short', label: 'Very Short (50-100 words)' },
                        { value: 'short', label: 'Short (100-200 words)' },
                        { value: 'standard', label: 'Standard (200-300 words)' }
                      ].map((option) => {
                        const isSelected = emailLength === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setEmailLength(option.value as 'very_short' | 'short' | 'standard')
                              setEmailLengthOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>

                <div ref={ctaSoftnessRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    CTA Softness
                  </label>
                  <button
                    type="button"
                    onClick={() => setCtaSoftnessOpen(!ctaSoftnessOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {ctaSoftness === 'soft' && 'Soft - Gentle, non-pushy approach'}
                      {ctaSoftness === 'balanced' && 'Balanced - Moderate assertiveness'}
                      {ctaSoftness === 'direct' && 'Direct - Clear and assertive'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${ctaSoftnessOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {ctaSoftnessOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'soft', label: 'Soft - Gentle, non-pushy approach' },
                        { value: 'balanced', label: 'Balanced - Moderate assertiveness' },
                        { value: 'direct', label: 'Direct - Clear and assertive' }
                      ].map((option) => {
                        const isSelected = ctaSoftness === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setCtaSoftness(option.value as 'soft' | 'balanced' | 'direct')
                              setCtaSoftnessOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>
              </div>

              <div ref={personalizationLevelRef} className="relative">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Personalization Level
                </label>
                <button
                  type="button"
                  onClick={() => setPersonalizationLevelOpen(!personalizationLevelOpen)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                >
                  <span className="text-gray-700">
                    {personalizationLevel === 'low' && 'Low - Light references only (industry/company)'}
                    {personalizationLevel === 'medium' && 'Medium - Clear sentence about company or recent event'}
                    {personalizationLevel === 'high' && 'High - Heavily tailored opener + body'}
                  </span>
                  <svg
                    className={`w-5 h-5 text-gray-400 transition-transform ${personalizationLevelOpen ? 'transform rotate-180' : ''}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {personalizationLevelOpen && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                    {[
                      { value: 'low', label: 'Low - Light references only (industry/company)' },
                      { value: 'medium', label: 'Medium - Clear sentence about company or recent event' },
                      { value: 'high', label: 'High - Heavily tailored opener + body' }
                    ].map((option) => {
                      const isSelected = personalizationLevel === option.value
                      return (
                        <button
                          key={option.value}
                          type="button"
                          onClick={() => {
                            setPersonalizationLevel(option.value as 'low' | 'medium' | 'high')
                            setPersonalizationLevelOpen(false)
                          }}
                          className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                        >
                          <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                            <TickerIcon className="w-4 h-4" />
                          </span>
                          <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                        </button>
                      )
                    })}
                  </div>
                )}
              </div>

              <div>
                <div className="flex items-center gap-3 mb-1 flex-nowrap">
                  <label htmlFor="numVariantsPerLead" className="text-sm font-medium text-gray-700 whitespace-nowrap">
                    # Variants Per Lead
                  </label>
                  <div className="flex items-center gap-2 w-32">
                    <input
                      type="range"
                      id="numVariantsPerLead"
                      min="1"
                      max="3"
                      value={numVariantsPerLead}
                      onChange={(e) => setNumVariantsPerLead(parseInt(e.target.value) || 2)}
                      className="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer range-slider"
                      style={{
                        background: `linear-gradient(to right, #2563eb 0%, #2563eb ${((numVariantsPerLead - 1) / 2) * 100}%, #e5e7eb ${((numVariantsPerLead - 1) / 2) * 100}%, #e5e7eb 100%)`
                      }}
                    />
                    <span className="text-sm font-medium text-gray-700 min-w-[1.5rem] text-right">
                      {numVariantsPerLead}
                    </span>
                    <style>{`
                      #numVariantsPerLead::-webkit-slider-thumb {
                        appearance: none;
                        width: 18px;
                        height: 18px;
                        border-radius: 50%;
                        background: #2563eb;
                        cursor: pointer;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
                      }
                      #numVariantsPerLead::-moz-range-thumb {
                        width: 18px;
                        height: 18px;
                        border-radius: 50%;
                        background: #2563eb;
                        cursor: pointer;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
                      }
                    `}</style>
                  </div>
                </div>
              </div>

            </div>
          )}

              {/* CRITIQUE Agent Settings */}
              {agentName === 'CRITIQUE' && (
                <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div ref={qualityChecksRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Quality Checks
                  </label>
                  <button
                    type="button"
                    onClick={() => setQualityChecksOpen(!qualityChecksOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {getSelectedQualityChecks().length === 0 && 'None selected'}
                      {getSelectedQualityChecks().length === 1 && getSelectedQualityChecks()[0]}
                      {getSelectedQualityChecks().length === 2 && getSelectedQualityChecks().join(', ')}
                      {getSelectedQualityChecks().length === 3 && 'All selected'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${qualityChecksOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {qualityChecksOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { key: 'check_personalization', label: 'Check Personalization' },
                        { key: 'check_brand_voice', label: 'Check Brand Voice' },
                        { key: 'check_spamminess', label: 'Check Spamminess' }
                      ].map((option) => {
                        const isSelected = 
                          (option.key === 'check_personalization' && checkPersonalization) ||
                          (option.key === 'check_brand_voice' && checkBrandVoice) ||
                          (option.key === 'check_spamminess' && checkSpamminess)
                        return (
                          <button
                            key={option.key}
                            type="button"
                            onClick={() => toggleQualityCheck(option.key as 'check_personalization' | 'check_brand_voice' | 'check_spamminess')}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Strictness
                  </label>
                  <div className="inline-flex rounded-full shadow-sm border border-gray-300 relative flex-shrink-0" role="group">
                      <button
                        ref={lenientButtonRef}
                        type="button"
                        onClick={() => setStrictness('lenient')}
                        onMouseEnter={(e) => {
                          const rect = e.currentTarget.getBoundingClientRect()
                          setStrictnessTooltipPosition({
                            top: rect.bottom + 8,
                            left: rect.left + rect.width / 2
                          })
                          setHoveredStrictnessTooltip('lenient')
                        }}
                        onMouseLeave={() => {
                          setHoveredStrictnessTooltip(null)
                          setStrictnessTooltipPosition(null)
                        }}
                        className={`px-4 py-2 text-sm font-medium transition-all duration-200 ${
                          strictness === 'lenient'
                            ? 'bg-white text-blue-600 outline outline-2 outline-blue-600 outline-offset-[-2px] rounded-full'
                            : 'bg-white text-gray-700 hover:bg-gray-50 rounded-l-full'
                        }`}
                      >
                        Lenient
                      </button>
                      <button
                        ref={moderateButtonRef}
                        type="button"
                        onClick={() => setStrictness('moderate')}
                        onMouseEnter={(e) => {
                          const rect = e.currentTarget.getBoundingClientRect()
                          setStrictnessTooltipPosition({
                            top: rect.bottom + 8,
                            left: rect.left + rect.width / 2
                          })
                          setHoveredStrictnessTooltip('moderate')
                        }}
                        onMouseLeave={() => {
                          setHoveredStrictnessTooltip(null)
                          setStrictnessTooltipPosition(null)
                        }}
                        className={`px-4 py-2 text-sm font-medium transition-all duration-200 ${
                          strictness === 'moderate'
                            ? 'bg-white text-blue-600 outline outline-2 outline-blue-600 outline-offset-[-2px] rounded-full'
                            : 'bg-white text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        Moderate
                      </button>
                      <button
                        ref={strictButtonRef}
                        type="button"
                        onClick={() => setStrictness('strict')}
                        onMouseEnter={(e) => {
                          const rect = e.currentTarget.getBoundingClientRect()
                          setStrictnessTooltipPosition({
                            top: rect.bottom + 8,
                            left: rect.left + rect.width / 2
                          })
                          setHoveredStrictnessTooltip('strict')
                        }}
                        onMouseLeave={() => {
                          setHoveredStrictnessTooltip(null)
                          setStrictnessTooltipPosition(null)
                        }}
                        className={`px-4 py-2 text-sm font-medium transition-all duration-200 ${
                          strictness === 'strict'
                            ? 'bg-white text-blue-600 outline outline-2 outline-blue-600 outline-offset-[-2px] rounded-full'
                            : 'bg-white text-gray-700 hover:bg-gray-50 rounded-r-full'
                        }`}
                      >
                        Strict
                      </button>
                    </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div ref={rewritePolicyRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Rewrite Policy
                  </label>
                  <button
                    type="button"
                    onClick={() => setRewritePolicyOpen(!rewritePolicyOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {rewritePolicy === 'none' && 'None - Only score + highlight issues'}
                      {rewritePolicy === 'rewrite_if_bad' && 'Rewrite If Bad - Pass to Writer agent to rewrite once'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${rewritePolicyOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {rewritePolicyOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'none', label: 'None - Only score + highlight issues' },
                        { value: 'rewrite_if_bad', label: 'Rewrite If Bad - Pass to Writer agent to rewrite once' }
                      ].map((option) => {
                        const isSelected = rewritePolicy === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setRewritePolicy(option.value as 'none' | 'rewrite_if_bad')
                              setRewritePolicyOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>

                <div ref={variantSelectionRef} className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Variant Selection
                  </label>
                  <button
                    type="button"
                    onClick={() => setVariantSelectionOpen(!variantSelectionOpen)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                  >
                    <span className="text-gray-700">
                      {variantSelection === 'highest_overall_score' && 'Highest Overall Score - Best aggregate quality'}
                      {variantSelection === 'highest_personalization_score' && 'Highest Personalization Score - Best personalization, even if tone slightly worse'}
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${variantSelectionOpen ? 'transform rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {variantSelectionOpen && (
                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                      {[
                        { value: 'highest_overall_score', label: 'Highest Overall Score - Best aggregate quality' },
                        { value: 'highest_personalization_score', label: 'Highest Personalization Score - Best personalization, even if tone slightly worse' }
                      ].map((option) => {
                        const isSelected = variantSelection === option.value
                        return (
                          <button
                            key={option.value}
                            type="button"
                            onClick={() => {
                              setVariantSelection(option.value as 'highest_overall_score' | 'highest_personalization_score')
                              setVariantSelectionOpen(false)
                            }}
                            className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                          >
                            <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                              <TickerIcon className="w-4 h-4" />
                            </span>
                            <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>
              </div>

              <div>
                <div className="flex flex-col items-center gap-3 mb-1">
                  <label htmlFor="minScoreForSend" className="text-sm font-medium text-gray-700 whitespace-nowrap">
                    Minimum Score to Be Eligible for Send
                  </label>
                  <div className="flex items-center gap-2 w-64">
                    <input
                      type="range"
                      id="minScoreForSend"
                      min="1"
                      max="10"
                      value={minScoreForSend}
                      onChange={(e) => setMinScoreForSend(parseInt(e.target.value) || 6)}
                      className="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer range-slider"
                      style={{
                        background: `linear-gradient(to right, #2563eb 0%, #2563eb ${((minScoreForSend - 1) / 9) * 100}%, #e5e7eb ${((minScoreForSend - 1) / 9) * 100}%, #e5e7eb 100%)`
                      }}
                    />
                    <span className="text-sm font-medium text-gray-700 min-w-[1.5rem] text-right">
                      {minScoreForSend}
                    </span>
                    <style>{`
                      #minScoreForSend::-webkit-slider-thumb {
                        appearance: none;
                        width: 18px;
                        height: 18px;
                        border-radius: 50%;
                        background: #2563eb;
                        cursor: pointer;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
                      }
                      #minScoreForSend::-moz-range-thumb {
                        width: 18px;
                        height: 18px;
                        border-radius: 50%;
                        background: #2563eb;
                        cursor: pointer;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
                      }
                    `}</style>
                  </div>
                </div>
              </div>
            </div>
          )}

              {/* DESIGN Agent Settings */}
              {agentName === 'DESIGN' && (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div ref={formatRef} className="relative">
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Format
                      </label>
                      <button
                        type="button"
                        onClick={() => setFormatOpen(!formatOpen)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                      >
                        <span className="text-gray-700">
                          {format === 'plain_text' && 'Plain Text'}
                          {format === 'formatted' && 'Formatted'}
                        </span>
                        <svg
                          className={`w-5 h-5 text-gray-400 transition-transform ${formatOpen ? 'transform rotate-180' : ''}`}
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </svg>
                      </button>
                      {formatOpen && (
                        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                          {[
                            { value: 'plain_text', label: 'Plain Text' },
                            { value: 'formatted', label: 'Formatted' }
                          ].map((option) => {
                            const isSelected = format === option.value
                            return (
                              <button
                                key={option.value}
                                type="button"
                                onClick={() => {
                                  setFormat(option.value as 'plain_text' | 'formatted')
                                  setFormatOpen(false)
                                }}
                                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                              >
                                <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                                  <TickerIcon className="w-4 h-4" />
                                </span>
                                <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                              </button>
                            )
                          })}
                        </div>
                      )}
                    </div>

                    <div ref={ctaStyleRef} className="relative">
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        CTA Style
                      </label>
                      <button
                        type="button"
                        onClick={() => setCtaStyleOpen(!ctaStyleOpen)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                      >
                        <span className="text-gray-700">
                          {ctaStyle === 'link' && 'Link'}
                          {ctaStyle === 'button' && 'Button'}
                        </span>
                        <svg
                          className={`w-5 h-5 text-gray-400 transition-transform ${ctaStyleOpen ? 'transform rotate-180' : ''}`}
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </svg>
                      </button>
                      {ctaStyleOpen && (
                        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                          {[
                            { value: 'link', label: 'Link' },
                            { value: 'button', label: 'Button' }
                          ].map((option) => {
                            const isSelected = ctaStyle === option.value
                            return (
                              <button
                                key={option.value}
                                type="button"
                                onClick={() => {
                                  setCtaStyle(option.value as 'link' | 'button')
                                  setCtaStyleOpen(false)
                                }}
                                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                              >
                                <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                                  <TickerIcon className="w-4 h-4" />
                                </span>
                                <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                              </button>
                            )
                          })}
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div ref={fontFamilyRef} className="relative">
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Font Family
                      </label>
                      <button
                        type="button"
                        onClick={() => setFontFamilyOpen(!fontFamilyOpen)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md text-left text-sm text-gray-900 bg-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:ring-offset-1 focus:ring-offset-white flex items-center justify-between"
                      >
                        <span className="text-gray-700">
                          {fontFamily === 'system_sans' && 'System Sans'}
                          {fontFamily === 'serif' && 'Serif'}
                        </span>
                        <svg
                          className={`w-5 h-5 text-gray-400 transition-transform ${fontFamilyOpen ? 'transform rotate-180' : ''}`}
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </svg>
                      </button>
                      {fontFamilyOpen && (
                        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                          {[
                            { value: 'system_sans', label: 'System Sans' },
                            { value: 'serif', label: 'Serif' }
                          ].map((option) => {
                            const isSelected = fontFamily === option.value
                            return (
                              <button
                                key={option.value}
                                type="button"
                                onClick={() => {
                                  setFontFamily(option.value as 'system_sans' | 'serif')
                                  setFontFamilyOpen(false)
                                }}
                                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center space-x-2"
                              >
                                <span className={`flex-shrink-0 ${isSelected ? 'text-blue-600' : 'text-transparent'}`}>
                                  <TickerIcon className="w-4 h-4" />
                                </span>
                                <span className={isSelected ? 'text-blue-600' : 'text-gray-700'}>{option.label}</span>
                              </button>
                            )
                          })}
                        </div>
                      )}
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Formatting Options
                      </label>
                      <div className="inline-flex rounded-full shadow-sm border border-gray-300 relative flex-shrink-0" role="group">
                        <button
                          type="button"
                          onClick={() => setAllowBold(!allowBold)}
                          className={`px-4 py-2 text-sm font-medium transition-all duration-200 border-r border-gray-300 ${
                            allowBold
                              ? 'bg-blue-600 text-white shadow-inner rounded-l-full'
                              : 'bg-white text-gray-700 hover:bg-gray-50 rounded-l-full'
                          }`}
                        >
                          Bold
                        </button>
                        <button
                          type="button"
                          onClick={() => setAllowItalic(!allowItalic)}
                          className={`px-4 py-2 text-sm font-medium transition-all duration-200 border-r border-gray-300 ${
                            allowItalic
                              ? 'bg-blue-600 text-white shadow-inner'
                              : 'bg-white text-gray-700 hover:bg-gray-50'
                          }`}
                        >
                          Italics
                        </button>
                        <button
                          type="button"
                          onClick={() => setAllowBullets(!allowBullets)}
                          className={`px-4 py-2 text-sm font-medium transition-all duration-200 ${
                            allowBullets
                              ? 'bg-blue-600 text-white shadow-inner rounded-r-full'
                              : 'bg-white text-gray-700 hover:bg-gray-50 rounded-r-full'
                          }`}
                        >
                          Bullets
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Fixed Footer */}
            <div className="flex justify-end space-x-3 p-6 pt-4 border-t border-gray-200 flex-shrink-0">
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
    </>
  )
}
