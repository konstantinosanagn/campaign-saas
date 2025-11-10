import React from 'react'
import { Campaign, CampaignFormData } from '@/types'
import apiClient from '@/libs/utils/apiClient'

export function useCampaigns() {
  const [campaigns, setCampaigns] = React.useState<Campaign[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  // Load campaigns on mount
  React.useEffect(() => {
    loadCampaigns()
  }, [])

  const loadCampaigns = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await apiClient.index<Campaign[]>('campaigns')
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to load campaigns:', response.error)
        return
      }

      setCampaigns(response.data || [])
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load campaigns'
      setError(errorMessage)
      console.error('Error loading campaigns:', err)
    } finally {
      setLoading(false)
    }
  }

  const createCampaign = async (data: CampaignFormData): Promise<Campaign | null> => {
    try {
      setError(null)
      const response = await apiClient.create<Campaign>('campaigns', data)
      
      if (response.error) {
        const errors = response.data?.errors ?? []
        const errorMsg = errors.length > 0 ? errors.join(', ') : response.error
        setError(errorMsg)

        if (errors.length > 0) {
          console.error('Failed to create campaign:', response.error, { errors })
        } else {
          console.error('Failed to create campaign:', response.error)
        }

        return null
      }

      const newCampaign = response.data
      if (!newCampaign) {
        return null
      }

      setCampaigns(prev => [...prev, newCampaign])
      return newCampaign
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create campaign'
      setError(errorMessage)
      console.error('Error creating campaign:', err)
      return null
    }
  }

  const updateCampaign = async (index: number, data: CampaignFormData) => {
    try {
      const campaign = campaigns[index]
      if (!campaign || !campaign.id) {
        setError('Campaign ID not found')
        return false
      }

      setError(null)
      const response = await apiClient.update<Campaign>('campaigns', campaign.id, data)
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to update campaign:', response.error)
        return false
      }

      const updatedCampaign = response.data
      if (!updatedCampaign) {
        setError('No data returned from server')
        return false
      }

      setCampaigns(prev => prev.map((c, i) => (i === index ? updatedCampaign : c)))
      return true
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update campaign'
      setError(errorMessage)
      console.error('Error updating campaign:', err)
      return false
    }
  }

  const deleteCampaign = async (index: number) => {
    try {
      const campaign = campaigns[index]
      if (!campaign || !campaign.id) {
        setError('Campaign ID not found')
        return false
      }

      if (!window.confirm('Are you sure you want to delete this campaign? This action cannot be undone.')) {
        return false
      }

      setError(null)
      const response = await apiClient.destroy('campaigns', campaign.id)
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to delete campaign:', response.error)
        return false
      }

      setCampaigns(prev => prev.filter((_, i) => i !== index))
      return true
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to delete campaign'
      setError(errorMessage)
      console.error('Error deleting campaign:', err)
      return false
    }
  }

  return { 
    campaigns, 
    loading, 
    error, 
    createCampaign, 
    updateCampaign, 
    deleteCampaign,
    refreshCampaigns: loadCampaigns
  }
}


