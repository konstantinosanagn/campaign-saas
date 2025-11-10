export interface Campaign {
  id?: number
  title: string
  basePrompt: string
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
  basePrompt: string
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

export interface AgentConfig {
  id?: number
  agentName: AgentConfigName
  enabled: boolean
  settings: Record<string, unknown>
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


