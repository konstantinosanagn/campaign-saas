import React, { useState, useCallback, useMemo } from 'react'
import Navigation from '@/components/shared/Navigation'
import Background from '@/components/shared/Background'
import CampaignForm from '@/components/campaigns/CampaignForm'
import CampaignSidebar from '@/components/campaigns/CampaignSidebar'
import LeadForm from '@/components/leads/LeadForm'
import AgentDashboard from '@/components/agents/AgentDashboard'
import EmptyState from '@/components/shared/EmptyState'
import AgentOutputModal from '@/components/agents/AgentOutputModal'
import AgentSettingsModal from '@/components/agents/AgentSettingsModal'
import EmailConfigModal from '@/components/shared/EmailConfigModal'
import ActionBar from './ActionBar'
import LeadTableSection from './LeadTableSection'
import { useCampaigns } from '@/hooks/useCampaigns'
import { useLeads } from '@/hooks/useLeads'
import { useSelection } from '@/hooks/useSelection'
import { useTypewriter } from '@/hooks/useTypewriter'
import { useAgentOutputs } from '@/hooks/useAgentOutputs'
import { useAgentConfigs } from '@/hooks/useAgentConfigs'
import { useAgentActions } from './useAgentActions'
import { useEmailActions } from './useEmailActions'
import type { Lead, AgentConfig } from '@/types'

interface CampaignDashboardProps {
  user?: {
    first_name?: string | null
    last_name?: string | null
    name?: string | null
    workspace_name?: string | null
    job_title?: string | null
    gmail_email?: string | null
    can_send_gmail?: boolean
  }
  defaultGmailSenderAvailable?: boolean
  defaultGmailSenderEmail?: string | null
}

