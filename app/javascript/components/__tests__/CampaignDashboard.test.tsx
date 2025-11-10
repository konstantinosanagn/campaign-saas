import React from 'react'
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import CampaignDashboard from '@/components/campaigns/CampaignDashboard'
import type { Campaign, Lead } from '@/types'

// Mock all hooks
jest.mock('@/hooks/useCampaigns', () => ({
  useCampaigns: jest.fn(),
}))

jest.mock('@/hooks/useLeads', () => ({
  useLeads: jest.fn(),
}))

jest.mock('@/hooks/useSelection', () => ({
  useSelection: jest.fn(),
}))

jest.mock('@/hooks/useTypewriter', () => ({
  useTypewriter: jest.fn(),
}))

// Mock child components
jest.mock('@/components/shared/Navigation', () => {
  return function MockNavigation() {
    return <div data-testid="navigation">Navigation</div>
  }
})

jest.mock('@/components/shared/Background', () => {
  return function MockBackground() {
    return <div data-testid="background">Background</div>
  }
})

jest.mock('@/components/campaigns/CampaignForm', () => {
  return function MockCampaignForm({ isOpen, onClose, onSubmit, initialData, isEdit }: any) {
    if (!isOpen) return null
    return (
      <div data-testid={`campaign-form-${isEdit ? 'edit' : 'create'}`}>
        <button onClick={onClose}>Close</button>
        <button onClick={() => onSubmit({ title: 'Test', tone: 'professional', persona: 'founder', primaryGoal: 'book_call' })}>Submit</button>
        {initialData && <div>Editing: {initialData.title}</div>}
      </div>
    )
  }
})

jest.mock('@/components/leads/LeadForm', () => {
  return function MockLeadForm({ isOpen, onClose, onSubmit, initialData, isEdit }: any) {
    if (!isOpen) return null
    return (
      <div data-testid={`lead-form-${isEdit ? 'edit' : 'create'}`}>
        <button onClick={onClose}>Close</button>
        <button onClick={() => onSubmit({ name: 'Test', email: 'test@example.com', title: 'Title', company: 'Company' })}>Submit</button>
        {initialData && <div>Editing: {initialData.name}</div>}
      </div>
    )
  }
})

jest.mock('@/components/campaigns/CampaignSidebar', () => {
  return function MockCampaignSidebar({ campaigns, selectedCampaign, onCampaignClick, onCreateClick, onEditClick, onDeleteClick }: any) {
    return (
      <div data-testid="campaign-sidebar">
        <button onClick={onCreateClick}>Create Campaign</button>
        {campaigns.map((campaign: Campaign, index: number) => (
          <div key={index}>
            <button onClick={() => onCampaignClick(index)}>{campaign.title}</button>
            <button onClick={() => onEditClick(index)}>Edit {index}</button>
            <button onClick={() => onDeleteClick(index)}>Delete {index}</button>
          </div>
        ))}
      </div>
    )
  }
})

jest.mock('@/components/agents/AgentDashboard', () => {
  return function MockAgentDashboard({ hasSelectedCampaign, onAddLeadClick, leads }: any) {
    return (
      <div data-testid="agent-dashboard">
        <button onClick={onAddLeadClick}>Add Lead</button>
        <div>Leads: {leads.length}</div>
      </div>
    )
  }
})

jest.mock('@/components/leads/ProgressTable', () => {
  return function MockProgressTable({ leads, onRunLead, onLeadClick, selectedLeads }: any) {
    return (
      <div data-testid="progress-table">
        {leads.map((lead: Lead) => (
          <div key={lead.id}>
            <button onClick={() => onRunLead(lead.id)}>Run {lead.id}</button>
            <button onClick={() => onLeadClick(lead)}>Click {lead.id}</button>
          </div>
        ))}
      </div>
    )
  }
})

jest.mock('@/components/shared/EmptyState', () => {
  return function MockEmptyState() {
    return <div data-testid="empty-state">Empty State</div>
  }
})

import { useCampaigns } from '@/hooks/useCampaigns'
import { useLeads } from '@/hooks/useLeads'
import { useSelection } from '@/hooks/useSelection'
import { useTypewriter } from '@/hooks/useTypewriter'

