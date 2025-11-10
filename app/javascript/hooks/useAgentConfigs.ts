import React from 'react'
import { AgentConfig } from '@/types'
import apiClient from '@/libs/utils/apiClient'

interface AgentConfigsResponse {
  campaignId: number
  configs: AgentConfig[]
}

export function useAgentConfigs(campaignId: number | null) {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)
  const [configs, setConfigs] = React.useState<AgentConfig[]>([])

  const loadConfigs = React.useCallback(async () => {
    if (!campaignId) {
      setConfigs([])
      return
    }

    try {
      setLoading(true)
      setError(null)
      
      const response = await apiClient.get<AgentConfigsResponse>(`campaigns/${campaignId}/agent_configs`)
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to load agent configs:', response.error)
        setConfigs([])
      } else {
        const configsFromResponse = response.data?.configs ?? []
        const normalisedConfigs = configsFromResponse.map((cfg) => ({
          ...cfg,
          settings: cfg.settings ?? {}
        }))
        setConfigs(normalisedConfigs)
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load agent configs'
      setError(errorMessage)
      console.error('Error loading agent configs:', err)
      setConfigs([])
    } finally {
      setLoading(false)
    }
  }, [campaignId])

  const createConfig = async (config: Omit<AgentConfig, 'id' | 'createdAt' | 'updatedAt'>): Promise<AgentConfig | null> => {
    if (!campaignId) {
      setError('No campaign selected')
      return null
    }

    try {
      setError(null)
      
      const response = await apiClient.post<AgentConfig>(`campaigns/${campaignId}/agent_configs`, {
        agent_config: config
      })
      
      if (response.error) {
        const errorMsg = response.data?.errors ? response.data.errors.join(', ') : response.error
        setError(errorMsg)
        console.error('Failed to create agent config:', response.error)
        return null
      }
      
      const newConfig = response.data
      if (newConfig) {
        setConfigs(prev => [...prev, newConfig])
        return newConfig
      }
      return null
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create agent config'
      setError(errorMessage)
      console.error('Error creating agent config:', err)
      return null
    }
  }

  const updateConfig = async (configId: number, updates: Partial<AgentConfig>): Promise<boolean> => {
    if (!campaignId) {
      setError('No campaign selected')
      return false
    }

    try {
      setError(null)
      
      const response = await apiClient.put<AgentConfig>(`campaigns/${campaignId}/agent_configs/${configId}`, {
        agent_config: updates
      })
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to update agent config:', response.error)
        return false
      }
      
      const updatedConfig = response.data
      if (updatedConfig) {
        setConfigs(prev => prev.map(c => c.id === configId ? updatedConfig : c))
      }
      return true
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update agent config'
      setError(errorMessage)
      console.error('Error updating agent config:', err)
      return false
    }
  }

  // Load configs when campaign changes
  React.useEffect(() => {
    loadConfigs()
  }, [loadConfigs])

  return {
    loading,
    error,
    configs,
    loadConfigs,
    createConfig,
    updateConfig
  }
}

