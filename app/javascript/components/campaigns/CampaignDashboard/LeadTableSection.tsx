import React from 'react'
import ProgressTable from '@/components/leads/ProgressTable'
import type { Lead, AgentConfig } from '@/types'

interface LeadTableSectionProps {
  selectedCampaign: number | null
  filteredLeads: Lead[]
  selectedLeads: number[]
  runningLeadIds: number[]
  onRunLead: (leadId: number) => void
  onSendEmail?: (leadId: number) => void
  onLeadClick: (lead: Lead) => void
  onStageClick: (lead: Lead) => void
  onToggleSelection: (leadId: number) => void
  onToggleMultiple: (startIndex: number, endIndex: number) => void
  sendingEmails?: boolean
  sendingLeadId?: number | null
  agentConfigs?: AgentConfig[]
}

export default function LeadTableSection({
  selectedCampaign,
  filteredLeads,
  selectedLeads,
  runningLeadIds,
  onRunLead,
  onSendEmail,
  onLeadClick,
  onStageClick,
  onToggleSelection,
  onToggleMultiple,
  sendingEmails,
  sendingLeadId,
  agentConfigs,
}: LeadTableSectionProps) {
  if (selectedCampaign === null) {
    return null
  }

  if (filteredLeads.length === 0) {
    return (
      <div className="p-4">
        <div className="flex items-center justify-center h-64 text-gray-500">
          <div className="text-center">
            <p className="text-lg font-medium mb-2">No leads in this campaign</p>
            <p className="text-sm">
              Click <span className="text-[#004dff] font-bold">+</span> next to LEADS to add a lead
            </p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="p-4">
      <ProgressTable
        leads={filteredLeads}
        onRunLead={onRunLead}
        onSendEmail={onSendEmail}
        onLeadClick={onLeadClick}
        onStageClick={onStageClick}
        selectedLeads={selectedLeads}
        onToggleSelection={onToggleSelection}
        onToggleMultiple={onToggleMultiple}
        runningLeadIds={runningLeadIds}
        sendingEmails={sendingEmails}
        sendingLeadId={sendingLeadId}
        agentConfigs={agentConfigs}
      />
    </div>
  )
}
