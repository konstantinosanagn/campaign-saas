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

export default function CampaignDashboard() {
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

  const { campaigns, createCampaign, updateCampaign, deleteCampaign } = useCampaigns()
  const { leads, createLead, updateLead, deleteLeads, findLead, refreshLeads } = useLeads()
  const { selectedIds: selectedLeads, toggleSelection, clearSelection } = useSelection()

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

  const { loading: agentExecLoading, runAgentsForLead, runAgentsForMultipleLeads } = useAgentExecution()
  const [runningLeadIds, setRunningLeadIds] = React.useState<Set<number>>(new Set())
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

  const handleLeadClick = useCallback((lead: { id: number }) => {
    toggleSelection(lead.id)
  }, [toggleSelection])

  const handleEditSelectedLead = () => {
    if (selectedLeads.length === 1) {
      const lead = findLead(selectedLeads[0])
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
    setRunningLeadIds(prev => new Set(prev).add(leadId))
    try {
      console.log('Running agents for lead:', leadId)
      const result = await runAgentsForLead(leadId)
      console.log('Agent execution result:', result)
      
      if (result) {
        // Check if there were any errors in the response
        if (result.status === 'failed' && result.error) {
          alert(`Failed to run agents: ${result.error}`)
          console.error('Agent execution failed:', result.error)
        } else if (result.failedAgents && result.failedAgents.length > 0) {
          alert(`Some agents failed: ${result.failedAgents.join(', ')}`)
          console.error('Some agents failed:', result.failedAgents)
        } else {
          console.log('Agents executed successfully:', result.completedAgents)
        }
        // Refresh leads to get updated stage/quality
        await refreshLeads()
      } else {
        // If result is null, there was an error in the API call
        const errorMsg = 'Failed to run agents. Please check the console for details.'
        alert(errorMsg)
        console.error('Agent execution returned null - check API response')
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
      alert(`Error running agents: ${errorMessage}`)
      console.error('Exception in handleRunLead:', err)
    } finally {
      setRunningLeadIds(prev => {
        const next = new Set(prev)
        next.delete(leadId)
        return next
      })
    }
  }, [runAgentsForLead, refreshLeads])

  const handleStageClick = useCallback(async (lead: Lead) => {
    setOutputModalLead(lead)
    setIsOutputModalOpen(true)
    await loadAgentOutputs(lead.id)
  }, [loadAgentOutputs])

  const handleRunAllAgents = useCallback(async () => {
    if (!filteredLeads.length) return
    
    // Run agents for all leads that aren't in completed stage
    const leadsToRun = filteredLeads.filter(l => l.stage !== 'completed').map(l => l.id)
    
    if (leadsToRun.length > 0) {
      setRunningLeadIds(prev => {
        const next = new Set(prev)
        leadsToRun.forEach(id => next.add(id))
        return next
      })
      try {
        await runAgentsForMultipleLeads(leadsToRun)
        await refreshLeads()
      } finally {
        setRunningLeadIds(prev => {
          const next = new Set(prev)
          leadsToRun.forEach(id => next.delete(id))
          return next
        })
      }
    }
  }, [filteredLeads, runAgentsForMultipleLeads, refreshLeads])

  const handleAgentSettingsClick = useCallback((agentName: 'SEARCH' | 'WRITER' | 'DESIGNER' | 'CRITIQUE') => {
    console.log('handleAgentSettingsClick called with:', agentName)
    // Map 'DESIGNER' to 'DESIGN' for the modal
    const modalAgentName = agentName === 'DESIGNER' ? 'DESIGN' : agentName
    setSettingsModalAgent(modalAgentName as 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE')
    setIsSettingsModalOpen(true)
  }, [])

  // Check if a lead is ready to send (has reached critiqued or completed stage)
  const isLeadReady = useCallback((lead: Lead) => {
    return lead.stage === 'critiqued' || lead.stage === 'completed'
  }, [])

  // Count ready leads
  const readyLeadsCount = React.useMemo(() => {
    return filteredLeads.filter(isLeadReady).length
  }, [filteredLeads, isLeadReady])

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
      } else {
        alert(`Failed to send emails: ${data.error || 'Unknown error'}`)
      }
    } catch (error) {
      console.error('Error sending emails:', error)
      alert(`Error sending emails: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setSendingEmails(false)
    }
  }, [campaignObj, readyLeadsCount, refreshLeads])

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
      <Navigation />
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
                        className="px-3 py-1.5 text-sm font-medium text-white bg-black border border-black rounded-full hover:text-black hover:bg-transparent hover:border-black transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {agentExecLoading ? 'Running...' : 'Run Agents'}
                      </button>
                      <button 
                        onClick={handleSendEmails}
                        disabled={sendingEmails || !campaignObj || readyLeadsCount === 0}
                        className="px-3 py-1.5 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-full hover:text-green-600 hover:bg-transparent hover:border-green-600 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                        title={readyLeadsCount === 0 ? 'No ready leads to send' : `Send emails to ${readyLeadsCount} ready lead(s)`}
                      >
                        {sendingEmails ? 'Sending...' : `Send${readyLeadsCount > 0 ? ` (${readyLeadsCount})` : ''}`}
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

                <div className="h-full">
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
      </main>
    </>
  )
}


