// Test utilities for React components
import React, { ReactElement } from 'react'
import { render, RenderOptions } from '@testing-library/react'

// All providers should be added here if needed in the future
// For now, this is a basic wrapper that can be extended
const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  return <>{children}</>
}

// Custom render function that includes all providers
const customRender = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) => render(ui, { wrapper: AllTheProviders, ...options })

// Re-export everything from @testing-library/react
export * from '@testing-library/react'

// Override render method
export { customRender as render }

// Mock data helpers
export const mockCampaign = (overrides = {}) => ({
  id: 1,
  title: 'Test Campaign',
  basePrompt: 'Test base prompt',
  user_id: 1,
  created_at: '2024-01-01T00:00:00.000Z',
  updated_at: '2024-01-01T00:00:00.000Z',
  ...overrides,
})

export const mockLead = (overrides = {}) => ({
  id: 1,
  name: 'John Doe',
  email: 'john@example.com',
  title: 'VP Marketing',
  company: 'Example Corp',
  campaign_id: 1,
  created_at: '2024-01-01T00:00:00.000Z',
  updated_at: '2024-01-01T00:00:00.000Z',
  ...overrides,
})

export const mockUser = (overrides = {}) => ({
  id: 1,
  email: 'test@example.com',
  ...overrides,
})

// Mock API response helpers
export const mockApiSuccess = <T = any>(data: T, status = 200) => ({
  ok: true,
  status,
  headers: new Headers({ 'content-type': 'application/json' }),
  json: async () => data,
})

export const mockApiError = (message: string, status = 400) => ({
  ok: false,
  status,
  headers: new Headers({ 'content-type': 'application/json' }),
  json: async () => ({ error: message }),
})

export const mockApiValidationError = (errors: string[], status = 422) => ({
  ok: false,
  status,
  headers: new Headers({ 'content-type': 'application/json' }),
  json: async () => ({ errors }),
})

// Wait for async operations
export const waitForAsync = () => new Promise(resolve => setTimeout(resolve, 0))

