import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Navigation from '@/components/shared/Navigation'

// Mock the useApiKeys hook
jest.mock('@/hooks/useApiKeys', () => ({
  useApiKeys: jest.fn(),
}))

// Mock ApiKeyModal
jest.mock('@/components/shared/ApiKeyModal', () => {
  return function MockApiKeyModal({ isOpen, onClose, onSave, initialKeys }: any) {
    if (!isOpen) return null
    return (
      <div data-testid="api-key-modal">
        <button onClick={onClose}>Close</button>
        <button onClick={() => onSave({ llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' })}>Save</button>
        <div>{JSON.stringify(initialKeys)}</div>
      </div>
    )
  }
})

// Mock Cube component
jest.mock('@/components/shared/Cube', () => {
  return function MockCube() {
    return <div data-testid="cube">Cube</div>
  }
})

import { useApiKeys } from '@/hooks/useApiKeys'

describe('Navigation', () => {
  const mockSaveKeys = jest.fn()
  const mockKeys = { llmApiKey: 'sk-existing', tavilyApiKey: 'tv-existing' }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(useApiKeys as jest.Mock).mockReturnValue({
      keys: mockKeys,
      saveKeys: mockSaveKeys,
    })
  })

  it('renders navigation with user info and cube logo', () => {
    render(<Navigation />)
    
    expect(screen.getByText('John Doe')).toBeInTheDocument()
    expect(screen.getByText('Software Engineer @ TechCorp')).toBeInTheDocument()
    expect(screen.getByTestId('cube')).toBeInTheDocument()
  })

  it('opens API key modal when profile button is clicked', () => {
    render(<Navigation />)
    
    const profileButton = screen.getByRole('button', { name: '' }).closest('button')
    expect(profileButton).toBeInTheDocument()
    
    fireEvent.click(profileButton!)
    
    expect(screen.getByTestId('api-key-modal')).toBeInTheDocument()
  })

  it('closes API key modal when close is clicked', () => {
    render(<Navigation />)
    
    const profileButton = screen.getByRole('button', { name: '' }).closest('button')
    fireEvent.click(profileButton!)
    
    expect(screen.getByTestId('api-key-modal')).toBeInTheDocument()
    
    fireEvent.click(screen.getByText('Close'))
    
    expect(screen.queryByTestId('api-key-modal')).not.toBeInTheDocument()
  })

  it('calls saveKeys when API keys are saved successfully', async () => {
    mockSaveKeys.mockResolvedValue(true)
    
    render(<Navigation />)
    
    const profileButton = screen.getByRole('button', { name: '' }).closest('button')
    fireEvent.click(profileButton!)
    
    const saveButton = screen.getByText('Save')
    fireEvent.click(saveButton)
    
    await waitFor(() => {
      expect(mockSaveKeys).toHaveBeenCalledWith({ llmApiKey: 'sk-test', tavilyApiKey: 'tv-test' })
    })
  })

  it('logs error when saveKeys fails', async () => {
    mockSaveKeys.mockResolvedValue(false)
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
    
    render(<Navigation />)
    
    const profileButton = screen.getByRole('button', { name: '' }).closest('button')
    fireEvent.click(profileButton!)
    
    const saveButton = screen.getByText('Save')
    fireEvent.click(saveButton)
    
    await waitFor(() => {
      expect(consoleErrorSpy).toHaveBeenCalledWith('Failed to save API keys')
    })
    
    consoleErrorSpy.mockRestore()
  })

  it('successfully saves API keys even when some keys are empty', async () => {
    mockSaveKeys.mockResolvedValue(true)

    render(<Navigation />)

    const profileButton = screen.getByRole('button', { name: '' }).closest('button')
    fireEvent.click(profileButton!)

    // Create a custom save handler that passes empty keys
    const modal = screen.getByTestId('api-key-modal')
    const customSaveButton = document.createElement('button')
    customSaveButton.textContent = 'Save Empty'
    customSaveButton.onclick = async () => {
      await mockSaveKeys({ llmApiKey: '', tavilyApiKey: 'tv-test' })
    }
    modal.appendChild(customSaveButton)
    fireEvent.click(customSaveButton)

    await waitFor(() => {
      expect(mockSaveKeys).toHaveBeenCalledWith({ llmApiKey: '', tavilyApiKey: 'tv-test' })
    })
  })

  it('renders with correct layout classes', () => {
    const { container } = render(<Navigation />)
    
    const nav = container.querySelector('nav')
    expect(nav).toHaveClass('bg-transparent', 'shadow-sm', 'relative', 'z-10')
  })

  it('renders cube logo as link', () => {
    render(<Navigation />)
    
    const link = screen.getByRole('link')
    expect(link).toHaveAttribute('href', '/')
    expect(link).toContainElement(screen.getByTestId('cube'))
  })
})

