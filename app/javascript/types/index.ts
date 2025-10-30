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
  outputData: any
  errorMessage?: string
  createdAt: string
  updatedAt: string
}

export interface AgentConfig {
  id?: number
  agentName: 'SEARCH' | 'WRITER' | 'CRITIQUE'
  enabled: boolean
  settings: {
    product_info?: string
    sender_company?: string
    [key: string]: any
  }
  createdAt?: string
  updatedAt?: string
}

export interface RunAgentsResponse {
  status: 'completed' | 'partial' | 'failed'
  outputs: Record<string, any>
  lead: Lead
  completedAgents: string[]
  failedAgents: string[]
  error?: string
}


