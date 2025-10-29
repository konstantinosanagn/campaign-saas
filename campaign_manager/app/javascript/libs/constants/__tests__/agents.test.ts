import { baseAgents, AgentConfig, AgentName } from '../agents'

describe('agents', () => {
  it('exports baseAgents array', () => {
    expect(Array.isArray(baseAgents)).toBe(true)
    expect(baseAgents.length).toBeGreaterThan(0)
  })

  it('contains all required agent types', () => {
    const agentNames = baseAgents.map(agent => agent.name)
    expect(agentNames).toContain('LEADS')
    expect(agentNames).toContain('WRITER')
    expect(agentNames).toContain('CRITIQUE')
    expect(agentNames).toContain('DESIGNER')
    expect(agentNames).toContain('SEARCH')
    expect(agentNames).toContain('SENDER')
  })

  it('each agent has required properties', () => {
    baseAgents.forEach(agent => {
      expect(agent).toHaveProperty('name')
      expect(agent).toHaveProperty('icon')
      expect(agent).toHaveProperty('clickable')
      expect(typeof agent.name).toBe('string')
      expect(typeof agent.icon).toBe('string')
      expect(typeof agent.clickable).toBe('boolean')
    })
  })

  it('agent names match AgentName type', () => {
    const validNames: AgentName[] = ['LEADS', 'WRITER', 'CRITIQUE', 'DESIGNER', 'SEARCH', 'SENDER']
    baseAgents.forEach(agent => {
      expect(validNames).toContain(agent.name)
    })
  })

  it('icons are non-empty strings', () => {
    baseAgents.forEach(agent => {
      expect(agent.icon).toBeTruthy()
      expect(agent.icon.length).toBeGreaterThan(0)
    })
  })

  it('matches AgentConfig interface', () => {
    baseAgents.forEach(agent => {
      const config: AgentConfig = agent
      expect(config.name).toBeDefined()
      expect(config.icon).toBeDefined()
      expect(config.clickable).toBeDefined()
    })
  })

  it('has correct clickable settings', () => {
    const clickableAgents = baseAgents.filter(agent => agent.clickable)
    const nonClickableAgents = baseAgents.filter(agent => !agent.clickable)

    // Most agents should be clickable
    expect(clickableAgents.length).toBeGreaterThan(nonClickableAgents.length)

    // SENDER should not be clickable
    const sender = baseAgents.find(agent => agent.name === 'SENDER')
    expect(sender).toBeDefined()
    expect(sender?.clickable).toBe(false)
  })

  it('has 6 agents total', () => {
    expect(baseAgents.length).toBe(6)
  })
})

