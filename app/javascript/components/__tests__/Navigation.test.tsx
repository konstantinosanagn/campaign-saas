import React from 'react'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import Navigation from '@/components/shared/Navigation'
import { useApiKeys } from '@/hooks/useApiKeys'

jest.mock('@/hooks/useApiKeys', () => ({
  useApiKeys: jest.fn(),
}))

jest.mock('@/components/shared/Cube', () => {
  return function MockCube() {
    return <div data-testid="cube">Cube</div>
  }
})

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

  it('renders navigation with user info, cube logo, and partner logos', () => {
    render(<Navigation />)

    expect(screen.getByText('John Doe')).toBeInTheDocument()
    expect(screen.getByText('Software Engineer @ TechCorp')).toBeInTheDocument()
    expect(screen.getByTestId('cube')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Manage Tavily API key/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Manage Gemini API key/i })).toBeInTheDocument()
  })

  it('shows Tavily dropdown on hover and hides after successful save', async () => {
    mockSaveKeys.mockResolvedValue(true)
    render(<Navigation />)

    const tavilyButton = screen.getByRole('button', { name: /Manage Tavily API key/i })
    fireEvent.mouseEnter(tavilyButton)

    const input = await screen.findByPlaceholderText('Enter your Tavily API key')
    expect(input).toBeInTheDocument()
    fireEvent.change(input, { target: { value: 'tv-new' } })

    fireEvent.click(screen.getByRole('button', { name: /Save/i }))

    await waitFor(() => expect(mockSaveKeys).toHaveBeenCalledWith({
      llmApiKey: mockKeys.llmApiKey,
      tavilyApiKey: 'tv-new',
    }))

    await waitFor(() => {
      expect(screen.queryByPlaceholderText('Enter your Tavily API key')).not.toBeInTheDocument()
    })
  })

  it('keeps dropdown open and shows error when save fails', async () => {
    mockSaveKeys.mockResolvedValue(false)
    render(<Navigation />)

    const geminiButton = screen.getByRole('button', { name: /Manage Gemini API key/i })
    fireEvent.focus(geminiButton)

    const input = await screen.findByPlaceholderText('Enter your Gemini API key')
    fireEvent.change(input, { target: { value: 'sk-new' } })

    fireEvent.submit(input.closest('form')!)

    await waitFor(() => expect(mockSaveKeys).toHaveBeenCalledWith({
      llmApiKey: 'sk-new',
      tavilyApiKey: mockKeys.tavilyApiKey,
    }))

    expect(await screen.findByText(/Save failed/i)).toBeInTheDocument()
  })

  it('retains dropdown while input is focused', async () => {
    render(<Navigation />)

    const tavilyButton = screen.getByRole('button', { name: /Manage Tavily API key/i })
    fireEvent.focus(tavilyButton)

    const input = await screen.findByPlaceholderText('Enter your Tavily API key')
    expect(input).toHaveFocus()

    fireEvent.blur(tavilyButton)
    expect(input).toBeInTheDocument()
  })
})

