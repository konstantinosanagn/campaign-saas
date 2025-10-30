'use client'

import React from 'react'
import type { Lead } from '@/types'

interface ProgressTableProps {
  leads: Lead[]
  onRunLead: (leadId: number) => void
  onLeadClick: (lead: Lead) => void
  onStageClick: (lead: Lead) => void
  selectedLeads: number[]
}

function ProgressTable({ leads, onRunLead, onLeadClick, onStageClick, selectedLeads }: ProgressTableProps) {
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
        <table className="w-full">
          <thead>
            <tr className="border-b border-blue-500 bg-gray-50">
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Lead</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Company</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Stage</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Quality</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody>
            {leads.map((lead) => (
              <tr 
                key={lead.id} 
                className="border-b border-gray-200 hover:bg-blue-100 transition-colors duration-200"
              >
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
                  <button
                    onClick={() => onRunLead(lead.id)}
                    className="inline-flex items-center justify-center w-8 h-8 rounded-md text-gray-600 hover:text-black hover:bg-transparent transition-colors duration-200 group"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor" className="w-6 h-6 group-hover:fill-black transition-all duration-300 ease-in-out">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z" />
                    </svg>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default React.memo(ProgressTable)


