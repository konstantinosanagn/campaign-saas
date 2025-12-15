import { useCallback, useState, useRef, useEffect } from 'react'
import { useAgentExecution } from '@/hooks/useAgentExecution'
import apiClient from '@/libs/utils/apiClient'
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
    async (leadId: number, startingStage: string | null, getLatestLead: () => Lead | undefined, agentName?: string) => {
      const MAX_ATTEMPTS = 60 // Increased to allow more time for agent execution
      const POLL_INTERVAL_MS = 2000 // 2 seconds between polls
      let currentStage = startingStage
      
      // Track when we started waiting - used to detect NEW outputs for rewrites
      const pollingStartTime = Date.now()

      // Determine which agent we're waiting for based on starting stage or explicit agentName
      const getExpectedAgent = (stage: string | null, explicitAgentName?: string): string | null => {
        // If agentName is explicitly provided, use it (e.g., when triggering WRITER rewrite)
        if (explicitAgentName) return explicitAgentName
        
        if (stage === 'queued') return 'SEARCH'
        if (stage === 'searched') return 'WRITER'
        if (stage === 'written') return 'CRITIQUE'
        if (stage === 'critiqued') return 'DESIGN'
        // Handle rewritten stages - could be waiting for WRITER (rewrite) or CRITIQUE
        if (stage?.startsWith('rewritten')) {
          // If at rewritten stage, we might be waiting for WRITER (if triggered) or CRITIQUE
          // Default to CRITIQUE, but agentName will override if provided
          return 'CRITIQUE'
        }
        return null
      }
      const expectedAgent = getExpectedAgent(startingStage, agentName)
      
      // Detect if this is a rewrite scenario (WRITER agent at written/rewritten stage)
      const isRewrite = expectedAgent === 'WRITER' && (startingStage === 'written' || startingStage?.startsWith('rewritten'))

      // Helper to get latest lead from refreshed data
      const getUpdatedLead = async (): Promise<Lead | undefined> => {
        const refreshedLeads = await refreshLeads({ silent: true })
        if (refreshedLeads) {
          return refreshedLeads.find((lead) => lead.id === leadId)
        }
        return getLatestLead() // Fallback to closure if refreshLeads returns undefined
      }

      // Helper to check if agent output exists (indicates completion even if stage didn't update)
      // For rewrites, we need to check if a NEW output was created after we started
      const checkAgentOutput = async (agentName: string | null, checkForNew: boolean = false, startTime?: number): Promise<boolean> => {
        if (!agentName) return false
        try {
          const response = await apiClient.get<{ outputs: Array<{ agentName: string; status: string; createdAt?: string; id?: number }> }>(`leads/${leadId}/agent_outputs`)
          if (response.data?.outputs) {
            const outputs = response.data.outputs.filter((o: { agentName: string }) => o.agentName === agentName)
            if (outputs.length === 0) return false
            
            // If checking for new output (rewrite scenario), check if any output was created after we started
            if (checkForNew && startTime) {
              // Allow a small buffer (5 seconds) before start time to account for timing differences
              const bufferTime = startTime - 5000
              const hasNewOutput = outputs.some((o: { createdAt?: string; id?: number }) => {
                if (!o.createdAt) return false
                try {
                  const outputTime = new Date(o.createdAt).getTime()
                  // Check if output was created after we started (with buffer)
                  if (outputTime >= bufferTime) {
                    console.log(`[AgentPolling] Found new ${agentName} output (ID: ${o.id}, created: ${o.createdAt}) created after polling started (${new Date(bufferTime).toISOString()})`)
                    return true
                  }
                } catch (e) {
                  console.debug(`[AgentPolling] Could not parse createdAt: ${o.createdAt}`, e)
                }
                return false
              })
              if (hasNewOutput) {
                return true
              }
              // If no new output found, continue polling
              return false
            }
            
            // Otherwise, just check if the latest output is completed
            const output = outputs[0] // Outputs are ordered by created_at DESC, so first is latest
            return output?.status === 'completed' || output?.status === 'failed'
          }
        } catch (err) {
          // Silently fail - agent outputs check is optional
          console.debug(`[AgentPolling] Could not check agent output for ${agentName}:`, err)
        }
        return false
      }

      try {
        // Check immediately before waiting (in case agent completed very quickly)
        let latestLead = await getUpdatedLead()
        if (latestLead?.leadRun) {
          const lr = latestLead.leadRun
          const lastCompleted = lr.lastCompletedStep?.agentName
          if (expectedAgent && lastCompleted === expectedAgent) {
            console.log(`[AgentPolling] Lead ${leadId} already completed ${expectedAgent} (LeadRuns).`)
            return
          }
          if (lr.runStatus === 'completed' || lr.runStatus === 'failed' || lr.runStatus === 'cancelled') {
            console.log(`[AgentPolling] Lead ${leadId} run terminal (LeadRuns): ${lr.runStatus}`)
            return
          }
        } else if (latestLead && currentStage !== latestLead.stage) {
          // Fallback: stage projection changed
          console.log(`[AgentPolling] Lead ${leadId} stage changed immediately from "${startingStage}" to "${latestLead.stage}". Agent completed.`)
          return // Exit early if stage already changed
        }

        // Also check if agent output exists immediately
        // For rewrites, we need to check for NEW outputs created after we started
        // Skip the immediate check for rewrites since we need to wait for a NEW output
        if (!isRewrite && expectedAgent && await checkAgentOutput(expectedAgent, false, pollingStartTime)) {
          console.log(`[AgentPolling] Lead ${leadId} has ${expectedAgent} output, agent completed.`)
          return
        }
        
        // For rewrites, don't check immediately - wait for the first poll to see if a new output appears
        if (isRewrite) {
          console.log(`[AgentPolling] Lead ${leadId} rewrite detected - waiting for new ${expectedAgent} output (starting time: ${new Date(pollingStartTime).toISOString()})`)
        }

        for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
          if (!isMountedRef.current) {
            return
          }

          await new Promise((resolve) => window.setTimeout(resolve, POLL_INTERVAL_MS))
          latestLead = await getUpdatedLead()

          if (!latestLead) {
            // Lead not found, stop polling
            console.log(`[AgentPolling] Lead ${leadId} not found, stopping polling.`)
            break
          }

          if (latestLead.leadRun) {
            const lr = latestLead.leadRun
            const lastCompleted = lr.lastCompletedStep?.agentName
            const terminal = lr.runStatus === 'completed' || lr.runStatus === 'failed' || lr.runStatus === 'cancelled'

            if (expectedAgent && lastCompleted === expectedAgent) {
              console.log(`[AgentPolling] Lead ${leadId} completed ${expectedAgent} (LeadRuns).`)
              break
            }
            if (terminal) {
              console.log(`[AgentPolling] Lead ${leadId} run terminal (LeadRuns): ${lr.runStatus}`)
              break
            }
          } else {
            // Fallback: stage projection changed (older behavior)
            // For rewrites, stage might not change (stays "rewritten"), so we also check outputs
            if (currentStage !== latestLead.stage) {
              currentStage = latestLead.stage
              console.log(`[AgentPolling] Lead ${leadId} stage changed from "${startingStage}" to "${currentStage}". Agent completed.`)
              break
            }
          }

          // Check if agent output exists (fallback if stage didn't update)
          // For rewrites, check for NEW outputs created after we started
          if (expectedAgent && await checkAgentOutput(expectedAgent, isRewrite, pollingStartTime)) {
            console.log(`[AgentPolling] Lead ${leadId} has ${expectedAgent} output (stage: "${latestLead.stage}"), agent completed.`)
            break
          }

          // Check if we've reached a final stage (all agents done)
          // Include sent stages and send_failed as final stages
          const reachedFinalStage = latestLead.stage === 'completed' || 
                                    latestLead.stage === 'designed' ||
                                    (latestLead.stage?.startsWith('sent (') ?? false) ||
                                    latestLead.stage === 'send_failed'
          if (reachedFinalStage) {
            console.log(`[AgentPolling] Lead ${leadId} reached final stage "${latestLead.stage}".`)
            break
          }

          // Log progress every 10 attempts for debugging (reduced frequency)
          if (attempt > 0 && attempt % 10 === 0) {
            console.log(`[AgentPolling] Lead ${leadId} still at stage "${latestLead.stage}" (attempt ${attempt + 1}/${MAX_ATTEMPTS}, waiting for ${expectedAgent || 'unknown'} agent)`)
          }

          // Timeout warning on last attempt
          if (attempt === MAX_ATTEMPTS - 1) {
            console.warn(`[AgentPolling] Lead ${leadId} timeout after ${MAX_ATTEMPTS * (POLL_INTERVAL_MS / 1000)} seconds. Current stage: "${latestLead.stage}", started at: "${startingStage}", expected agent: ${expectedAgent || 'unknown'}`)
          }
        }
      } catch (pollError) {
        console.error('Error while polling lead status:', pollError)
      } finally {
        // Always remove the loading cube when polling stops
        if (isMountedRef.current) {
          console.log(`[AgentPolling] Stopping polling for lead ${leadId}, removing loading state.`)
          removeRunningLeadId(leadId)
        }
      }
    },
    [refreshLeads, removeRunningLeadId]
  )

  const handleRunLead = useCallback(async (leadId: number, getLatestLead: () => Lead | undefined, agentName?: string) => {
    const initialStage = findLeadById(leadId)?.stage ?? null
    addRunningLeadId(leadId)
    try {
      console.log('Running agents for lead:', leadId, agentName ? `with agentName: ${agentName}` : '')
      const result = await runAgentsForLead(leadId, agentName)
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
        // Pass agentName to waitForLeadCompletion so it knows which agent to wait for
        // This is especially important for WRITER rewrites where stage might not change
        waitForLeadCompletion(leadId, initialStage, getLatestLead, agentName).catch((err) => {
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
          // Check if lead is done: run completed OR stage is sent/failed
          const isDone = lead?.leadRun?.runStatus === 'completed' || 
                         lead?.stage === 'completed' || 
                         (lead?.stage?.startsWith('sent (') ?? false) ||
                         lead?.stage === 'send_failed'
          return !!lead && !isDone
        })
      : filteredLeads
          .filter((l) => {
            const isDone = l.leadRun?.runStatus === 'completed' || 
                          l.stage === 'completed' || 
                          (l.stage?.startsWith('sent (') ?? false) ||
                          l.stage === 'send_failed'
            return !isDone
          })
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
        waitForLeadCompletion(firstLeadId, initialStage, () => getLatestLead(firstLeadId), undefined).catch((err) => {
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
