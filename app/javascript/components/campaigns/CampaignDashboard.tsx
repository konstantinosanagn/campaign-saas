import React, { useState, useCallback } from 'react'
import Navigation from '@/components/shared/Navigation'
import Background from '@/components/shared/Background'
import CampaignForm from '@/components/campaigns/CampaignForm'
import CampaignSidebar from '@/components/campaigns/CampaignSidebar'
import ProgressTable from '@/components/leads/ProgressTable'
import LeadForm from '@/components/leads/LeadForm'
import AgentDashboard from '@/components/agents/AgentDashboard'
import EmptyState from '@/components/shared/EmptyState'
import AgentOutputModal from '@/components/agents/AgentOutputModal'
import AgentSettingsModal from '@/components/agents/AgentSettingsModal'
import EmailConfigModal from '@/components/shared/EmailConfigModal'
import { useCampaigns } from '@/hooks/useCampaigns'
import { useLeads } from '@/hooks/useLeads'
import { useSelection } from '@/hooks/useSelection'
import { useTypewriter } from '@/hooks/useTypewriter'
import { useAgentExecution } from '@/hooks/useAgentExecution'
import { useAgentOutputs } from '@/hooks/useAgentOutputs'
import { useAgentConfigs } from '@/hooks/useAgentConfigs'
import type { Lead, AgentConfig } from '@/types'

type SendEmailsResponse = {
  success?: boolean
  sent?: number
  failed?: number
  errors?: Array<{ lead_email?: string; error?: string }>
  error?: string
}

interface CampaignDashboardProps {
  user?: {
    first_name?: string | null;
    last_name?: string | null;
    name?: string | null;
    workspace_name?: string | null;
    job_title?: string | null;
  };
}

