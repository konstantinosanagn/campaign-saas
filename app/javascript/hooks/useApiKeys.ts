import React from 'react'
import apiClient from '@/libs/utils/apiClient'

interface ApiKeys {
  llmApiKey: string
  tavilyApiKey: string
}

export function useApiKeys() {
  const [keys, setKeys] = React.useState<ApiKeys>({
    llmApiKey: '',
    tavilyApiKey: ''
  })
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  // Load keys from Rails API on mount
  React.useEffect(() => {
    loadKeys()
  }, [])

  const loadKeys = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await apiClient.get<ApiKeys>('api_keys') // Remove the ID since it's a singular resource
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to load API keys:', response.error)
      } else {
        setKeys(response.data || { llmApiKey: '', tavilyApiKey: '' })
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load API keys'
      setError(errorMessage)
      console.error('Error loading API keys:', err)
    } finally {
      setLoading(false)
    }
  }

  const saveKeys = async (newKeys: ApiKeys) => {
    try {
      setError(null)
      const response = await apiClient.put<ApiKeys>('api_keys', newKeys) // Remove the ID since it's a singular resource
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to save API keys:', response.error)
        return false
      } else {
        // Update local state with the saved keys
        const savedKeys = response.data
        if (savedKeys) {
          setKeys(savedKeys)
        }
        return true
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to save API keys'
      setError(errorMessage)
      console.error('Error saving API keys:', err)
      return false
    }
  }

  const clearKeys = async () => {
    try {
      setError(null)
      const emptyKeys = { llmApiKey: '', tavilyApiKey: '' }
      const response = await apiClient.put<ApiKeys>('api_keys', emptyKeys) // Remove the ID since it's a singular resource
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to clear API keys:', response.error)
        return false
      } else {
        setKeys(emptyKeys)
        return true
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to clear API keys'
      setError(errorMessage)
      console.error('Error clearing API keys:', err)
      return false
    }
  }

  return {
    keys,
    loading,
    error,
    saveKeys,
    clearKeys,
    refreshKeys: loadKeys
  }
}
