export interface BrandVoice {
  tone: 'formal' | 'professional' | 'friendly'
  persona: 'founder' | 'sales' | 'cs'
}

export interface SharedSettings {
  brand_voice: BrandVoice
  primary_goal: 'book_call' | 'get_reply' | 'get_click'
  product_info?: string
  sender_company?: string
}

export interface Campaign {
  id?: number
  title: string
  sharedSettings?: SharedSettings
}

export interface Lead {
  id: number
  name: string
  email: string
  title: string
  company: string
  website: string
  campaignId: number
  stage: string
  quality: string
}

export interface CampaignFormData {
  title: string
  productInfo?: string
  senderCompany?: string
  tone?: string
  persona?: string
  primaryGoal?: string
}

export interface LeadFormData {
  name: string
  email: string
  title: string
  company: string
}

export interface AgentOutput {
  agentName: string
  status: 'pending' | 'completed' | 'failed'
  outputData: Record<string, unknown> | null
  errorMessage?: string
  createdAt: string
  updatedAt: string
}

export type AgentConfigName = 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE'

export interface SearchAgentSettings {
  search_depth?: 'basic' | 'advanced'
  max_queries_per_lead?: number
  extracted_fields?: string[]
  on_low_info_behavior?: 'generic_industry' | 'light_personalization' | 'skip'
}

export interface WriterAgentSettings {
  tone?: 'formal' | 'professional' | 'friendly'
  sender_persona?: 'founder' | 'sales' | 'cs'
  email_length?: 'very_short' | 'short' | 'standard'
  personalization_level?: 'low' | 'medium' | 'high'
  primary_cta_type?: 'book_call' | 'get_reply' | 'get_click'
  cta_softness?: 'soft' | 'balanced' | 'direct'
  use_bullets?: boolean
  num_variants_per_lead?: number
  // Legacy fields for backward compatibility
  product_info?: string
  sender_company?: string
}

export interface CritiqueAgentChecks {
  check_personalization?: boolean
  check_brand_voice?: boolean
  check_spamminess?: boolean
}

export interface CritiqueAgentSettings {
  checks?: CritiqueAgentChecks
  strictness?: 'lenient' | 'moderate' | 'strict'
  rewrite_policy?: 'none' | 'rewrite_if_bad'
  min_score_for_send?: number
  variant_selection?: 'highest_overall_score' | 'highest_personalization_score'
}

export interface DesignAgentSettings {
  format?: 'plain_text' | 'formatted'
  allowBold?: boolean
  allowItalic?: boolean
  allowBullets?: boolean
  ctaStyle?: 'link' | 'button'
  fontFamily?: 'system_sans' | 'serif'
}

export interface AgentConfig {
  id?: number
  agentName: AgentConfigName
  enabled: boolean
  settings: SearchAgentSettings | WriterAgentSettings | CritiqueAgentSettings | DesignAgentSettings | Record<string, unknown>
  createdAt?: string
  updatedAt?: string
}

export interface RunAgentsResponse {
  status: 'completed' | 'partial' | 'failed'
  outputs: Record<string, unknown>
  lead: Lead
  completedAgents: string[]
  failedAgents: string[]
  error?: string
}


