// Jest setup file for React Testing Library
import '@testing-library/jest-dom'

// Mock window.matchMedia (required by some UI libraries)
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(), // deprecated
    removeListener: jest.fn(), // deprecated
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
})

// Mock window.confirm
window.confirm = jest.fn(() => true)

// Mock window.location
Object.defineProperty(window, 'location', {
  writable: true,
  configurable: true,
  value: {
    hostname: 'localhost',
    href: '',
    pathname: '/',
    search: '',
    hash: '',
    assign: jest.fn(),
    reload: jest.fn(),
    replace: jest.fn(),
  },
});

// Mock fetch globally
global.fetch = jest.fn()

// Mock hooks that make API calls
jest.mock('@/hooks/useAgentConfigs', () => ({
  useAgentConfigs: () => ({
    configs: [],
    loading: false,
    error: null,
    loadConfigs: jest.fn(),
    createConfig: jest.fn(),
    updateConfig: jest.fn()
  })
}))

jest.mock('@/hooks/useAgentExecution', () => ({
  useAgentExecution: () => ({
    loading: false,
    runAgentsForLead: jest.fn(),
    runAgentsForMultipleLeads: jest.fn()
  })
}))

jest.mock('@/hooks/useAgentOutputs', () => ({
  useAgentOutputs: () => ({
    loading: false,
    outputs: [],
    loadAgentOutputs: jest.fn()
  })
}))

// Mock CSRF token meta tag - reset before each test
beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="test-token">'
  // Clear fetch mocks
  if (global.fetch && typeof (global.fetch as jest.Mock).mockClear === 'function') {
    (global.fetch as jest.Mock).mockClear()
  }
})

