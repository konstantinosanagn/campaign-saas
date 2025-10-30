import React from 'react'
import { AgentOutput } from '@/types'
import apiClient from '@/libs/utils/apiClient'

interface AgentOutputsResponse {
  leadId: number
  outputs: AgentOutput[]
}

export function useAgentOutputs() {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)
  const [outputs, setOutputs] = React.useState<AgentOutput[]>([])

  const loadAgentOutputs = async (leadId: number) => {
    try {
      setLoading(true)
      setError(null)
      
      const response = await apiClient.get<AgentOutputsResponse>(`leads/${leadId}/agent_outputs`)
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to load agent outputs:', response.error)
        setOutputs([])
      } else {
        setOutputs(response.data?.outputs || [])
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load agent outputs'
      setError(errorMessage)
      console.error('Error loading agent outputs:', err)
      setOutputs([])
    } finally {
      setLoading(false)
    }
  }

  return {
    loading,
    error,
    outputs,
    loadAgentOutputs
  }
}

