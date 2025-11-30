import { useCallback, useState, useRef, useEffect } from 'react'
import { useAgentExecution } from '@/hooks/useAgentExecution'
import type { Lead } from '@/types'

export function useAgentActions(
  findLeadById: (leadId: number) => Lead | undefined,
  refreshLeads: (options?: { silent?: boolean }) => Promise<Lead[] | undefined>
) {
  const { loading: agentExecLoading, runAgentsForLead } = useAgentExecution()
  const [runningLeadIds, setRunningLeadIds] = useState<Set<number>>(new Set())
  const isMountedRef = useRef(true)

  useEffect(() => {
    return () => {
      isMountedRef.current = false
    }
  }, [])

  const addRunningLeadId = useCallback((leadId: number) => {
    setRunningLeadIds((prev) => {
      if (prev.has(leadId)) {
        return prev
      }
      const next = new Set(prev)
      next.add(leadId)
      return next
    })
  }, [])

  const removeRunningLeadId = useCallback((leadId: number) => {
    setRunningLeadIds((prev) => {
      if (!prev.has(leadId)) {
        return prev
      }
      const next = new Set(prev)
      next.delete(leadId)
      return next
    })
  }, [])

  const waitForLeadCompletion = useCallback(
    async (leadId: number, startingStage: string | null, getLatestLead: () => Lead | undefined) => {
      const MAX_ATTEMPTS = 40
      const POLL_INTERVAL_MS = 3000
      let currentStage = startingStage

      try {
        for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
          if (!isMountedRef.current) {
            return
          }

          await new Promise((resolve) => window.setTimeout(resolve, POLL_INTERVAL_MS))
          await refreshLeads({ silent: true })
          const latestLead = getLatestLead()

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

  const handleRunLead = useCallback(async (leadId: number, getLatestLead: () => Lead | undefined) => {
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
        removeRunningLeadId(leadId)
        return
      }

      if (result.failedAgents && result.failedAgents.length > 0) {
        alert(`Some agents failed: ${result.failedAgents.join(', ')}`)
        console.error('Some agents failed:', result.failedAgents)
      }

      if (result.status === 'queued') {
        waitForLeadCompletion(leadId, initialStage, getLatestLead).catch((err) => {
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

  const handleRunAllAgents = useCallback(async (filteredLeads: Lead[], getLatestLead: (leadId: number) => Lead | undefined, selectedLeadIds?: number[]) => {
    if (!filteredLeads.length) return

    // If specific leads are selected, only run agents for those leads
    // Otherwise, run for all non-completed leads
    const leadsToRun = selectedLeadIds && selectedLeadIds.length > 0
      ? selectedLeadIds.filter((id) => {
          const lead = filteredLeads.find((l) => l.id === id)
          return lead && lead.stage !== 'completed'
        })
      : filteredLeads
          .filter((l) => l.stage !== 'completed')
          .map((l) => l.id)

    if (leadsToRun.length === 0) return

    // Check API keys by testing the first lead first
    // If API keys are missing, show one error message and stop processing all leads
    const firstLeadId = leadsToRun[0]
    const initialStage = findLeadById(firstLeadId)?.stage ?? null
    addRunningLeadId(firstLeadId)
    
    try {
      const result = await runAgentsForLead(firstLeadId)
      
      // If API keys are missing, show error once and stop processing
      if (result && result.status === 'failed' && result.error && result.error.includes('Missing API keys')) {
        alert(`Failed to run agents: ${result.error}`)
        console.error('Agent execution failed (API keys missing):', result.error)
        removeRunningLeadId(firstLeadId)
        return
      }
      
      // API keys are available, process first lead normally
      removeRunningLeadId(firstLeadId)
      
      // Handle first lead result
      if (!result) {
        const errorMsg = 'Failed to run agents. Please check the console for details.'
        alert(errorMsg)
        console.error('Agent execution returned null - check API response')
      } else if (result.status === 'failed' && result.error && !result.error.includes('Missing API keys')) {
        // Non-API-key error for first lead - show error but continue with others
        alert(`Failed to run agents for lead: ${result.error}`)
        console.error('Agent execution failed:', result.error)
      } else if (result.status === 'queued') {
        // First lead queued successfully, start polling
        addRunningLeadId(firstLeadId)
        waitForLeadCompletion(firstLeadId, initialStage, () => getLatestLead(firstLeadId)).catch((err) => {
          console.error('Error while polling lead status:', err)
          removeRunningLeadId(firstLeadId)
        })
      } else {
        // First lead completed/partial successfully
        await refreshLeads()
      }
      
      // Process remaining leads (API keys are available, so they should work or fail for other reasons)
      for (let i = 1; i < leadsToRun.length; i++) {
        handleRunLead(leadsToRun[i], () => getLatestLead(leadsToRun[i]))
      }
    } catch (err) {
      removeRunningLeadId(firstLeadId)
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
      
      // Check if it's an API key error from the exception
      if (errorMessage.includes('Missing API keys') || errorMessage.includes('API key')) {
        alert(`Failed to run agents: ${errorMessage}`)
        console.error('Exception in handleRunAllAgents (API keys missing):', err)
        return
      }
      
      // Other errors - show but continue with remaining leads
      alert(`Error running agents: ${errorMessage}`)
      console.error('Exception in handleRunAllAgents:', err)
      
      // Still try to process remaining leads
      for (let i = 1; i < leadsToRun.length; i++) {
        handleRunLead(leadsToRun[i], () => getLatestLead(leadsToRun[i]))
      }
    }
  }, [findLeadById, addRunningLeadId, runAgentsForLead, removeRunningLeadId, waitForLeadCompletion, refreshLeads, handleRunLead])

  return {
    agentExecLoading,
    runningLeadIds: Array.from(runningLeadIds),
    handleRunLead,
    handleRunAllAgents,
  }
}
