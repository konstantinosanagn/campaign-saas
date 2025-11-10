import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import CampaignForm from '@/components/campaigns/CampaignForm'

describe('CampaignForm', () => {
  const mockOnSubmit = jest.fn()
  const mockOnClose = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('does not render when isOpen is false', () => {
    render(
      <CampaignForm isOpen={false} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )
    expect(screen.queryByText('Create New Campaign')).not.toBeInTheDocument()
  })

  it('renders create form when isOpen is true', () => {
    render(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )
    expect(screen.getByText('Create New Campaign')).toBeInTheDocument()
    expect(screen.getByLabelText('Title')).toBeInTheDocument()
    expect(screen.getByLabelText('Base Prompt')).toBeInTheDocument()
  })

  it('renders edit form when isEdit is true', () => {
    const initialData = {
      index: 0,
      title: 'Existing Campaign',
      basePrompt: 'Existing prompt',
    }

    render(
      <CampaignForm
        isOpen={true}
        onClose={mockOnClose}
        onSubmit={mockOnSubmit}
        initialData={initialData}
        isEdit={true}
      />
    )

    expect(screen.getByText('Edit Campaign')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Existing Campaign')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Existing prompt')).toBeInTheDocument()
  })

  it('submits form with valid data', async () => {
    const user = userEvent.setup()

    render(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    await user.type(screen.getByLabelText('Title'), 'My Campaign')
    await user.type(screen.getByLabelText('Base Prompt'), 'My base prompt')

    await user.click(screen.getByRole('button', { name: /create/i }))

    expect(mockOnSubmit).toHaveBeenCalledWith({
      title: 'My Campaign',
      basePrompt: 'My base prompt',
    })
    expect(mockOnClose).toHaveBeenCalled()
  })

  it('closes form when close button is clicked', async () => {
    const user = userEvent.setup()

    render(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const closeButton = screen.getByRole('button', { name: '' })
    await user.click(closeButton)

    expect(mockOnClose).toHaveBeenCalled()
  })

  it('resets form when closed', async () => {
    const user = userEvent.setup()

    const { rerender } = render(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    await user.type(screen.getByLabelText('Title'), 'Test Campaign')
    await user.type(screen.getByLabelText('Base Prompt'), 'Test prompt')

    rerender(
      <CampaignForm isOpen={false} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    rerender(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    expect(screen.getByLabelText('Title')).toHaveValue('')
    expect(screen.getByLabelText('Base Prompt')).toHaveValue('')
  })

  it('requires title and basePrompt fields', async () => {
    const user = userEvent.setup()

    render(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const submitButton = screen.getByRole('button', { name: /create/i })
    await user.click(submitButton)

    // HTML5 validation should prevent submission
    const titleInput = screen.getByLabelText('Title') as HTMLInputElement
    expect(titleInput.validity.valid).toBe(false)
  })

  it('focuses title input when form opens', () => {
    render(
      <CampaignForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const titleInput = screen.getByLabelText('Title')
    expect(titleInput).toHaveFocus()
  })
})

