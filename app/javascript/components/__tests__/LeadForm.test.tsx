import React from 'react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import LeadForm from '@/components/leads/LeadForm'

describe('LeadForm', () => {
  const mockOnSubmit = jest.fn()
  const mockOnClose = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('processes CSV upload and triggers bulk submit', async () => {
    const user = userEvent.setup()
    const mockOnBulkSubmit = jest.fn().mockResolvedValue({ success: true as const })
    const alertSpy = jest.spyOn(window, 'alert').mockImplementation(() => {})

    try {
      render(
        <LeadForm
          isOpen={true}
          onClose={mockOnClose}
          onSubmit={mockOnSubmit}
          onBulkSubmit={mockOnBulkSubmit}
        />
      )

      const fileInput = screen.getByTestId('lead-import-input') as HTMLInputElement
      const csvContent = [
        'First Name,Last Name,Company Email,Position/Title,Company Name',
        'Jane,Doe,jane@example.com,Manager,Acme Corp',
      ].join('\n')
      
      // Create a File with the CSV content
      // File.text() is polyfilled in setup.ts
      const file = new File([csvContent], 'leads.csv', { type: 'text/csv' })

      // Upload the file - user.upload handles the file input change event
      await user.upload(fileInput, file)

      await waitFor(() => {
        expect(mockOnBulkSubmit).toHaveBeenCalledWith([
          {
            firstName: 'Jane',
            lastName: 'Doe',
            email: 'jane@example.com',
            title: 'Manager',
            company: 'Acme Corp',
          },
        ])
      }, { timeout: 3000 })

      expect(mockOnSubmit).not.toHaveBeenCalled()
      expect(mockOnClose).toHaveBeenCalled()
      expect(alertSpy).not.toHaveBeenCalled()
    } finally {
      alertSpy.mockRestore()
    }
  })

  it('does not render when isOpen is false', () => {
    render(
      <LeadForm isOpen={false} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )
    expect(screen.queryByText('Add Lead')).not.toBeInTheDocument()
  })

  it('renders create form when isOpen is true', () => {
    render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )
    expect(screen.getByRole('heading', { name: 'Add Lead' })).toBeInTheDocument()
    expect(screen.getByLabelText('First Name')).toBeInTheDocument()
    expect(screen.getByLabelText('Last Name')).toBeInTheDocument()
    expect(screen.getByLabelText('Company Email')).toBeInTheDocument()
    expect(screen.getByLabelText('Position/Title')).toBeInTheDocument()
    expect(screen.getByLabelText('Company Name')).toBeInTheDocument()
  })

  it('renders edit form when isEdit is true', () => {
    const initialData = {
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP Marketing',
      company: 'Example Corp',
    }

    render(
      <LeadForm
        isOpen={true}
        onClose={mockOnClose}
        onSubmit={mockOnSubmit}
        initialData={initialData}
        isEdit={true}
      />
    )

    expect(screen.getByText('Edit Lead')).toBeInTheDocument()
    expect(screen.getByDisplayValue('John')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Doe')).toBeInTheDocument()
    expect(screen.getByDisplayValue('john@example.com')).toBeInTheDocument()
    expect(screen.getByDisplayValue('VP Marketing')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Example Corp')).toBeInTheDocument()
  })

  it('submits form with valid data', async () => {
    const user = userEvent.setup()

    render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    await user.type(screen.getByLabelText('First Name'), 'Jane')
    await user.type(screen.getByLabelText('Last Name'), 'Smith')
    await user.type(screen.getByLabelText('Company Email'), 'jane@example.com')
    await user.type(screen.getByLabelText('Position/Title'), 'Head of Sales')
    await user.type(screen.getByLabelText('Company Name'), 'Example Inc')

    await user.click(screen.getByRole('button', { name: /add lead/i }))

    expect(mockOnSubmit).toHaveBeenCalledWith({
      name: 'Jane Smith',
      email: 'jane@example.com',
      title: 'Head of Sales',
      company: 'Example Inc',
    })
    expect(mockOnClose).toHaveBeenCalled()
  })

  it('closes form when close button is clicked', async () => {
    const user = userEvent.setup()

    render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const closeButton = screen.getByRole('button', { name: '' })
    await user.click(closeButton)

    expect(mockOnClose).toHaveBeenCalled()
  })

  it('resets form when closed', async () => {
    const user = userEvent.setup()

    const { rerender } = render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    await user.type(screen.getByLabelText('First Name'), 'Test')
    await user.type(screen.getByLabelText('Last Name'), 'Lead')
    await user.type(screen.getByLabelText('Company Email'), 'test@example.com')

    rerender(
      <LeadForm isOpen={false} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    rerender(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    expect(screen.getByLabelText('First Name')).toHaveValue('')
    expect(screen.getByLabelText('Last Name')).toHaveValue('')
    expect(screen.getByLabelText('Company Email')).toHaveValue('')
  })

  it('requires all fields', async () => {
    const user = userEvent.setup()

    render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const submitButton = screen.getByRole('button', { name: /add lead/i })
    await user.click(submitButton)

    // HTML5 validation should prevent submission
    const firstNameInput = screen.getByLabelText('First Name') as HTMLInputElement
    expect(firstNameInput.validity.valid).toBe(false)
  })

  it('validates email format', async () => {
    const user = userEvent.setup()

    render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const emailInput = screen.getByLabelText('Company Email') as HTMLInputElement
    await user.type(emailInput, 'invalid-email')

    expect(emailInput.validity.valid).toBe(false)
  })

  it('focuses name input when form opens', () => {
    render(
      <LeadForm isOpen={true} onClose={mockOnClose} onSubmit={mockOnSubmit} />
    )

    const firstNameInput = screen.getByLabelText('First Name')
    expect(firstNameInput).toHaveFocus()
  })
})

