'use client'

import React from 'react'
import type { Lead, AgentConfig } from '@/types'
import Cube from '@/components/shared/Cube'
import ScoreGauge from '@/components/shared/ScoreGauge'
import { baseAgents } from '@/libs/constants/agents'

interface ProgressTableProps {
  leads: Lead[]
  onRunLead: (leadId: number, agentName?: string) => void
  onSendEmail?: (leadId: number) => void
  onLeadClick: (lead: Lead) => void
  onStageClick: (lead: Lead) => void
  selectedLeads: number[]
  onToggleSelection?: (leadId: number) => void
  onToggleMultiple?: (ids: number[], shouldSelect: boolean) => void
  runningLeadIds?: number[]
  sendingEmails?: boolean
  sendingLeadId?: number | null
  agentConfigs?: AgentConfig[]
}

function ProgressTable({ leads, onRunLead, onSendEmail, onLeadClick, onStageClick, selectedLeads, onToggleSelection, onToggleMultiple, runningLeadIds = [], sendingEmails = false, sendingLeadId = null, agentConfigs = [] }: ProgressTableProps) {
  
  // Helper functions to check stage status
  const isSentStage = (stage?: string): boolean => {
    return stage === 'sent' || (stage?.startsWith('sent (') ?? false)
  }

  const isFailedStage = (stage?: string): boolean => {
    return stage === 'send_failed' || stage === 'failed'
  }

  // Check if a lead can be sent via email (designed/completed stage, or critiqued if DESIGN is disabled)
  // Note: All leads can be selected, but only ready leads can be sent emails
  // Also checks that critique score meets minimum threshold if critique has been run
  // Allows resend/retry for already sent/failed emails (even if no active run due to auto-heal)
  const canSendEmail = (lead: Lead): boolean => {
    // Check if critique score meets minimum (if critique has been run)
    // If meetsMinScore is explicitly false, don't allow sending
    if (lead.meetsMinScore === false) {
      return false
    }

    // Normal "ready to send" case from backend
    if (lead.leadRun?.canSend === true) return true

    // Resend/retry case (no active run because of auto-heal)
    if (isSentStage(lead.stage) || isFailedStage(lead.stage)) return true

    // Fallback (if backend uses email_status instead of stage)
    if (lead.email_status === 'sent' || lead.email_status === 'failed') return true

    return false
  }

  // Check if email is currently being sent (SENDER step is running)
  const isSendingEmail = (lead: Lead): boolean => {
    const run = lead.leadRun
    if (!run) return false
    
    // Check if running step is SENDER
    if (run.runningStep?.agentName === 'SENDER') {
      return true
    }
    
    // Check if next step is SENDER and it's queued/running
    if (run.nextStep?.agentName === 'SENDER') {
      // If there's a running step that's not SENDER, email is not sending yet
      if (run.runningStep && run.runningStep.agentName !== 'SENDER') {
        return false
      }
      // If run status is running and next step is SENDER, it might be queued
      // We'll show sending state once the step actually starts running
      return false
    }
    
    return false
  }

  // Get email sending status for display
  const getEmailSendingStatus = (lead: Lead): 'idle' | 'queued' | 'sending' | 'retrying' | 'sent' | 'failed' => {
    // Check email_status first (most accurate for current state)
    if (lead.email_status === 'queued' || lead.email_status === 'sending') {
      return 'sending'
    }
    
    if (lead.email_status === 'retrying') {
      return 'retrying'
    }
    
    if (lead.email_status === 'sent') {
      return 'sent'
    }
    
    if (lead.email_status === 'failed') {
      return 'failed'
    }
    
    // Fallback to isSendingEmail check (for active runs)
    if (isSendingEmail(lead)) {
      return 'sending'
    }
    
    // Check stage for sent status
    if (lead.stage?.startsWith('sent (')) {
      return 'sent'
    }
    
    if (lead.stage === 'send_failed') {
      return 'failed'
    }
    
    return 'idle'
  }

  // Check if an agent is enabled
  const isAgentEnabled = (agentName: string): boolean => {
    // Map agent names: DESIGN -> DESIGN, DESIGNER -> DESIGN (for config lookup)
    const configAgentName = agentName === 'DESIGNER' ? 'DESIGN' : agentName
    const config = agentConfigs.find(c => c.agentName === configAgentName)
    // If no config exists, assume enabled (default behavior)
    return config ? config.enabled : true
  }

  // Determine next agent based on stage
  const getNextAgent = (stage: string): string | null => {
    // Handle rewritten stages - at "rewritten (N)" we could be waiting for WRITER or CRITIQUE
    // Default to CRITIQUE (most common case after rewrite WRITER completes)
    if (stage?.startsWith('rewritten')) {
      return 'CRITIQUE'
    }
    
    switch (stage) {
      case 'queued':
        return 'SEARCH'
      case 'searched':
        return 'WRITER'
      case 'written':
        return 'CRITIQUE'
      case 'critiqued':
        return 'DESIGN'
      case 'designed':
        return 'SENDER'
      case 'completed':
        return 'SENDER'
      default:
        return null
    }
  }

  // Find next enabled agent, skipping disabled ones
  const getNextEnabledAgent = (stage: string): string | null => {
    const agentOrder = ['SEARCH', 'WRITER', 'CRITIQUE', 'DESIGN', 'SENDER']
    const nextAgent = getNextAgent(stage)
    
    if (!nextAgent) return null
    
    // SENDER is always available (no config needed)
    if (nextAgent === 'SENDER') return 'SENDER'
    
    // Check if the next agent is enabled
    if (isAgentEnabled(nextAgent)) {
      return nextAgent
    }
    
    // If disabled, find the next enabled agent in the sequence
    const currentIndex = agentOrder.indexOf(nextAgent)
    if (currentIndex === -1) return null
    
    for (let i = currentIndex + 1; i < agentOrder.length; i++) {
      const agent = agentOrder[i]
      if (agent === 'SENDER') return 'SENDER' // SENDER is always available
      if (isAgentEnabled(agent)) {
        return agent
      }
    }
    
    // If no enabled agent found, return SENDER if we're at designed/completed/sent stages
    // Also return SENDER if at critiqued stage but DESIGN is disabled
    // Note: sent (n) stages are already sent, so don't return SENDER for those
    if (stage === 'designed' || stage === 'completed') {
      return 'SENDER'
    }
    
    // Don't return SENDER for already-sent stages
    if (stage?.startsWith('sent (') || stage === 'send_failed') {
      return null
    }
    
    // Special case: critiqued stage but DESIGN is disabled
    if (stage === 'critiqued') {
      const designConfig = agentConfigs?.find(c => c.agentName === 'DESIGN')
      if (designConfig && !designConfig.enabled) {
        return 'SENDER'
      }
    }
    
    return null
  }

  // Get icon for next agent
  // Uses availableActions from backend if available, otherwise falls back to stage-based logic
  const getNextAgentIcon = (lead: Lead): { icon: string; agentName: string } | null => {
    // Check if lead has availableActions from backend (preferred)
    let nextAgent: string | null = null
    
    if (lead.availableActions && lead.availableActions.length > 0) {
      // Use first available action from backend
      nextAgent = lead.availableActions[0]
    } else {
      // Fallback to stage-based determination
      nextAgent = getNextEnabledAgent(lead.stage)
    }
    
    // Special case: If canSendEmail is true but getNextEnabledAgent returned null
    // (e.g., for sent/failed stages with no active run), return SENDER icon
    if (!nextAgent && canSendEmail(lead)) {
      nextAgent = 'SENDER'
    }
    
    if (!nextAgent) return null
    
    // Map DESIGN to DESIGNER for baseAgents lookup
    const agentNameForLookup = nextAgent === 'DESIGN' ? 'DESIGNER' : nextAgent
    const agent = baseAgents.find(a => a.name === agentNameForLookup)
    
    if (agent) {
      return { icon: agent.icon, agentName: nextAgent }
    }
    
    return null
  }

  // Handle action button click
  const handleActionClick = (lead: Lead) => {
    if (canSendEmail(lead) && onSendEmail) {
      onSendEmail(lead.id)
    } else {
      // Get the agent name from the icon to pass to the run function
      const agentIcon = getNextAgentIcon(lead)
      const agentName = agentIcon?.agentName
      onRunLead(lead.id, agentName)
    }
  }
  
  return (
    <div 
      className="rounded-2xl overflow-hidden"
      style={{
        background: 'rgba(255, 255, 255, 0.36)',
        borderRadius: '16px',
        boxShadow: '0 4px 30px rgba(0, 0, 0, 0.1)',
        backdropFilter: 'blur(6.7px)',
        WebkitBackdropFilter: 'blur(6.7px)',
        border: '1px solid rgba(255, 255, 255, 1)'
      }}
    >
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="border-b border-blue-500 bg-gray-50">
              {onToggleSelection && (() => {
                // Allow selection of all leads
                const allLeadIds = leads.map(lead => lead.id)
                const allSelected = leads.length > 0 && leads.every(lead => selectedLeads.includes(lead.id))
                const someSelected = leads.some(lead => selectedLeads.includes(lead.id))
                
                return (
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-900 w-12">
                    <input
                      type="checkbox"
                      checked={allSelected}
                      ref={(input) => {
                        if (input) {
                          input.indeterminate = someSelected && !allSelected
                        }
                      }}
                      onChange={(e) => {
                        e.stopPropagation()
                        const shouldSelectAll = !allSelected
                        if (onToggleMultiple) {
                          // Use bulk toggle if available (more efficient)
                          onToggleMultiple(allLeadIds, shouldSelectAll)
                        } else if (onToggleSelection) {
                          // Fallback to individual toggles
                          leads.forEach((lead) => {
                            const isCurrentlySelected = selectedLeads.includes(lead.id)
                            // Only toggle if the lead's state doesn't match what we want
                            if (shouldSelectAll !== isCurrentlySelected) {
                              onToggleSelection(lead.id)
                            }
                          })
                        }
                      }}
                      onClick={(e) => {
                        e.stopPropagation()
                      }}
                      className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500 focus:ring-2 focus:ring-offset-0 cursor-pointer"
                      style={{ borderColor: allSelected ? '#2563eb' : '#d1d5db' }}
                      title="Select all leads"
                    />
                  </th>
                )
              })()}
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Lead</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Company</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Stage</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Quality</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody>
            {leads.map((lead) => {
              const isSelected = selectedLeads.includes(lead.id)
              const canSend = canSendEmail(lead)
              const isSending = isSendingEmail(lead)
              const emailStatus = getEmailSendingStatus(lead)
              const isDisabled = isSending || emailStatus === 'queued' || emailStatus === 'sending' || emailStatus === 'retrying'
              
              return (
              <tr 
                key={lead.id} 
                className={`border-b border-gray-200 hover:bg-blue-100 transition-colors duration-200 ${isSelected ? 'bg-blue-50' : ''}`}
              >
                {onToggleSelection && (
                  <td 
                    className="px-4 py-3" 
                    onClick={(e) => {
                      e.stopPropagation()
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onClick={(e) => {
                        e.stopPropagation()
                      }}
                      onChange={(e) => {
                        e.stopPropagation()
                        if (onToggleSelection) {
                          onToggleSelection(lead.id)
                        }
                      }}
                      className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500 focus:ring-2 focus:ring-offset-0 cursor-pointer"
                      style={{ borderColor: isSelected ? '#2563eb' : '#d1d5db' }}
                      title={canSend ? "Select lead (ready for email sending)" : "Select lead (must reach 'designed' or 'completed' stage to send email)"}
                    />
                  </td>
                )}
                <td className="px-4 py-3 cursor-pointer" onClick={() => onLeadClick(lead)}>
                  <div>
                    <div className={`font-medium ${selectedLeads.includes(lead.id) ? 'text-blue-600' : 'text-gray-900'}`}>{lead.name}</div>
                    <div className="text-sm text-gray-500">{lead.email} · {lead.title}</div>
                  </div>
                </td>
                <td className="px-4 py-3 cursor-pointer" onClick={() => onLeadClick(lead)}>
                  <div>
                    <div className={`font-medium ${selectedLeads.includes(lead.id) ? 'text-blue-600' : 'text-gray-900'}`}>{lead.company}</div>
                    <div className="text-sm text-gray-500">({lead.website})</div>
                  </div>
                </td>
                <td className="px-4 py-3">
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      onStageClick(lead)
                    }}
                    className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 hover:bg-blue-200 hover:text-blue-900 cursor-pointer transition-colors duration-200"
                  >
                    {lead.stage ? lead.stage.charAt(0).toUpperCase() + lead.stage.slice(1) : lead.stage}
                  </button>
                </td>
                <td className="px-4 py-3">
                  <ScoreGauge score={lead.score} size="small" />
                </td>
                <td className="px-4 py-3">
                  {runningLeadIds.includes(lead.id) || sendingLeadId === lead.id || isSending ? (
                    <div className="inline-flex items-center justify-center w-8 h-8" title={isSending ? "Sending email..." : "Processing..."}>
                      <Cube variant="black" size="small" />
                    </div>
                  ) : (() => {
                    const nextAgentIcon = getNextAgentIcon(lead)
                    if (!nextAgentIcon) {
                      return null // No next agent available
                    }
                    
                    // Determine action title and disabled state
                    let actionTitle = canSend 
                      ? "Send email" 
                      : `Run ${nextAgentIcon.agentName} agent`
                    
                    // Add helpful tooltip when send is disabled
                    if (canSend && isDisabled) {
                      if (emailStatus === 'queued' || emailStatus === 'sending') {
                        actionTitle = "Email is being sent..."
                      } else if (emailStatus === 'retrying') {
                        actionTitle = "Retrying email send..."
                      } else if (emailStatus === 'sent') {
                        actionTitle = "Resend email"
                      } else if (emailStatus === 'failed') {
                        actionTitle = "Retry sending email"
                      }
                    } else if (!canSend && lead.leadRun?.nextStep) {
                      actionTitle = `Next step: ${lead.leadRun.nextStep.agentName}. Complete previous steps to send email.`
                    } else if (canSend && (isSentStage(lead.stage) || isFailedStage(lead.stage))) {
                      // Show resend/retry tooltip for sent/failed emails that can be resent
                      if (isSentStage(lead.stage)) {
                        actionTitle = "Resend email"
                      } else if (isFailedStage(lead.stage)) {
                        actionTitle = "Retry sending email"
                      }
                    }
                    
                    return (
                      <button
                        onClick={() => handleActionClick(lead)}
                        disabled={sendingEmails || sendingLeadId === lead.id || isDisabled}
                        className="inline-flex items-center justify-center w-8 h-8 rounded-md text-gray-600 hover:text-black hover:bg-transparent transition-colors duration-200 group disabled:opacity-50 disabled:cursor-not-allowed"
                        title={actionTitle}
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6 group-hover:fill-black transition-all duration-300 ease-in-out">
                          <path strokeLinecap="round" strokeLinejoin="round" d={nextAgentIcon.icon} />
                        </svg>
                      </button>
                    )
                  })()}
                </td>
              </tr>
            )})}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default React.memo(ProgressTable)