export default function CampaignDashboard({ 
  user, 
  defaultGmailSenderAvailable = false, 
  defaultGmailSenderEmail = null 
}: CampaignDashboardProps = {}) {
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [isEditFormOpen, setIsEditFormOpen] = useState(false)
  const [isLeadFormOpen, setIsLeadFormOpen] = useState(false)
  const [isEditLeadFormOpen, setIsEditLeadFormOpen] = useState(false)

  const [editingCampaign, setEditingCampaign] = useState<{
    index: number
    title: string
    productInfo?: string
    senderCompany?: string
    tone?: string
    persona?: string
    primaryGoal?: string
  } | null>(null)
  const [editingLead, setEditingLead] = useState<{
    id: number
    name: string
    email: string
    title: string
    company: string
  } | null>(null)

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
  const findLeadById = useCallback(
    (leadId: number) => leads.find((lead) => lead.id === leadId),
    [leads]
  )
  const { selectedIds: selectedLeads, toggleSelection, toggleMultiple, clearSelection } = useSelection()

  // Auto-select newly created campaign
  React.useEffect(() => {
    if (pendingCampaignId !== null) {
      const index = campaigns.findIndex((c) => c.id === pendingCampaignId)
      if (index !== -1) {
        setSelectedCampaign(index)
        setPendingCampaignId(null)
      }
    }
  }, [campaigns, pendingCampaignId])

  const campaignObj =
    selectedCampaign !== null && campaigns[selectedCampaign]
      ? campaigns[selectedCampaign]
      : null

  // Agent actions hook
  const { agentExecLoading, runningLeadIds, handleRunLead, handleRunAllAgents } = useAgentActions(
    findLeadById,
    refreshLeads
  )

  // Filter leads by selected campaign
  const filteredLeads = useMemo(() => {
    if (selectedCampaign === null || !campaignObj?.id) {
      return []
    }
    return leads.filter((lead) => lead.campaignId === campaignObj.id)
  }, [leads, selectedCampaign, campaignObj])

  // Ready leads calculation
  // A lead is ready if it's at designed/completed stage, or critiqued stage with DESIGN disabled
  const isLeadReady = useCallback((lead: Lead) => {
    // Normal case: designed or completed stage
    if (lead.stage === 'designed' || lead.stage === 'completed') {
      return true
    }
    
    // Special case: critiqued stage but DESIGN agent is disabled
    if (lead.stage === 'critiqued') {
      const designConfig = configs.find(c => c.agentName === 'DESIGN')
      if (designConfig && !designConfig.enabled) {
        return true
      }
    }
    
    return false
  }, [configs])

  const readyLeadsCount = useMemo(() => {
    return filteredLeads.filter(isLeadReady).length
  }, [filteredLeads, isLeadReady])

  const selectedReadyLeads = useMemo(() => {
    return filteredLeads.filter(
      (lead) => selectedLeads.includes(lead.id) && isLeadReady(lead)
    )
  }, [filteredLeads, selectedLeads, isLeadReady])

  // Email actions hook
  const { sendingEmails, sendingLeadId, handleSendEmails, handleSendSelectedEmails, handleSendSingleEmail } = useEmailActions(
    campaignObj,
    readyLeadsCount,
    selectedReadyLeads,
    refreshLeads,
    clearSelection
  )

  const campaignTitle = campaignObj ? campaignObj.title || '' : ''
  const displayedTitle = useTypewriter(campaignTitle)

  const { loading: outputsLoading, outputs, loadAgentOutputs } = useAgentOutputs()
  const { configs, loading: configsLoading, updateConfig, createConfig, loadConfigs } = useAgentConfigs(
    campaignObj?.id || null
  )

  // Campaign handlers
  const handleCampaignClick = (campaignIndex: number) => {
    if (selectedCampaign === campaignIndex) {
      setSelectedCampaign(null)
    } else {
      setSelectedCampaign(campaignIndex)
    }
  }

  const handleCreateCampaign = async (data: {
    title: string
    productInfo?: string
    senderCompany?: string
    tone?: string
    persona?: string
    primaryGoal?: string
  }) => {
    const newCampaign = await createCampaign(data)
    if (newCampaign && newCampaign.id) {
      setPendingCampaignId(newCampaign.id)
    }
  }

  const handleEditCampaign = (data: {
    title: string
    productInfo?: string
    senderCompany?: string
    tone?: string
    persona?: string
    primaryGoal?: string
  }) => {
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
      primaryGoal: campaign.sharedSettings?.primary_goal,
    })
    setIsEditFormOpen(true)
  }

  const handleDeleteCampaign = async (index: number) => {
    const success = await deleteCampaign(index)
    if (success) {
      if (selectedCampaign === index) {
        setSelectedCampaign(null)
      } else if (selectedCampaign !== null && selectedCampaign > index) {
        setSelectedCampaign(selectedCampaign - 1)
      }
      clearSelection()
    }
  }

  // Lead handlers
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

  const handleImportLeads = useCallback(
    async (rows: Array<{ firstName: string; lastName: string; email: string; title: string; company: string }>) => {
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
    },
    [campaignObj, createLead, refreshLeads, selectedCampaign]
  )

  const handleLeadClick = useCallback(
    (lead: Lead) => {
      toggleSelection(lead.id)
    },
    [toggleSelection]
  )

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

  // Agent handlers
  const handleRunLeadWrapper = useCallback(
    async (leadId: number) => {
      await handleRunLead(leadId, () => findLeadById(leadId))
    },
    [handleRunLead, findLeadById]
  )

  const handleRunAllAgentsWrapper = useCallback(() => {
    // If leads are selected, run agents only for selected leads
    // Otherwise, run for all leads
    handleRunAllAgents(filteredLeads, findLeadById, selectedLeads.length > 0 ? selectedLeads : undefined)
  }, [handleRunAllAgents, filteredLeads, findLeadById, selectedLeads])

  const handleStageClick = useCallback(
    async (lead: Lead) => {
      setOutputModalLead(lead)
      setIsOutputModalOpen(true)
      await loadAgentOutputs(lead.id)
    },
    [loadAgentOutputs]
  )

  const handleAgentSettingsClick = useCallback((agentName: 'SEARCH' | 'WRITER' | 'DESIGNER' | 'CRITIQUE') => {
    console.log('handleAgentSettingsClick called with:', agentName)
    const modalAgentName = agentName === 'DESIGNER' ? 'DESIGN' : agentName
    setSettingsModalAgent(modalAgentName as 'SEARCH' | 'WRITER' | 'DESIGN' | 'CRITIQUE')
    setIsSettingsModalOpen(true)
  }, [])

  const handleSaveAgentConfig = async (config: AgentConfig) => {
    try {
      if (config.id) {
        const success = await updateConfig(config.id, config)
        if (success) {
          await loadConfigs()
        } else {
          console.error('Failed to update agent config')
        }
      } else {
        const newConfig = await createConfig(config)
        if (newConfig) {
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
      <Navigation 
        user={user} 
        defaultGmailSenderAvailable={defaultGmailSenderAvailable}
        defaultGmailSenderEmail={defaultGmailSenderEmail}
      />
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
                  {selectedCampaign !== null && (
                    <div className="border-b border-gray-200 p-4 py-4">
                      <div className="text-sm sm:text-lg md:text-xl lg:text-2xl xl:text-3xl font-semibold text-gray-900">
                        {displayedTitle}
                      </div>
                    </div>
                  )}

                  <ActionBar
                    selectedLeads={selectedLeads}
                    readyLeadsCount={readyLeadsCount}
                    selectedReadyLeads={selectedReadyLeads}
                    sendingEmails={sendingEmails}
                    agentExecLoading={agentExecLoading}
                    runningLeadIds={runningLeadIds}
                    filteredLeads={filteredLeads}
                    campaignObj={campaignObj}
                    user={user}
                    defaultGmailSenderAvailable={defaultGmailSenderAvailable}
                    defaultGmailSenderEmail={defaultGmailSenderEmail}
                    onEditSelectedLead={handleEditSelectedLead}
                    onDeleteSelectedLeads={handleDeleteSelectedLeads}
                    onRunAllAgents={handleRunAllAgentsWrapper}
                    onSendEmails={handleSendEmails}
                    onSendSelectedEmails={handleSendSelectedEmails}
                    onEmailConfigClick={() => setIsEmailConfigModalOpen(true)}
                  />

                  <AgentDashboard
                    hasSelectedCampaign={selectedCampaign !== null}
                    onAddLeadClick={() => setIsLeadFormOpen(true)}
                    onAgentSettingsClick={handleAgentSettingsClick}
                    leads={filteredLeads}
                  />

                  <div className="h-full overflow-y-auto">
                    {selectedCampaign !== null ? (
                      <LeadTableSection
                        selectedCampaign={selectedCampaign}
                        filteredLeads={filteredLeads}
                        selectedLeads={selectedLeads}
                        runningLeadIds={runningLeadIds}
                        onRunLead={handleRunLeadWrapper}
                        onSendEmail={handleSendSingleEmail}
                        onLeadClick={handleLeadClick}
                        onStageClick={handleStageClick}
                        onToggleSelection={toggleSelection}
                        onToggleMultiple={toggleMultiple}
                        sendingEmails={sendingEmails}
                        sendingLeadId={sendingLeadId}
                        agentConfigs={configs}
                      />
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
            const response = await fetch(`/api/v1/leads/${leadId}/update_agent_output`, {
              method: 'PATCH',
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
              },
              body: JSON.stringify({
                agentName: agentName,
                content: newContent,
              }),
            })

            if (response.ok) {
              await loadAgentOutputs(leadId)
            } else {
              throw new Error('Failed to update agent output')
            }
          }}
          onUpdateSearchOutput={async (leadId, agentName, updatedData) => {
            const response = await fetch(`/api/v1/leads/${leadId}/update_agent_output`, {
              method: 'PATCH',
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
              },
              body: JSON.stringify({
                agentName: agentName,
                updatedData: updatedData,
              }),
            })

            if (!response.ok) {
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
            config={configs.find((c) => c.agentName === settingsModalAgent) || null}
            sharedSettings={campaignObj?.sharedSettings}
            onSave={handleSaveAgentConfig}
            loading={configsLoading}
          />
        )}

        <EmailConfigModal isOpen={isEmailConfigModalOpen} onClose={() => setIsEmailConfigModalOpen(false)} />
      </main>
    </>
  )
}
