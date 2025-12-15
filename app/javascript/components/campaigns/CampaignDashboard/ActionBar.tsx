import React from 'react'
import type { Lead } from '@/types'

interface ActionBarProps {
  selectedLeads: number[]
  readyLeadsCount: number
  selectedReadyLeads: Lead[]
  sendingEmails: boolean
  agentExecLoading: boolean
  runningLeadIds: number[]
  filteredLeads: Lead[]
  campaignObj: { id: number } | null
  user?: {
    gmail_email?: string | null
    can_send_gmail?: boolean
  }
  defaultGmailSenderAvailable?: boolean
  defaultGmailSenderEmail?: string | null
  onEditSelectedLead: () => void
  onDeleteSelectedLeads: () => void
  onRunAllAgents: () => void
  onSendEmails: () => void
  onSendSelectedEmails: () => void
  onEmailConfigClick: () => void
}

export default function ActionBar({
  selectedLeads,
  readyLeadsCount,
  selectedReadyLeads,
  sendingEmails,
  agentExecLoading,
  runningLeadIds,
  filteredLeads,
  campaignObj,
  user,
  defaultGmailSenderAvailable = false,
  defaultGmailSenderEmail = null,
  onEditSelectedLead,
  onDeleteSelectedLeads,
  onRunAllAgents,
  onSendEmails,
  onSendSelectedEmails,
  onEmailConfigClick,
}: ActionBarProps) {
  const handleConnectGmail = () => {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = "/users/auth/google_oauth2";

    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content");

    if (csrfToken) {
      const csrfInput = document.createElement("input");
      csrfInput.type = "hidden";
      csrfInput.name = "authenticity_token";
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
    }

    document.body.appendChild(form);
    form.submit();
  };

  return (
    <div className="border-b border-gray-200 p-4 py-4">
      <div className="flex items-center justify-between">
        <div className="flex-1">
          {/* Sender info */}
          {(readyLeadsCount > 0 || selectedReadyLeads.length > 0) && (
            <div className="text-sm text-gray-600">
              {user?.can_send_gmail && user?.gmail_email ? (
                <p>
                  Emails will be sent from{' '}
                  <span className="font-semibold">{user.gmail_email}</span> via Gmail.
                </p>
              ) : defaultGmailSenderAvailable && defaultGmailSenderEmail ? (
                <p>
                  Emails will be sent from{' '}
                  <span className="font-semibold">{defaultGmailSenderEmail}</span> via Gmail.
                </p>
              ) : (
                <div className="flex items-center gap-2">
                  <p>
                    Emails will be sent from the default campaign sender.
                  </p>
                  <button
                    type="button"
                    onClick={handleConnectGmail}
                    className="text-blue-600 hover:text-blue-700 underline text-sm font-medium"
                  >
                    Connect Gmail
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="flex space-x-3 ml-auto">
          {selectedLeads.length > 0 && (
            <>
              {selectedLeads.length === 1 && (
                <button
                  onClick={onEditSelectedLead}
                  className="p-2 text-gray-400 hover:text-blue-500 transition-colors duration-200"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    strokeWidth="1.5"
                    stroke="currentColor"
                    className="w-5 h-5"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125"
                    />
                  </svg>
                </button>
              )}
              <button
                onClick={onDeleteSelectedLeads}
                className="p-2 text-gray-400 hover:text-red-500 transition-colors duration-200"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth="1.5"
                  stroke="currentColor"
                  className="w-5 h-5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                  />
                </svg>
              </button>
            </>
          )}
          <button
            onClick={onRunAllAgents}
            disabled={
              (agentExecLoading || runningLeadIds.length > 0) ||
              (selectedLeads.length > 0
                ? selectedLeads.filter((id) => {
                    const lead = filteredLeads.find((l) => l.id === id)
                    // Check if lead is done: run completed OR stage is sent/failed (not just 'completed')
                    const isDone = lead?.leadRun?.runStatus === 'completed' || 
                                   lead?.stage === 'completed' || 
                                   (lead?.stage?.startsWith('sent (') ?? false) ||
                                   lead?.stage === 'send_failed'
                    return lead && !isDone
                  }).length === 0
                : filteredLeads.filter((l) => {
                    const isDone = l.leadRun?.runStatus === 'completed' || 
                                   l.stage === 'completed' || 
                                   (l.stage?.startsWith('sent (') ?? false) ||
                                   l.stage === 'send_failed'
                    return !isDone
                  }).length === 0)
            }
            className="px-3 py-1.5 text-sm font-medium text-white bg-black border border-black rounded-full hover:text-black hover:bg-transparent hover:border-black transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:text-white disabled:hover:bg-black disabled:hover:border-black"
            title={
              selectedLeads.length > 0
                ? `Run agents for ${selectedLeads.length} selected lead(s)`
                : 'Run agents for all leads'
            }
          >
            {(agentExecLoading || runningLeadIds.length > 0)
              ? 'Running...'
              : selectedLeads.length > 0
              ? `Run Agents (${selectedLeads.length})`
              : 'Run Agents'}
          </button>
          {selectedReadyLeads.length > 0 ? (
            <button
              onClick={onSendSelectedEmails}
              disabled={sendingEmails || !campaignObj}
              className="px-3 py-1.5 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-full hover:text-green-600 hover:bg-transparent hover:border-green-600 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:text-white disabled:hover:bg-green-600 disabled:hover:border-green-600"
              title={`Send emails to ${selectedReadyLeads.length} selected lead(s)`}
            >
              {sendingEmails ? 'Sending...' : `Send Selected (${selectedReadyLeads.length})`}
            </button>
          ) : (
            <button
              onClick={onSendEmails}
              disabled={sendingEmails || !campaignObj || readyLeadsCount === 0}
              className="px-3 py-1.5 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-full hover:text-green-600 hover:bg-transparent hover:border-green-600 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:text-white disabled:hover:bg-green-600 disabled:hover:border-green-600"
              title={readyLeadsCount === 0 ? 'No ready leads to send' : `Send emails to ${readyLeadsCount} ready lead(s)`}
            >
              {sendingEmails ? 'Sending...' : `Send All${readyLeadsCount > 0 ? ` (${readyLeadsCount})` : ''}`}
            </button>
          )}
          <button
            onClick={onEmailConfigClick}
            className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-full hover:bg-gray-50 transition-colors duration-200"
            title="Configure email settings"
          >
            Email Settings
          </button>
        </div>
      </div>
    </div>
  )
}
