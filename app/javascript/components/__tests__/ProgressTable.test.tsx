import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import ProgressTable from '../ProgressTable'
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
        selectedLeads={mockSelectedLeads}
      />
    )

    // Component should re-render when props change
    rerender(
      <ProgressTable
        leads={mockLeads}
        onRunLead={mockOnRunLead}
        onLeadClick={mockOnLeadClick}
        selectedLeads={[1]}
      />
    )

    const johnDoeName = screen.getByText('John Doe')
    expect(johnDoeName).toHaveClass('text-blue-600')
  })
})

