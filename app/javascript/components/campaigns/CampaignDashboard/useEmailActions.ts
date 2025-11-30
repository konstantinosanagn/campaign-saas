import { useCallback, useState } from 'react'
import type { Lead } from '@/types'

type SendEmailsResponse = {
  success?: boolean
  sent?: number
  failed?: number
  errors?: Array<{ lead_email?: string; error?: string }>
  error?: string
}

export function useEmailActions(
  campaignObj: { id: number } | null,
  readyLeadsCount: number,
  selectedReadyLeads: Lead[],
  refreshLeads: () => Promise<void>,
  clearSelection: () => void
) {
  const [sendingEmails, setSendingEmails] = useState(false)

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

  return {
    sendingEmails,
    handleSendEmails,
    handleSendSelectedEmails,
  }
}
