import React from 'react'
import { RunAgentsResponse } from '@/types'
import apiClient from '@/libs/utils/apiClient'

export function useAgentExecution() {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)

  const runAgentsForLead = async (leadId: number): Promise<RunAgentsResponse | null> => {
    try {
      setLoading(true)
      setError(null)
      
      const response = await apiClient.post<RunAgentsResponse>(`leads/${leadId}/run_agents`, {})
      
      if (response.error) {
        const errorMsg = response.data?.error || response.error
        setError(errorMsg)
        console.error('[useAgentExecution] Failed to run agents:', response.error)
        
        // Return error response if available, otherwise null
        if (response.data && typeof response.data === 'object') {
          return response.data as RunAgentsResponse
        }
        return null
      }
      
      if (!response.data) {
        return null
      }
      
      return response.data
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to run agents'
      setError(errorMessage)
      console.error('[useAgentExecution] Exception:', err)
      return null
    } finally {
      setLoading(false)
    }
  }

  const runAgentsForMultipleLeads = async (leadIds: number[]): Promise<Map<number, RunAgentsResponse | null>> => {
    const results = new Map<number, RunAgentsResponse | null>()
    
    for (const leadId of leadIds) {
      const result = await runAgentsForLead(leadId)
      results.set(leadId, result)
    }
    
    return results
  }

  return {
    loading,
    error,
    runAgentsForLead,
    runAgentsForMultipleLeads
  }
}