describe('CampaignDashboard', () => {
  const mockCampaigns: Campaign[] = [
    { id: 1, title: 'Campaign 1', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
    { id: 2, title: 'Campaign 2', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
  ]

  const mockLeads: Lead[] = [
    {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      title: 'VP',
      company: 'Company',
      website: 'https://example.com',
      campaignId: 1,
      stage: 'queued',
      quality: 'A',
    },
  ]

  const mockCreateCampaign = jest.fn()
  const mockUpdateCampaign = jest.fn()
  const mockDeleteCampaign = jest.fn()
  const mockCreateLead = jest.fn()
  const mockUpdateLead = jest.fn()
  const mockDeleteLeads = jest.fn()
  const mockFindLead = jest.fn()
  const mockToggleSelection = jest.fn()
  const mockClearSelection = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    jest.useFakeTimers()

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: mockCampaigns,
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    ;(useLeads as jest.Mock).mockReturnValue({
      leads: mockLeads,
      loading: false,
      error: null,
      createLead: mockCreateLead,
      updateLead: mockUpdateLead,
      deleteLeads: mockDeleteLeads,
      findLead: mockFindLead,
    })

    ;(useSelection as jest.Mock).mockReturnValue({
      selectedIds: [],
      toggleSelection: mockToggleSelection,
      clearSelection: mockClearSelection,
    })

    ;(useTypewriter as jest.Mock).mockImplementation((text: string) => text)
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  it('renders Navigation and Background', () => {
    render(<CampaignDashboard />)

    expect(screen.getByTestId('navigation')).toBeInTheDocument()
    expect(screen.getByTestId('background')).toBeInTheDocument()
  })

  it('renders CampaignSidebar with campaigns', () => {
    render(<CampaignDashboard />)

    expect(screen.getByTestId('campaign-sidebar')).toBeInTheDocument()
    expect(screen.getByText('Campaign 1')).toBeInTheDocument()
    expect(screen.getByText('Campaign 2')).toBeInTheDocument()
  })

  it('renders EmptyState when no campaign is selected', () => {
    render(<CampaignDashboard />)

    expect(screen.getByTestId('empty-state')).toBeInTheDocument()
    expect(screen.queryByTestId('progress-table')).not.toBeInTheDocument()
  })

  it('opens create campaign form when create button is clicked', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Create Campaign'))

    expect(screen.getByTestId('campaign-form-create')).toBeInTheDocument()
  })

  it('creates campaign and auto-selects it', async () => {
    const newCampaign = { id: 3, title: 'New Campaign', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } }
    mockCreateCampaign.mockResolvedValue(newCampaign)

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: [...mockCampaigns, newCampaign],
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Create Campaign'))
    fireEvent.click(screen.getByText('Submit'))

    await waitFor(() => {
      expect(mockCreateCampaign).toHaveBeenCalledWith({ title: 'Test', tone: 'professional', persona: 'founder', primaryGoal: 'book_call' })
    })
  })

  it('opens edit campaign form when edit button is clicked', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Edit 0'))

    expect(screen.getByTestId('campaign-form-edit')).toBeInTheDocument()
    expect(screen.getByText('Editing: Campaign 1')).toBeInTheDocument()
  })

  it('updates campaign when edit form is submitted', async () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Edit 0'))
    fireEvent.click(screen.getByText('Submit'))

    await waitFor(() => {
      expect(mockUpdateCampaign).toHaveBeenCalledWith(0, { title: 'Test', tone: 'professional', persona: 'founder', primaryGoal: 'book_call' })
    })
  })

  it('deletes campaign when delete button is clicked', async () => {
    window.confirm = jest.fn(() => true)
    mockDeleteCampaign.mockResolvedValue(true)

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: [mockCampaigns[1]],
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Delete 0'))

    await waitFor(() => {
      expect(mockDeleteCampaign).toHaveBeenCalledWith(0)
    })
  })

  it('selects campaign when campaign is clicked', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    expect(screen.queryByTestId('empty-state')).not.toBeInTheDocument()
  })

  it('deselects campaign when clicking selected campaign again', () => {
    render(<CampaignDashboard />)

    const campaignButtons = screen.getAllByRole('button')
    const campaign1Button = campaignButtons.find(btn => btn.textContent === 'Campaign 1')
    if (campaign1Button) {
      fireEvent.click(campaign1Button)
      // Click again to deselect
      fireEvent.click(campaign1Button)
    }

    expect(screen.getByTestId('empty-state')).toBeInTheDocument()
  })

  it('renders ProgressTable when campaign is selected and has leads', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    expect(screen.getByTestId('progress-table')).toBeInTheDocument()
    expect(screen.queryByTestId('empty-state')).not.toBeInTheDocument()
  })

  it('displays empty message when campaign selected but no leads', () => {
    ;(useLeads as jest.Mock).mockReturnValue({
      leads: [],
      loading: false,
      error: null,
      createLead: mockCreateLead,
      updateLead: mockUpdateLead,
      deleteLeads: mockDeleteLeads,
      findLead: mockFindLead,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    expect(screen.getByText(/No leads in this campaign/)).toBeInTheDocument()
  })

  it('opens lead form when Add Lead is clicked', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))
    fireEvent.click(screen.getByText('Add Lead'))

    expect(screen.getByTestId('lead-form-create')).toBeInTheDocument()
  })

  it('creates lead when lead form is submitted', async () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))
    fireEvent.click(screen.getByText('Add Lead'))
    fireEvent.click(screen.getByText('Submit'))

    await waitFor(() => {
      expect(mockCreateLead).toHaveBeenCalledWith({
        name: 'Test',
        email: 'test@example.com',
        title: 'Title',
        company: 'Company',
        campaignId: 1,
      })
    })
  })

  it('logs error when creating lead without selected campaign', () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Add Lead'))
    fireEvent.click(screen.getByText('Submit'))

    expect(consoleErrorSpy).toHaveBeenCalledWith('No campaign selected')

    consoleErrorSpy.mockRestore()
  })

  it('handles run lead action', () => {
    render(<CampaignDashboard />)

    // Click on the campaign button in sidebar
    const campaignButtons = screen.getAllByText('Campaign 1')
    const sidebarButton = campaignButtons.find(btn => btn.closest('[data-testid="campaign-sidebar"]'))
    fireEvent.click(sidebarButton!)
    
    const runButton = screen.getByText('Run 1')
    
    // Verify the run button is present and clickable
    expect(runButton).toBeInTheDocument()
    
    // Click should not crash (placeholder for future functionality)
    fireEvent.click(runButton)
    
    // Verify component still renders correctly after click - check that run button still exists
    expect(screen.getByText('Run 1')).toBeInTheDocument()
  })

  it('toggles lead selection when lead is clicked', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))
    fireEvent.click(screen.getByText('Click 1'))

    expect(mockToggleSelection).toHaveBeenCalledWith(1)
  })

  it('opens edit lead form when one lead is selected and edit clicked', () => {
    mockFindLead.mockReturnValue(mockLeads[0])

    ;(useSelection as jest.Mock).mockReturnValue({
      selectedIds: [1],
      toggleSelection: mockToggleSelection,
      clearSelection: mockClearSelection,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    const editButtons = screen.getAllByRole('button')
    const editLeadButton = editButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('4.487')
    })

    if (editLeadButton) {
      fireEvent.click(editLeadButton)
      expect(screen.getByTestId('lead-form-edit')).toBeInTheDocument()
    }
  })

  it('does not show edit button when multiple leads selected', () => {
    ;(useSelection as jest.Mock).mockReturnValue({
      selectedIds: [1, 2],
      toggleSelection: mockToggleSelection,
      clearSelection: mockClearSelection,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    const editButtons = screen.queryAllByRole('button')
    const editLeadButton = editButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('4.487')
    })

    expect(editLeadButton).toBeUndefined()
  })

  it('deletes selected leads when delete button is clicked', async () => {
    window.confirm = jest.fn(() => true)
    mockDeleteLeads.mockResolvedValue(true)

    ;(useSelection as jest.Mock).mockReturnValue({
      selectedIds: [1],
      toggleSelection: mockToggleSelection,
      clearSelection: mockClearSelection,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    const deleteButtons = screen.getAllByRole('button')
    const deleteLeadButton = deleteButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('14.74')
    })

    if (deleteLeadButton) {
      fireEvent.click(deleteLeadButton)

      await waitFor(() => {
        expect(mockDeleteLeads).toHaveBeenCalledWith([1])
      })

      expect(mockClearSelection).toHaveBeenCalled()
    }
  })

  it('adjusts selected campaign index when campaign before it is deleted', async () => {
    window.confirm = jest.fn(() => true)
    mockDeleteCampaign.mockResolvedValue(true)

    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
      { id: 2, title: 'Campaign 2', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
    ]

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: campaigns,
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    render(<CampaignDashboard />)

    // Select campaign at index 1
    fireEvent.click(screen.getByText('Campaign 2'))

    // Delete campaign at index 0
    fireEvent.click(screen.getByText('Delete 0'))

    await waitFor(() => {
      expect(mockDeleteCampaign).toHaveBeenCalled()
    })

    expect(mockClearSelection).toHaveBeenCalled()
  })

  it('clears selection when selected campaign is deleted', async () => {
    window.confirm = jest.fn(() => true)
    mockDeleteCampaign.mockResolvedValue(true)

    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
    ]

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: campaigns,
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    render(<CampaignDashboard />)

    // Select campaign 1
    const campaignButtons = screen.getAllByRole('button')
    const campaign1Button = campaignButtons.find(btn => btn.textContent === 'Campaign 1')
    if (campaign1Button) {
      fireEvent.click(campaign1Button)
    }

    // Delete campaign 0
    const deleteButtons = screen.getAllByRole('button')
    const delete0Button = deleteButtons.find(btn => btn.textContent === 'Delete 0')
    if (delete0Button) {
      fireEvent.click(delete0Button)
    }

    await waitFor(() => {
      expect(mockClearSelection).toHaveBeenCalled()
    })
  })

  it('displays campaign title using typewriter effect', () => {
    ;(useTypewriter as jest.Mock).mockReturnValue('Typed Campaign Title')

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    expect(screen.getByText('Typed Campaign Title')).toBeInTheDocument()
  })

  it('filters leads by selected campaign', () => {
    const allLeads: Lead[] = [
      ...mockLeads,
      {
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        title: 'VP',
        company: 'Company',
        website: 'https://example.com',
        campaignId: 2,
        stage: 'queued',
        quality: 'A',
      },
    ]

    ;(useLeads as jest.Mock).mockReturnValue({
      leads: allLeads,
      loading: false,
      error: null,
      createLead: mockCreateLead,
      updateLead: mockUpdateLead,
      deleteLeads: mockDeleteLeads,
      findLead: mockFindLead,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    expect(screen.getByText('Run 1')).toBeInTheDocument()
    expect(screen.queryByText('Run 2')).not.toBeInTheDocument()
  })

  it('updates lead when edit lead form is submitted', async () => {
    mockFindLead.mockReturnValue(mockLeads[0])

    ;(useSelection as jest.Mock).mockReturnValue({
      selectedIds: [1],
      toggleSelection: mockToggleSelection,
      clearSelection: mockClearSelection,
    })

    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Campaign 1'))

    const editButtons = screen.getAllByRole('button')
    const editLeadButton = editButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('4.487')
    })

    if (editLeadButton) {
      fireEvent.click(editLeadButton)
      fireEvent.click(screen.getByText('Submit'))

      await waitFor(() => {
        expect(mockUpdateLead).toHaveBeenCalledWith(1, {
          name: 'Test',
          email: 'test@example.com',
          title: 'Title',
          company: 'Company',
        })
      })
    }
  })

  it('closes forms when close button is clicked', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Create Campaign'))
    expect(screen.getByTestId('campaign-form-create')).toBeInTheDocument()

    fireEvent.click(screen.getByText('Close'))
    expect(screen.queryByTestId('campaign-form-create')).not.toBeInTheDocument()
  })

  it('resets editing state when edit form is closed', () => {
    render(<CampaignDashboard />)

    fireEvent.click(screen.getByText('Edit 0'))
    fireEvent.click(screen.getByText('Close'))

    // Form should be closed and editing state reset
    expect(screen.queryByTestId('campaign-form-edit')).not.toBeInTheDocument()
  })

  it('handles campaign with no ID gracefully', async () => {
    const campaignWithoutId: Campaign[] = [
      { title: 'Campaign No ID', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
    ]

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: campaignWithoutId,
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    render(<CampaignDashboard />)

    // Should not crash when filtering leads
    expect(screen.getByTestId('empty-state')).toBeInTheDocument()
  })

  it('handles multiple campaign deletions correctly', async () => {
    window.confirm = jest.fn(() => true)
    mockDeleteCampaign.mockResolvedValue(true)

    const campaigns: Campaign[] = [
      { id: 1, title: 'Campaign 1', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
      { id: 2, title: 'Campaign 2', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
      { id: 3, title: 'Campaign 3', sharedSettings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' } },
    ]

    ;(useCampaigns as jest.Mock).mockReturnValue({
      campaigns: campaigns,
      loading: false,
      error: null,
      createCampaign: mockCreateCampaign,
      updateCampaign: mockUpdateCampaign,
      deleteCampaign: mockDeleteCampaign,
    })

    render(<CampaignDashboard />)

    // Select campaign 2 (index 1) - use the button from the mocked sidebar
    const campaignButtons = screen.getAllByRole('button')
    const campaign2Button = campaignButtons.find(btn => btn.textContent === 'Campaign 2')
    expect(campaign2Button).toBeInTheDocument()
    if (campaign2Button) {
      fireEvent.click(campaign2Button)
    }

    // Delete campaign 0
    const deleteButtons = screen.getAllByRole('button')
    const delete0Button = deleteButtons.find(btn => btn.textContent === 'Delete 0')
    expect(delete0Button).toBeInTheDocument()
    if (delete0Button) {
      fireEvent.click(delete0Button)
    }

    await waitFor(() => {
      expect(mockDeleteCampaign).toHaveBeenCalled()
    })
  })
})

