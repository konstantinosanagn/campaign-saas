import React from 'react'
import { Lead, LeadFormData } from '@/types'
import apiClient from '@/libs/utils/apiClient'

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
      } else {
        setLeads(response.data || [])
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load leads'
      setError(errorMessage)
      console.error('Error loading leads:', err)
    } finally {
      setLoading(false)
    }
  }

  const createLead = async (data: LeadFormData, campaignId: number) => {
    try {
      setError(null)
      
      // Add campaignId from parameter
      const leadData = {
        ...data,
        website: data.email.split('@')[1] || '',
        stage: 'queued',
        quality: '-',
        campaignId: campaignId
      }
      
      const response = await apiClient.create<Lead>('leads', leadData)

      if (response.error) {
        const errorMsg = response.data?.errors ? response.data.errors.join(', ') : response.error
        setError(errorMsg)
        console.error('Failed to create lead:', response.error, response.data)
        return false
      } else {
        // Add the new lead to the list
        const newLead = response.data
        if (newLead) {
          setLeads(prev => [...prev, newLead])
        }
        return true
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create lead'
      setError(errorMessage)
      console.error('Error creating lead:', err)
      return false
    }
  }

  const updateLead = async (leadId: number, data: LeadFormData) => {
    try {
      setError(null)
      
      const leadData = {
        ...data,
        website: data.email.split('@')[1] || ''
      }
      
      const response = await apiClient.update<Lead>('leads', leadId, leadData)

      if (response.error) {
        setError(response.error)
        console.error('Failed to update lead:', response.error)
        return false
      } else {
        // Update the lead in the list
        const updatedLead = response.data
        if (updatedLead) {
          setLeads(prev => prev.map(lead => lead.id === leadId ? updatedLead : lead))
        }
        return true
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update lead'
      setError(errorMessage)
      console.error('Error updating lead:', err)
      return false
    }
  }

  const deleteLeads = async (leadIds: number[]) => {
    // Show confirmation dialog first (synchronously)
    if (!confirm(`Are you sure you want to delete ${leadIds.length} lead(s)?`)) {
      return false
    }

    try {
      setError(null)
      
      // Delete each lead individually
      const deletePromises = leadIds.map(leadId => 
        apiClient.destroy('leads', leadId)
      )
      
      const responses = await Promise.all(deletePromises)
      
      // Check if any deletions failed
      const failedDeletions = responses.filter(response => response.error)
      if (failedDeletions.length > 0) {
        setError(`Failed to delete ${failedDeletions.length} lead(s)`)
        console.error('Some lead deletions failed:', failedDeletions)
        return false
      }
      
      // Remove deleted leads from the list
      setLeads(prev => prev.filter(lead => !leadIds.includes(lead.id)))
      return true
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to delete leads'
      setError(errorMessage)
      console.error('Error deleting leads:', err)
      return false
    }
  }

  const findLead = (leadId: number) => {
    return leads.find((l) => l.id === leadId)
  }

  return { 
    leads, 
    loading, 
    error, 
    createLead, 
    updateLead, 
    deleteLeads, 
    findLead,
    refreshLeads: loadLeads
  }
}


