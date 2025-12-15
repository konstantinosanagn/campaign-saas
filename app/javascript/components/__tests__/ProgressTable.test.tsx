import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import ProgressTable from '@/components/leads/ProgressTable'
import type { Lead } from '@/types'

describe('ProgressTable', () => {
  const mockLeads: Lead[] = [
    {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP Marketing',
      company: 'Example Corp',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    },
    {
      id: 2,
      name: 'Jane Smith',
      email: 'jane@example.com',
      title: 'Head of Sales',
      company: 'Test Inc',
      website: 'https://test.com',
      campaignId: 1,
      stage: 'writing',
      quality: '-',
    },
    {
      id: 3,
      name: 'Bob Johnson',
      email: 'bob@example.com',
      title: 'CEO',
      company: 'Company XYZ',
      website: '',
      campaignId: 1,
      stage: 'sent',
      quality: null,
    },
  ]

  const mockOnRunLead = jest.fn()
  const mockOnLeadClick = jest.fn()
  const mockOnStageClick = jest.fn()
  const mockOnToggleSelection = jest.fn()
  const mockOnToggleMultiple = jest.fn()
  const mockSelectedLeads: number[] = []

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders table with correct headers', () => {
    render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getByText('Lead')).toBeInTheDocument()
    expect(screen.getByText('Company')).toBeInTheDocument()
    expect(screen.getByText('Stage')).toBeInTheDocument()
    expect(screen.getByText('Quality')).toBeInTheDocument()
    expect(screen.getByText('Actions')).toBeInTheDocument()
  })

  it('renders all leads in table rows', () => {
    render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getByText('John Doe')).toBeInTheDocument()
    expect(screen.getByText('Jane Smith')).toBeInTheDocument()
    expect(screen.getByText('Bob Johnson')).toBeInTheDocument()
  })

  it('displays lead information correctly', () => {
    render(
      <ProgressTable
        leads={[mockLeads[0]]}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getByText('John Doe')).toBeInTheDocument()
    expect(screen.getByText('john@example.com · VP Marketing')).toBeInTheDocument()
    expect(screen.getByText('Example Corp')).toBeInTheDocument()
    expect(screen.getByText('(https://example.com)')).toBeInTheDocument()
  })

  it('displays stage badge', () => {
    render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getByText('queued')).toBeInTheDocument()
    expect(screen.getByText('writing')).toBeInTheDocument()
    expect(screen.getByText('sent')).toBeInTheDocument()
  })

  it('displays quality or dash', () => {
    render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    // Lead 1 has quality 'A'
    expect(screen.getByText('A')).toBeInTheDocument()
    // Lead 2 has quality '-'
    const dashElements = screen.getAllByText('-')
    expect(dashElements.length).toBeGreaterThan(0)
  })

  it('displays dash for null quality', () => {
    render(
      <ProgressTable
        leads={[mockLeads[2]]}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getAllByText('-')[0]).toBeInTheDocument()
  })

  it('calls onRunLead when run button is clicked', () => {
    render(
      <ProgressTable
        leads={[mockLeads[0]]}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    const runButtons = screen.getAllByRole('button')
    const runButton = runButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('M5.25')
    })
    
    if (runButton) {
      fireEvent.click(runButton)
      expect(mockOnRunLead).toHaveBeenCalledWith(1)
    }
  })

  it('calls onLeadClick when company cell is clicked', () => {
    render(
      <ProgressTable
        leads={[mockLeads[0]]}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    const companyCell = screen.getByText('Example Corp').closest('td')
    fireEvent.click(companyCell!)

    expect(mockOnLeadClick).toHaveBeenCalledWith(mockLeads[0])
  })

  it('highlights selected leads', () => {
    render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={[1]}
      />
    )

    const johnDoeName = screen.getByText('John Doe')
    expect(johnDoeName).toHaveClass('text-blue-600')
  })

  it('does not highlight non-selected leads', () => {
    render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={[2]}
      />
    )

    const johnDoeName = screen.getByText('John Doe')
    expect(johnDoeName).toHaveClass('text-gray-900')
  })

  it('handles empty leads array', () => {
    render(
      <ProgressTable
        leads={[]}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getByText('Lead')).toBeInTheDocument()
    expect(screen.queryByText('John Doe')).not.toBeInTheDocument()
  })

  it('displays empty website as empty string', () => {
    render(
      <ProgressTable
        leads={[mockLeads[2]]}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    expect(screen.getByText('()')).toBeInTheDocument()
  })

  it('has correct styling classes', () => {
    const { container } = render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    const table = container.querySelector('table')
    expect(table).toHaveClass('w-full')
  })

  it('renders with memo optimization', () => {
    const { rerender } = render(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={mockSelectedLeads}
      />
    )

    // Component should re-render when props change
    rerender(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        onStageClick={mockOnStageClick}
        selectedLeads={[1]}
      />
    )

    const johnDoeName = screen.getByText('John Doe')
    expect(johnDoeName).toHaveClass('text-blue-600')
  })

  describe('checkbox selection', () => {
    it('renders checkboxes when onToggleSelection is provided', () => {
      const selectableLeads: Lead[] = [
        {
          ...mockLeads[0],
          stage: 'designed',
        },
      ]

      render(
        <ProgressTable
          leads={selectableLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('does not render checkboxes when onToggleSelection is not provided', () => {
      render(
        <ProgressTable
          leads={mockLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
        />
      )

      const checkboxes = screen.queryAllByRole('checkbox')
      expect(checkboxes.length).toBe(0)
    })

    it('renders select all checkbox in header when onToggleSelection is provided', () => {
      const selectableLeads: Lead[] = [
        {
          ...mockLeads[0],
          stage: 'designed',
        },
      ]

      render(
        <ProgressTable
          leads={selectableLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      // Should have select all checkbox + individual checkbox
      expect(checkboxes.length).toBe(2)
    })

    it('calls onToggleSelection when individual checkbox is clicked', () => {
      const selectableLead: Lead = {
        ...mockLeads[0],
        stage: 'designed',
      }

      render(
        <ProgressTable
          leads={[selectableLead]}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      // The second checkbox is the individual lead checkbox
      const individualCheckbox = checkboxes[1]
      fireEvent.click(individualCheckbox)

      expect(mockOnToggleSelection).toHaveBeenCalledWith(1)
    })

    it('disables checkbox for non-selectable leads', () => {
      render(
        <ProgressTable
          leads={mockLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      // First checkbox is select all, then individual checkboxes
      // Lead 1 has stage 'queued', so it's not selectable
      const lead1Checkbox = checkboxes[1]
      expect(lead1Checkbox).toBeDisabled()
    })

    it('enables checkbox for selectable leads', () => {
      const selectableLead: Lead = {
        ...mockLeads[0],
        stage: 'designed',
      }

      render(
        <ProgressTable
          leads={[selectableLead]}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const leadCheckbox = checkboxes[1]
      expect(leadCheckbox).not.toBeDisabled()
    })

    it('shows checked state for selected leads', () => {
      const selectableLead: Lead = {
        ...mockLeads[0],
        stage: 'designed',
      }

      render(
        <ProgressTable
          leads={[selectableLead]}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[1]}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const leadCheckbox = checkboxes[1] as HTMLInputElement
      expect(leadCheckbox.checked).toBe(true)
    })

    it('shows unchecked state for non-selected leads', () => {
      const selectableLead: Lead = {
        ...mockLeads[0],
        stage: 'designed',
      }

      render(
        <ProgressTable
          leads={[selectableLead]}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[]}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const leadCheckbox = checkboxes[1] as HTMLInputElement
      expect(leadCheckbox.checked).toBe(false)
    })

    it('calls onToggleMultiple when select all checkbox is clicked', () => {
      const selectableLeads: Lead[] = [
        {
          ...mockLeads[0],
          id: 1,
          stage: 'designed',
        },
        {
          ...mockLeads[1],
          id: 2,
          stage: 'completed',
        },
      ]

      render(
        <ProgressTable
          leads={selectableLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[]}
          onToggleSelection={mockOnToggleSelection}
          onToggleMultiple={mockOnToggleMultiple}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const selectAllCheckbox = checkboxes[0]
      fireEvent.click(selectAllCheckbox)

      expect(mockOnToggleMultiple).toHaveBeenCalledWith([1, 2], true)
    })

    it('deselects all when select all checkbox is unchecked', () => {
      const selectableLeads: Lead[] = [
        {
          ...mockLeads[0],
          id: 1,
          stage: 'designed',
        },
        {
          ...mockLeads[1],
          id: 2,
          stage: 'completed',
        },
      ]

      render(
        <ProgressTable
          leads={selectableLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[1, 2]}
          onToggleSelection={mockOnToggleSelection}
          onToggleMultiple={mockOnToggleMultiple}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const selectAllCheckbox = checkboxes[0]
      fireEvent.click(selectAllCheckbox)

      expect(mockOnToggleMultiple).toHaveBeenCalledWith([1, 2], false)
    })

    it('shows checked state for select all when all selectable leads are selected', () => {
      const selectableLeads: Lead[] = [
        {
          ...mockLeads[0],
          id: 1,
          stage: 'designed',
        },
        {
          ...mockLeads[1],
          id: 2,
          stage: 'completed',
        },
      ]

      render(
        <ProgressTable
          leads={selectableLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[1, 2]}
          onToggleSelection={mockOnToggleSelection}
          onToggleMultiple={mockOnToggleMultiple}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const selectAllCheckbox = checkboxes[0] as HTMLInputElement
      expect(selectAllCheckbox.checked).toBe(true)
    })

    it('shows unchecked state for select all when not all selectable leads are selected', () => {
      const selectableLeads: Lead[] = [
        {
          ...mockLeads[0],
          id: 1,
          stage: 'designed',
        },
        {
          ...mockLeads[1],
          id: 2,
          stage: 'completed',
        },
      ]

      render(
        <ProgressTable
          leads={selectableLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[1]}
          onToggleSelection={mockOnToggleSelection}
          onToggleMultiple={mockOnToggleMultiple}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const selectAllCheckbox = checkboxes[0] as HTMLInputElement
      expect(selectAllCheckbox.checked).toBe(false)
    })

    it('only considers selectable leads for select all checkbox', () => {
      const mixedLeads: Lead[] = [
        {
          ...mockLeads[0],
          id: 1,
          stage: 'queued', // Not selectable
        },
        {
          ...mockLeads[1],
          id: 2,
          stage: 'designed', // Selectable
        },
        {
          ...mockLeads[2],
          id: 3,
          stage: 'completed', // Selectable
        },
      ]

      render(
        <ProgressTable
          leads={mixedLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={[2, 3]}
          onToggleSelection={mockOnToggleSelection}
          onToggleMultiple={mockOnToggleMultiple}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const selectAllCheckbox = checkboxes[0] as HTMLInputElement
      // Should be checked because all selectable leads (2, 3) are selected
      expect(selectAllCheckbox.checked).toBe(true)
    })

    it('does not call onToggleSelection when clicking disabled checkbox', () => {
      render(
        <ProgressTable
          leads={mockLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          onToggleSelection={mockOnToggleSelection}
        />
      )

      const checkboxes = screen.getAllByRole('checkbox')
      const disabledCheckbox = checkboxes[1] // First lead is not selectable
      expect(disabledCheckbox).toBeDisabled()

      fireEvent.click(disabledCheckbox)
      expect(mockOnToggleSelection).not.toHaveBeenCalled()
    })
  })

  describe('onStageClick', () => {
    it('calls onStageClick when stage badge is clicked', () => {
      render(
        <ProgressTable
          leads={mockLeads}
          onRunLead={mockOnRunLead}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
        />
      )

      const stageButton = screen.getByText('queued')
      fireEvent.click(stageButton)

      expect(mockOnStageClick).toHaveBeenCalledWith(mockLeads[0])
    })
  })

  describe('resend functionality for sent leads', () => {
    it('shows send/resend button for sent lead with no active run (auto-heal case)', () => {
      const sentLead: Lead = {
        id: 86,
        name: 'Test Lead',
        email: 'test@example.com',
        title: 'Test Title',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
        stage: 'sent (1)',
        email_status: 'sent',
        leadRun: null, // No active run due to auto-heal
        quality: null,
      }

      const mockOnSendEmail = jest.fn()

      render(
        <ProgressTable
          leads={[sentLead]}
          onRunLead={mockOnRunLead}
          onSendEmail={mockOnSendEmail}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
        />
      )

      // Should show the send/resend button (action icon)
      const buttons = screen.getAllByRole('button')
      // Find the action button (should have a title with "Resend email" or "Send email")
      const actionButton = buttons.find(btn => {
        const title = btn.getAttribute('title')
        return title && (title.includes('Resend') || title.includes('Send email'))
      })

      expect(actionButton).toBeInTheDocument()
      expect(actionButton).not.toBeDisabled()
    })

    it('disables send button while email is being sent', () => {
      const sendingLead: Lead = {
        id: 87,
        name: 'Sending Lead',
        email: 'sending@example.com',
        title: 'Test Title',
        company: 'Test Company',
        website: 'https://test.com',
        campaignId: 1,
        stage: 'sent (1)',
        email_status: 'sending', // Currently sending
        leadRun: null,
        quality: null,
      }

      const mockOnSendEmail = jest.fn()

      render(
        <ProgressTable
          leads={[sendingLead]}
          onRunLead={mockOnRunLead}
          onSendEmail={mockOnSendEmail}
          onLeadClick={mockOnLeadClick}
          onStageClick={mockOnStageClick}
          selectedLeads={mockSelectedLeads}
          sendingLeadId={87} // This lead is being sent
        />
      )

      const buttons = screen.getAllByRole('button')
      const actionButton = buttons.find(btn => {
        const title = btn.getAttribute('title')
        return title && (title.includes('Resend') || title.includes('Send') || title.includes('sending'))
      })

      expect(actionButton).toBeInTheDocument()
      expect(actionButton).toBeDisabled()
    })
  })
})

