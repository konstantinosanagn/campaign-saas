'use client'

import { baseAgents } from '@/libs/constants/agents'
import type { Lead } from '@/types'

type ConfigurableAgentName = 'SEARCH' | 'WRITER' | 'DESIGNER' | 'CRITIQUE'

interface AgentDashboardProps {
  hasSelectedCampaign: boolean
  onAddLeadClick: () => void
  onAgentSettingsClick?: (agentName: ConfigurableAgentName) => void
  leads: Lead[]
}

export default function AgentDashboard({ hasSelectedCampaign, onAddLeadClick, onAgentSettingsClick, leads }: AgentDashboardProps) {
  type AgentWithOnClick = (typeof baseAgents)[number] & { onClick?: () => void }

  const agents: AgentWithOnClick[] = baseAgents.map((a) => {
    if (a.name === 'LEADS') {
      return { ...a, onClick: onAddLeadClick }
    }
    if (a.name === 'SEARCH' || a.name === 'WRITER' || a.name === 'DESIGNER' || a.name === 'CRITIQUE') {
      const agentName = a.name as ConfigurableAgentName
      return { ...a, onClick: () => {
        console.log('Agent clicked:', agentName)
        onAgentSettingsClick?.(agentName)
      }}
    }
    return a
  })

  // Calculate stats from leads based on their current stage
  // Each lead should only count in ONE agent at a time based on its current stage
  const getAgentStat = (agentName: string): string => {
    if (!hasSelectedCampaign || leads.length === 0) {
      return '-'
    }

    switch (agentName) {
      case 'LEADS':
        return leads.length.toString()
      case 'SEARCH':
        // Count leads currently in 'searched' stage (just completed SEARCH)
        return leads.filter(l => l.stage === 'searched').length.toString()
      case 'WRITER':
        // Count leads currently in 'written' stage (just completed WRITER)
        return leads.filter(l => l.stage === 'written').length.toString()
      case 'DESIGNER':
        // Count leads currently in 'designed' stage (just completed DESIGN)
        return leads.filter(l => l.stage === 'designed').length.toString()
      case 'CRITIQUE':
        // Count leads currently in 'critiqued' stage (just completed CRITIQUE)
        return leads.filter(l => l.stage === 'critiqued').length.toString()
      case 'SENDER':
        // Count leads in sent stages (sent (1), sent (2), etc.) or send_failed
        return leads.filter(l => 
          l.stage?.startsWith('sent (') || 
          l.stage === 'send_failed' ||
          l.stage === 'completed' // Legacy support
        ).length.toString()
      default:
        return '-'
    }
  }

  return (
    <div className="border-b border-gray-200">
      <div className="grid grid-cols-8">
        <div className="border-r border-gray-200 py-4 px-4"></div>

        {agents.map((agent) => (
          <div key={agent.name} className="text-left border-r border-gray-200 py-4 px-2 overflow-hidden">
            {hasSelectedCampaign && agent.clickable ? (
              <button
                onClick={(e) => {
                  e.preventDefault()
                  e.stopPropagation()
                  console.log('Button clicked for agent:', agent.name, 'onClick exists:', !!agent.onClick)
                  if (agent.onClick) {
                    agent.onClick()
                  } else {
                    console.warn('No onClick handler for agent:', agent.name)
                  }
                }}
                className="flex items-center mb-1 w-full text-left hover:bg-gray-50 rounded px-1 py-1 -mx-1 -my-1 transition-colors duration-200 group"
              >
                <span className="text-sm font-medium text-gray-900 truncate hidden lg:inline">{agent.name}</span>
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-4 h-4 text-gray-900 lg:hidden">
                  <path strokeLinecap="round" strokeLinejoin="round" d={agent.icon} />
                </svg>
                {agent.name === 'LEADS' ? (
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="3" stroke="currentColor" className="w-3 h-3 text-blue-600 group-hover:text-white group-hover:bg-blue-600 rounded-full ml-1 flex-shrink-0 transition-all duration-200">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                  </svg>
                ) : (
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-3 h-3 text-gray-400 group-hover:text-blue-500 ml-1 flex-shrink-0 transition-colors duration-200">
                    <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125" />
                  </svg>
                )}
              </button>
            ) : (
              <div className="flex items-center mb-1">
                <span className={`text-sm font-medium truncate hidden lg:inline ${hasSelectedCampaign ? 'text-gray-900' : 'text-gray-400'}`}>{agent.name}</span>
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className={`w-4 h-4 lg:hidden ${hasSelectedCampaign ? 'text-gray-900' : 'text-gray-400'}`}>
                  <path strokeLinecap="round" strokeLinejoin="round" d={agent.icon} />
                </svg>
              </div>
            )}
            <div className="text-lg font-bold text-gray-600">{getAgentStat(agent.name)}</div>
          </div>
        ))}

        <div className="py-4 px-4"></div>
      </div>
    </div>
  )
}


