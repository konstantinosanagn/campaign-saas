'use client'

import React from 'react'
import type { Lead } from '@/types'
import Cube from '@/components/shared/Cube'

interface ProgressTableProps {
  leads: Lead[]
  onRunLead: (leadId: number) => void
  onLeadClick: (lead: Lead) => void
  onStageClick: (lead: Lead) => void
  selectedLeads: number[]
  onToggleSelection?: (leadId: number) => void
  onToggleMultiple?: (ids: number[], shouldSelect: boolean) => void
  runningLeadIds?: number[]
}

function ProgressTable({ leads, onRunLead, onLeadClick, onStageClick, selectedLeads, onToggleSelection, onToggleMultiple, runningLeadIds = [] }: ProgressTableProps) {
  
  // Check if a lead can be sent via email (only designed/completed stage)
  // Note: All leads can be selected, but only designed/completed leads can be sent emails
  const canSendEmail = (lead: Lead): boolean => {
    return lead.stage === 'designed' || lead.stage === 'completed'
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
                    {lead.stage}
                  </button>
                </td>
                <td className="px-4 py-3 text-gray-500">{lead.quality || '-'}</td>
                <td className="px-4 py-3">
                  {runningLeadIds.includes(lead.id) ? (
                    <div className="inline-flex items-center justify-center w-8 h-8">
                      <Cube variant="black" size="small" />
                    </div>
                  ) : (
                    <button
                      onClick={() => onRunLead(lead.id)}
                      className="inline-flex items-center justify-center w-8 h-8 rounded-md text-gray-600 hover:text-black hover:bg-transparent transition-colors duration-200 group"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6 group-hover:fill-black transition-all duration-300 ease-in-out">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z" />
                      </svg>
                    </button>
                  )}
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


