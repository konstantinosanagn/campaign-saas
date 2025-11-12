import React from 'react'
import { Lead, LeadFormData } from '@/types'
import apiClient from '@/libs/utils/apiClient'

type LeadActionError = {
  success: false
  error: string
  errors?: string[]
  deletedIds?: number[]
}

type LeadDeleteSuccess = {
  success: true
  deletedIds: number[]
}

export function useLeads() {
  const [leads, setLeads] = React.useState<Lead[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  // Load leads on mount
  React.useEffect(() => {
    loadLeads()
  }, [])

  const loadLeads = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await apiClient.index<Lead[]>('leads')
      
      if (response.error) {
        setError(response.error)
        console.error('Failed to load leads:', response.error)
        return
      }

      setLeads(response.data || [])
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load leads'
      setError(errorMessage)
      console.error('Error loading leads:', err)
    } finally {
      setLoading(false)
    }
  }

  const createLead = async (
    data: LeadFormData & { campaignId?: number; website?: string }
  ): Promise<boolean | LeadActionError> => {
    try {
      setError(null)

      const campaignId = data.campaignId
      if (!campaignId) {
        const missingCampaignError = 'Campaign not found or unauthorized'
        setError(missingCampaignError)
        console.error('Failed to create lead:', missingCampaignError)
        return {
          success: false,
          error: missingCampaignError,
          errors: [],
        }
      }

      const hasAtSymbol = data.email.includes('@')
      const website =
        data.website && data.website.trim().length > 0
          ? data.website.trim()
          : hasAtSymbol
            ? `https://${data.email.split('@')[1]}`.replace('https://https://', 'https://')
            : ''

      const payload = {
        name: data.name,
        email: data.email,
        title: data.title,
        company: data.company,
        website,
        stage: 'queued',
        quality: '-',
        campaignId,
      }
      console.log("📦 [createLead] Sending payload to backend:", JSON.stringify(payload, null, 2))
      const response = await apiClient.create<Lead>('leads', payload )
      console.log("📬 [createLead] Response from backend:", response)

      if (response.error) {
        const errors = response.data?.errors ?? response.errors ?? []
        const errorMsg = Array.isArray(errors) && errors.length > 0 ? errors.join(', ') : response.error
        setError(errorMsg)

        if (errors.length > 0) {
          console.error('Failed to create lead:', response.error, { errors })
        } else {
          console.error('Failed to create lead:', response.error)
        }

        return errors.length > 0
          ? false
          : {
            success: false,
            error: response.error ?? 'Failed to create lead',
            errors: [],
          }
      }

      const newLead = response.data
      if (!newLead) {
        return {
          success: false,
          error: 'No data returned from server',
          errors: [],
        }
      }

      setLeads((prev) => [...prev, newLead])
      return true
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create lead'
      setError(errorMessage)
      console.error('Error creating lead:', err)
      return {
        success: false,
        error: errorMessage,
        errors: [],
      }
    }
  }

  const updateLead = async (
    leadId: number,
    data: LeadFormData & { website?: string }
  ): Promise<{ success: true; data: Lead } | LeadActionError> => {
    try {
      setError(null)

      const website =
        data.website && data.website.trim().length > 0
          ? data.website
          : data.email.includes('@')
            ? `https://${data.email.split('@')[1]}`.replace('https://https://', 'https://')
            : ''

       const payload = {
          name: data.name,
          email: data.email,
          title: data.title,
          company: data.company,
          website,
        }
      const response = await apiClient.update<Lead>('leads', leadId, payload )

      if (response.error) {
        setError(response.error)
        console.error('Failed to update lead:', response.error)
        return {
          success: false,
          error: response.error,
          errors: [],
        }
      }

      const updatedLead = response.data

      if (!updatedLead) {
        return {
          success: false,
          error: 'No data returned from server',
          errors: [],
        }
      }

      setLeads((prev) => prev.map((lead) => (lead.id === leadId ? updatedLead : lead)))
      return {
        success: true,
        data: updatedLead,
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update lead'
      setError(errorMessage)
      console.error('Error updating lead:', err)
      return {
        success: false,
        error: errorMessage,
        errors: [],
      }
    }
  }

  const deleteLeads = async (leadIds: number[]): Promise<LeadDeleteSuccess | LeadActionError> => {
    // Show confirmation dialog first (synchronously)
    if (!window.confirm(`Are you sure you want to delete ${leadIds.length} lead(s)?`)) {
      return {
        success: false,
        error: 'Deletion cancelled by user',
        deletedIds: [],
      }
    }

    try {
      setError(null)

      const successfulIds: number[] = []

      for (const leadId of leadIds) {
        try {
          const response = await apiClient.destroy('leads', leadId)
          if (response && response.error) {
            console.error(`Failed to delete lead ${leadId}:`, response.error)
            const deletedIds = [...successfulIds]
            if (deletedIds.length > 0) {
              setLeads((prev) => prev.filter((lead) => !deletedIds.includes(lead.id)))
            }
            setError('Some leads could not be deleted')
        return {
          success: false,
          error: 'Some leads could not be deleted',
          deletedIds,
        }
          }

          successfulIds.push(leadId)
        } catch (err) {
          const errorMessage = err instanceof Error ? err.message : 'Failed to delete leads'
          setError(errorMessage)
          console.error(`Error deleting lead ${leadId}:`, err)
          const deletedIds = [...successfulIds]
          if (deletedIds.length > 0) {
            setLeads((prev) => prev.filter((lead) => !deletedIds.includes(lead.id)))
          }
          return {
            success: false,
            error: errorMessage,
            deletedIds,
          }
        }
      }

      setLeads((prev) => prev.filter((lead) => !successfulIds.includes(lead.id)))
      return {
        success: true,
        deletedIds: successfulIds,
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to delete leads'
      setError(errorMessage)
      console.error('Error deleting leads:', err)
      return {
        success: false,
        error: errorMessage,
        deletedIds: [],
      }
    }
  }

  const findLeadById = (leadId: number) => leads.find((l) => l.id === leadId)
  const findLead = findLeadById

  return { 
    leads, 
    loading, 
    error, 
    createLead, 
    updateLead, 
    deleteLeads, 
    findLead,
    findLeadById,
    refreshLeads: loadLeads
  }
}