export default function CampaignDashboard({ user }: CampaignDashboardProps = {}) {
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [isEditFormOpen, setIsEditFormOpen] = useState(false)
  const [isLeadFormOpen, setIsLeadFormOpen] = useState(false)
  const [isEditLeadFormOpen, setIsEditLeadFormOpen] = useState(false)

  const [editingCampaign, setEditingCampaign] = useState<{ index: number; title: string; productInfo?: string; senderCompany?: string; tone?: string; persona?: string; primaryGoal?: string } | null>(null)
  const [editingLead, setEditingLead] = useState<{ id: number; name: string; email: string; title: string; company: string } | null>(null)

  const [selectedCampaign, setSelectedCampaign] = useState<number | null>(null)
  const [pendingCampaignId, setPendingCampaignId] = React.useState<number | null>(null)

  // Agent modals state
  const [isOutputModalOpen, setIsOutputModalOpen] = useState(false)
  const [outputModalLead, setOutputModalLead] = useState<Lead | null>(null)
  const [isSettingsModalOpen, setIsSettingsModalOpen] = useState(false)
  const [settingsModalAgent, setSettingsModalAgent] = useState<'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE' | null>(null)
  const [isEmailConfigModalOpen, setIsEmailConfigModalOpen] = useState(false)

  const { campaigns, createCampaign, updateCampaign, deleteCampaign } = useCampaigns()
  const { leads, createLead, updateLead, deleteLeads, refreshLeads } = useLeads()
  const findLeadById = React.useCallback(
    (leadId: number) => leads.find((lead) => lead.id === leadId),
    [leads]
  )
  const { selectedIds: selectedLeads, toggleSelection, toggleMultiple, clearSelection } = useSelection()

  // Auto-select newly created campaign
  React.useEffect(() => {
    if (pendingCampaignId !== null) {
      const index = campaigns.findIndex(c => c.id === pendingCampaignId)
      if (index !== -1) {
        setSelectedCampaign(index)
        setPendingCampaignId(null)
      }
    }
  }, [campaigns, pendingCampaignId])

  const campaignObj =
    selectedCampaign !== null && campaigns[selectedCampaign]
      ? campaigns[selectedCampaign]
      : null;

  const { loading: agentExecLoading, runAgentsForLead } = useAgentExecution()
  const [runningLeadIds, setRunningLeadIds] = React.useState<Set<number>>(new Set())
  const isMountedRef = React.useRef(true)

  React.useEffect(() => {
    return () => {
      isMountedRef.current = false
    }
  }, [])

  const addRunningLeadId = React.useCallback((leadId: number) => {
    setRunningLeadIds((prev) => {
      if (prev.has(leadId)) {
        return prev
      }
      const next = new Set(prev)
      next.add(leadId)
      return next
    })
  }, [])

  const removeRunningLeadId = React.useCallback((leadId: number) => {
    setRunningLeadIds((prev) => {
      if (!prev.has(leadId)) {
        return prev
      }
      const next = new Set(prev)
      next.delete(leadId)
      return next
    })
  }, [])

  const waitForLeadCompletion = React.useCallback(
    async (leadId: number, startingStage: string | null) => {
      const MAX_ATTEMPTS = 40
      const POLL_INTERVAL_MS = 3000
      let currentStage = startingStage

      try {
        for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
          if (!isMountedRef.current) {
            return
          }

          await new Promise((resolve) => window.setTimeout(resolve, POLL_INTERVAL_MS))
          const latestLeads = await refreshLeads({ silent: true })
          const latestLead = latestLeads?.find((lead) => lead.id === leadId)

          if (!latestLead) {
            // Lead not found, stop polling
            break
          }

          // Check if stage has changed (meaning agent for previous stage completed)
          if (currentStage !== latestLead.stage) {
            currentStage = latestLead.stage
            
            // Stage changed means the agent for the previous stage completed
            // Remove the loading cube and stop polling
            console.log(`[AgentPolling] Lead ${leadId} stage changed from "${startingStage}" to "${currentStage}". Agent completed.`)
            break
          }

          // Check if we've reached a final stage (all agents done)
          const reachedFinalStage = latestLead.stage === 'completed' || latestLead.stage === 'designed'
          if (reachedFinalStage) {
            console.log(`[AgentPolling] Lead ${leadId} reached final stage "${latestLead.stage}".`)
            break
          }

          // Timeout warning on last attempt
          if (attempt === MAX_ATTEMPTS - 1) {
            console.warn(`[AgentPolling] Lead ${leadId} is still processing after ${MAX_ATTEMPTS * (POLL_INTERVAL_MS / 1000)} seconds.`)
          }
        }
      } catch (pollError) {
        console.error('Error while polling lead status:', pollError)
      } finally {
        // Always remove the loading cube when polling stops
        if (isMountedRef.current) {
          removeRunningLeadId(leadId)
        }
      }
    },
    [refreshLeads, removeRunningLeadId]
  )
  const { loading: outputsLoading, outputs, loadAgentOutputs } = useAgentOutputs()
  const { configs, loading: configsLoading, updateConfig, createConfig, loadConfigs } = useAgentConfigs(campaignObj?.id || null)
  
  const [sendingEmails, setSendingEmails] = useState(false)

  const campaignTitle = campaignObj ? (campaignObj.title || '') : '';
  const displayedTitle = useTypewriter(campaignTitle)

  // Filter leads by selected campaign
  const filteredLeads = React.useMemo(() => {
    if (selectedCampaign === null || !campaignObj?.id) {
      return []
    }
    return leads.filter(lead => lead.campaignId === campaignObj.id)
  }, [leads, selectedCampaign, campaignObj])

  const handleCampaignClick = (campaignIndex: number) => {
    if (selectedCampaign === campaignIndex) {
      setSelectedCampaign(null)
    } else {
      setSelectedCampaign(campaignIndex)
    }
  }

  const handleCreateCampaign = async (data: { title: string; productInfo?: string; senderCompany?: string; tone?: string; persona?: string; primaryGoal?: string }) => {
    const newCampaign = await createCampaign(data)
    if (newCampaign && newCampaign.id) {
      // Set pending campaign ID, useEffect will select it when campaigns array updates
      setPendingCampaignId(newCampaign.id)
    }
  }

  const handleEditCampaign = (data: { title: string; productInfo?: string; senderCompany?: string; tone?: string; persona?: string; primaryGoal?: string }) => {
    if (editingCampaign) {
      updateCampaign(editingCampaign.index, data)
      setEditingCampaign(null)
    }
  }

  const handleEditClick = (index: number) => {
    const campaign = campaigns[index]
    setEditingCampaign({ 
      index, 
      title: campaign.title, 
      productInfo: campaign.sharedSettings?.product_info,
      senderCompany: campaign.sharedSettings?.sender_company,
      tone: campaign.sharedSettings?.brand_voice?.tone,
      persona: campaign.sharedSettings?.brand_voice?.persona,
      primaryGoal: campaign.sharedSettings?.primary_goal
    })
    setIsEditFormOpen(true)
  }

  const handleDeleteCampaign = async (index: number) => {
    const success = await deleteCampaign(index)
    if (success) {
      // Clear selection if deleted campaign was selected
      if (selectedCampaign === index) {
        setSelectedCampaign(null)
      } else if (selectedCampaign !== null && selectedCampaign > index) {
        // Adjust selection index if deleted campaign was before selected one
        setSelectedCampaign(selectedCampaign - 1)
      }
      clearSelection()
    }
  }

  const handleCreateLead = (data: { name: string; email: string; title: string; company: string }) => {
    if (selectedCampaign === null || !campaignObj?.id) {
      console.error('No campaign selected')
      return
    }
    createLead({
      ...data,
      campaignId: campaignObj.id,
    })
  }

  const handleEditLead = (data: { name: string; email: string; title: string; company: string }) => {
    if (editingLead) {
      updateLead(editingLead.id, data)
    }
  }

  const handleImportLeads = React.useCallback(async (rows: Array<{ firstName: string; lastName: string; email: string; title: string; company: string }>) => {
    if (selectedCampaign === null || !campaignObj?.id) {
      return { success: false as const, error: 'Please select a campaign before importing leads.' }
    }

    try {
      for (const row of rows) {
        const trimmedFirst = row.firstName.trim()
        const trimmedLast = row.lastName.trim()
        const fullName = [trimmedFirst, trimmedLast].filter(Boolean).join(' ')
        const result = await createLead({
          name: fullName,
          email: row.email.trim(),
          title: row.title.trim(),
          company: row.company.trim(),
          campaignId: campaignObj.id,
        })

        if (result !== true) {
          const errorMessage =
            typeof result === 'object' && result !== null && 'error' in result
              ? result.error ?? 'Failed to create lead.'
              : 'Failed to create lead.'
          return { success: false as const, error: errorMessage }
        }
      }

      await refreshLeads()
      return { success: true as const }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to import leads.'
      return { success: false as const, error: message }
    }
  }, [campaignObj, createLead, refreshLeads, selectedCampaign])

  const handleLeadClick = useCallback((lead: Lead) => {
    // Allow toggling selection for all leads
    toggleSelection(lead.id)
  }, [toggleSelection])

  const handleEditSelectedLead = () => {
    if (selectedLeads.length === 1) {
      const lead = findLeadById(selectedLeads[0])
      if (lead) {
        setEditingLead({ id: lead.id, name: lead.name, email: lead.email, title: lead.title, company: lead.company })
        setIsEditLeadFormOpen(true)
      }
    }
  }

  const handleDeleteSelectedLeads = async () => {
    if (selectedLeads.length > 0) {
      const success = await deleteLeads(selectedLeads)
      if (success) {
        clearSelection()
      }
    }
  }

  const handleRunLead = useCallback(async (leadId: number) => {
    const initialStage = findLeadById(leadId)?.stage ?? null
    addRunningLeadId(leadId)
    try {
      console.log('Running agents for lead:', leadId)
      const result = await runAgentsForLead(leadId)
      console.log('Agent execution result:', result)

      if (!result) {
        const errorMsg = 'Failed to run agents. Please check the console for details.'
        alert(errorMsg)
        console.error('Agent execution returned null - check API response')
        removeRunningLeadId(leadId)
        return
      }

      if (result.status === 'failed' && result.error) {
        alert(`Failed to run agents: ${result.error}`)
        console.error('Agent execution failed:', result.error)
      } else if (result.failedAgents && result.failedAgents.length > 0) {
        alert(`Some agents failed: ${result.failedAgents.join(', ')}`)
        console.error('Some agents failed:', result.failedAgents)
      }

      if (result.status === 'queued') {
        waitForLeadCompletion(leadId, initialStage).catch((err) => {
          console.error('Error while polling lead status:', err)
          removeRunningLeadId(leadId)
        })
        return
      }

      if (result.status === 'error' && result.error) {
        alert(`Error running agents: ${result.error}`)
      }

      await refreshLeads()
      removeRunningLeadId(leadId)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
      alert(`Error running agents: ${errorMessage}`)
      console.error('Exception in handleRunLead:', err)
      removeRunningLeadId(leadId)
    }
  }, [findLeadById, addRunningLeadId, runAgentsForLead, waitForLeadCompletion, refreshLeads, removeRunningLeadId])

  const handleStageClick = useCallback(async (lead: Lead) => {
    setOutputModalLead(lead)
    setIsOutputModalOpen(true)
    await loadAgentOutputs(lead.id)
  }, [loadAgentOutputs])

  const handleRunAllAgents = useCallback(() => {
    if (!filteredLeads.length) return

    const leadsToRun = filteredLeads
      .filter((l) => l.stage !== 'completed')
      .map((l) => l.id)

    leadsToRun.forEach((id) => {
      handleRunLead(id)
    })
  }, [filteredLeads, handleRunLead])

  const handleAgentSettingsClick = useCallback((agentName: 'SEARCH' | 'WRITER' | 'DESIGNER' | 'CRITIQUE') => {
    console.log('handleAgentSettingsClick called with:', agentName)
    // Map 'DESIGNER' to 'DESIGN' for the modal
    const modalAgentName = agentName === 'DESIGNER' ? 'DESIGN' : agentName
    setSettingsModalAgent(modalAgentName as 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE')
    setIsSettingsModalOpen(true)
  }, [])

  // Check if a lead is ready to send (has reached designed or completed stage)
  const isLeadReady = useCallback((lead: Lead) => {
    return lead.stage === 'designed' || lead.stage === 'completed'
  }, [])

  // Count ready leads
  const readyLeadsCount = React.useMemo(() => {
    return filteredLeads.filter(isLeadReady).length
  }, [filteredLeads, isLeadReady])

  // Get selected ready leads (only designed/completed)
  const selectedReadyLeads = React.useMemo(() => {
    return filteredLeads.filter(lead => 
      selectedLeads.includes(lead.id) && isLeadReady(lead)
    )
  }, [filteredLeads, selectedLeads, isLeadReady])

  const handleSendEmails = useCallback(async () => {
    if (!campaignObj?.id || readyLeadsCount === 0) {
      return
    }

    if (!confirm(`Send emails to ${readyLeadsCount} ready lead(s)?`)) {
      return
    }

    try {
      setSendingEmails(true)
      const response = await fetch(`/api/v1/campaigns/${campaignObj.id}/send_emails`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        }
      })

      const data = await response.json() as SendEmailsResponse
      if (response.ok && data.success) {
        const sent = data.sent ?? 0
        const failed = data.failed ?? 0
        const errors = Array.isArray(data.errors) ? data.errors : []
        const errorDetails = errors.length > 0
          ? `\n\nErrors:\n${errors.map((e) => `- ${(e.lead_email ?? 'Unknown lead')}: ${e.error ?? 'Unknown error'}`).join('\n')}`
          : ''
        alert(`Emails sent successfully!\nSent: ${sent}\nFailed: ${failed}${errorDetails}`)
        // Refresh leads to get updated status
        await refreshLeads()
        clearSelection()
      } else {
        alert(`Failed to send emails: ${data.error || 'Unknown error'}`)
      }
    } catch (error) {
      console.error('Error sending emails:', error)
      alert(`Error sending emails: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setSendingEmails(false)
    }
  }, [campaignObj, readyLeadsCount, refreshLeads, clearSelection])

  // Send emails to selected leads
  const handleSendSelectedEmails = useCallback(async () => {
    if (selectedReadyLeads.length === 0) {
      alert('Please select at least one lead in "designed" or "completed" stage to send emails.')
      return
    }

    if (!confirm(`Send emails to ${selectedReadyLeads.length} selected lead(s)?`)) {
      return
    }

    try {
      setSendingEmails(true)
      const results = {
        sent: 0,
        failed: 0,
        errors: [] as Array<{ lead_email: string; error: string }>
      }

      // Send emails to each selected lead
      for (const lead of selectedReadyLeads) {
        try {
          const response = await fetch(`/api/v1/leads/${lead.id}/send_email`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
            }
          })

          const data = await response.json()
          if (response.ok && data.success) {
            results.sent += 1
          } else {
            results.failed += 1
            results.errors.push({
              lead_email: lead.email,
              error: data.error || 'Unknown error'
            })
          }
        } catch (error) {
          results.failed += 1
          results.errors.push({
            lead_email: lead.email,
            error: error instanceof Error ? error.message : 'Unknown error'
          })
        }
      }

      const errorDetails = results.errors.length > 0
        ? `\n\nErrors:\n${results.errors.map((e) => `- ${e.lead_email}: ${e.error}`).join('\n')}`
        : ''
      alert(`Emails sent!\nSent: ${results.sent}\nFailed: ${results.failed}${errorDetails}`)
      
      // Refresh leads and clear selection
      await refreshLeads()
      clearSelection()
    } catch (error) {
      console.error('Error sending selected emails:', error)
      alert(`Error sending emails: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setSendingEmails(false)
    }
  }, [selectedReadyLeads, refreshLeads, clearSelection])

  const handleSaveAgentConfig = async (config: AgentConfig) => {
    try {
      if (config.id) {
        // Update existing config
        const success = await updateConfig(config.id, config)
        if (success) {
          // Reload configs to get the latest data
          await loadConfigs()
        } else {
          console.error('Failed to update agent config')
        }
      } else {
        // Create new config if it doesn't exist
        const newConfig = await createConfig(config)
        if (newConfig) {
          // Reload configs to get the latest data
          await loadConfigs()
        } else {
          console.error('Failed to create agent config')
        }
      }
    } catch (error) {
      console.error('Error saving agent config:', error)
    }
  }

  return (
    <>
      <Navigation user={user} />
      <main className="relative overflow-hidden">
        <Background />
        <div className="relative z-10">
        <div className="grid grid-cols-12 h-[calc(100vh-5rem)]">
          <div className="col-span-1 lg:col-span-2 bg-transparent shadow-sm border border-gray-200"></div>

          <div className="col-span-10 lg:col-span-8 bg-transparent shadow-sm border border-gray-200">
            <div className="grid grid-cols-12 h-full">
              <CampaignSidebar
                campaigns={campaigns}
                selectedCampaign={selectedCampaign}
                onCampaignClick={handleCampaignClick}
                onCreateClick={() => setIsFormOpen(true)}
                onEditClick={handleEditClick}
                onDeleteClick={handleDeleteCampaign}
              />

              <div className="col-span-9 bg-transparent">
                <div className="border-b border-gray-200 p-4 py-4">
                  <div className="flex items-center justify-between">
                    {selectedCampaign !== null && (
                      <div className="text-sm sm:text-lg md:text-xl lg:text-2xl xl:text-3xl font-semibold text-gray-900">{displayedTitle}</div>
                    )}

                    <div className="flex space-x-3 ml-auto">
                      {selectedLeads.length > 0 && (
                        <>
                          {selectedLeads.length === 1 && (
                            <button onClick={handleEditSelectedLead} className="p-2 text-gray-400 hover:text-blue-500 transition-colors duration-200">
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-5 h-5">
                                <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125" />
                              </svg>
                            </button>
                          )}
                          <button onClick={handleDeleteSelectedLeads} className="p-2 text-gray-400 hover:text-red-500 transition-colors duration-200">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-5 h-5">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                            </svg>
                          </button>
                        </>
                      )}
                      <button 
                        onClick={handleRunAllAgents}
                        disabled={agentExecLoading || filteredLeads.filter(l => l.stage !== 'completed').length === 0}
                        className="px-3 py-1.5 text-sm font-medium text-white bg-black border border-black rounded-full hover:text-black hover:bg-transparent hover:border-black transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:text-white disabled:hover:bg-black disabled:hover:border-black"
                      >
                        {agentExecLoading ? 'Running...' : 'Run Agents'}
                      </button>
                      {selectedReadyLeads.length > 0 ? (
                        <button 
                          onClick={handleSendSelectedEmails}
                          disabled={sendingEmails || !campaignObj}
                          className="px-3 py-1.5 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-full hover:text-green-600 hover:bg-transparent hover:border-green-600 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:text-white disabled:hover:bg-green-600 disabled:hover:border-green-600"
                          title={`Send emails to ${selectedReadyLeads.length} selected lead(s)`}
                        >
                          {sendingEmails ? 'Sending...' : `Send Selected (${selectedReadyLeads.length})`}
                        </button>
                      ) : (
                        <button 
                          onClick={handleSendEmails}
                          disabled={sendingEmails || !campaignObj || readyLeadsCount === 0}
                          className="px-3 py-1.5 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-full hover:text-green-600 hover:bg-transparent hover:border-green-600 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:text-white disabled:hover:bg-green-600 disabled:hover:border-green-600"
                          title={readyLeadsCount === 0 ? 'No ready leads to send' : `Send emails to ${readyLeadsCount} ready lead(s)`}
                        >
                          {sendingEmails ? 'Sending...' : `Send All${readyLeadsCount > 0 ? ` (${readyLeadsCount})` : ''}`}
                        </button>
                      )}
                      <button 
                        onClick={() => setIsEmailConfigModalOpen(true)}
                        className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-full hover:bg-gray-50 transition-colors duration-200"
                        title="Configure email settings"
                      >
                        Email Settings
                      </button>
                    </div>
                  </div>
                </div>

                <AgentDashboard 
                  hasSelectedCampaign={selectedCampaign !== null} 
                  onAddLeadClick={() => setIsLeadFormOpen(true)}
                  onAgentSettingsClick={handleAgentSettingsClick}
                  leads={filteredLeads}
                />

                <div className="h-full overflow-y-auto">
                  {selectedCampaign !== null ? (
                    <div className="p-4">
                      {filteredLeads.length === 0 ? (
                        <div className="flex items-center justify-center h-64 text-gray-500">
                          <div className="text-center">
                            <p className="text-lg font-medium mb-2">No leads in this campaign</p>
                            <p className="text-sm">
                              Click <span className="text-[#004dff] font-bold">+</span> next to LEADS to add a lead
                            </p>
                          </div>
                        </div>
                      ) : (
                        <ProgressTable 
                          leads={filteredLeads} 
                          onRunLead={handleRunLead} 
                          onLeadClick={handleLeadClick} 
                          onStageClick={handleStageClick}
                          selectedLeads={selectedLeads}
                          onToggleSelection={toggleSelection}
                          onToggleMultiple={toggleMultiple}
                          runningLeadIds={Array.from(runningLeadIds)}
                        />
                      )}
                    </div>
                  ) : (
                    <EmptyState />
                  )}
                </div>
              </div>
            </div>
          </div>

          <div className="col-span-1 lg:col-span-2 bg-transparent shadow-sm border border-gray-200"></div>
        </div>
      </div>

      <CampaignForm isOpen={isFormOpen} onClose={() => setIsFormOpen(false)} onSubmit={handleCreateCampaign} />

      <CampaignForm
        isOpen={isEditFormOpen}
        onClose={() => {
          setIsEditFormOpen(false)
          setEditingCampaign(null)
        }}
        onSubmit={handleEditCampaign}
        initialData={editingCampaign}
        isEdit={true}
      />

      <LeadForm
        isOpen={isLeadFormOpen}
        onClose={() => setIsLeadFormOpen(false)}
        onSubmit={handleCreateLead}
        onBulkSubmit={handleImportLeads}
      />

      <LeadForm
        isOpen={isEditLeadFormOpen}
        onClose={() => {
          setIsEditLeadFormOpen(false)
          setEditingLead(null)
        }}
        onSubmit={handleEditLead}
        initialData={editingLead || undefined}
        isEdit={true}
      />

      <AgentOutputModal
        isOpen={isOutputModalOpen}
        onClose={() => {
          setIsOutputModalOpen(false)
          setOutputModalLead(null)
        }}
        leadName={outputModalLead?.name || ''}
        leadId={outputModalLead?.id}
        outputs={outputs}
        loading={outputsLoading}
        onUpdateOutput={async (leadId, agentName, newContent) => {
          // Update the agent output via API
          const response = await fetch(`/api/v1/leads/${leadId}/update_agent_output`, {
            method: 'PATCH',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
            },
            body: JSON.stringify({
              agentName: agentName,
              content: newContent
            })
          })
          
          if (response.ok) {
            // Reload outputs to show the updated version
            await loadAgentOutputs(leadId)
          } else {
            throw new Error('Failed to update agent output')
          }
        }}
        onUpdateSearchOutput={async (leadId, agentName, updatedData) => {
          // Update the search agent output via API
          const response = await fetch(`/api/v1/leads/${leadId}/update_agent_output`, {
            method: 'PATCH',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
            },
            body: JSON.stringify({
              agentName: agentName,
              updatedData: updatedData
            })
          })
          
          if (response.ok) {
            // Don't reload outputs - the local state in AgentOutputModal is already updated
            // Reloading would cause the modal to flicker. The local state is the source of truth.
            // Only reload if there's an error or when the modal is closed/reopened
          } else {
            throw new Error('Failed to update agent output')
          }
        }}
      />

      {settingsModalAgent && (
        <AgentSettingsModal
          isOpen={isSettingsModalOpen}
          onClose={() => {
            setIsSettingsModalOpen(false)
            setSettingsModalAgent(null)
          }}
          agentName={settingsModalAgent}
          config={configs.find(c => c.agentName === settingsModalAgent) || null}
          sharedSettings={campaignObj?.sharedSettings}
          onSave={handleSaveAgentConfig}
          loading={configsLoading}
        />
      )}

      <EmailConfigModal
        isOpen={isEmailConfigModalOpen}
        onClose={() => setIsEmailConfigModalOpen(false)}
      />
      </main>
    </>
  )
}


