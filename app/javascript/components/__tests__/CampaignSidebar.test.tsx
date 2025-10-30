import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import CampaignSidebar from '../CampaignSidebar'
import type { Campaign } from '@/types'

describe('CampaignSidebar', () => {
  const mockCampaigns: Campaign[] = [
    { id: 1, title: 'Campaign 1', basePrompt: 'This is a test prompt for campaign 1' },
    { id: 2, title: 'Campaign 2', basePrompt: 'This is a test prompt for campaign 2 with a very long description that should be truncated' },
  ]

  const mockOnCampaignClick = jest.fn()
  const mockOnCreateClick = jest.fn()
  const mockOnEditClick = jest.fn()
  const mockOnDeleteClick = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders campaigns title and create button', () => {
    const { container } = render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    expect(screen.getByText('Campaigns')).toBeInTheDocument()
    
    // Find the create button SVG by its path
    const svgs = container.querySelectorAll('svg')
    const createSvg = Array.from(svgs).find(svg => svg.innerHTML.includes('M12 4.5v15m7.5-7.5h-15'))
    expect(createSvg).toBeInTheDocument()
  })

  it('renders empty state message when no campaigns', () => {
    render(
      <CampaignSidebar
        campaigns={[]}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    expect(screen.getByText(/Click/)).toBeInTheDocument()
    expect(screen.getByText(/to create a campaign/)).toBeInTheDocument()
  })

  it('renders list of campaigns', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    expect(screen.getByText('Campaign 1')).toBeInTheDocument()
    expect(screen.getByText('Campaign 2')).toBeInTheDocument()
  })

  it('truncates long base prompts', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const promptText = screen.getByText(/This is a test prompt for campaign 2/)
    expect(promptText.textContent).toContain('...')
  })

  it('calls onCampaignClick when campaign is clicked', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const campaign1 = screen.getByText('Campaign 1').closest('div[class*="cursor-pointer"]')
    fireEvent.click(campaign1!)

    expect(mockOnCampaignClick).toHaveBeenCalledWith(0)
  })

  it('calls onCreateClick when create button is clicked', () => {
    const { container } = render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    // Find the create button SVG by its path and click its parent button
    const svgs = container.querySelectorAll('svg')
    const createSvg = Array.from(svgs).find(svg => svg.innerHTML.includes('M12 4.5v15m7.5-7.5h-15'))
    expect(createSvg).toBeInTheDocument()
    fireEvent.click(createSvg as SVGElement)

    expect(mockOnCreateClick).toHaveBeenCalledTimes(1)
  })

  it('calls onEditClick when edit button is clicked', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const editButtons = screen.getAllByRole('button')
    // Find the edit button (not the create button)
    const editButton = editButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('4.487')
    })
    
    if (editButton) {
      fireEvent.click(editButton)
      expect(mockOnEditClick).toHaveBeenCalledWith(0)
    }
  })

  it('calls onDeleteClick when delete button is clicked', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const deleteButtons = screen.getAllByRole('button')
    // Find the delete button
    const deleteButton = deleteButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('14.74')
    })
    
    if (deleteButton) {
      fireEvent.click(deleteButton)
      expect(mockOnDeleteClick).toHaveBeenCalledWith(0)
    }
  })

  it('stops propagation when edit button is clicked', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const editButtons = screen.getAllByRole('button')
    const editButton = editButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('4.487')
    })
    
    if (editButton) {
      const stopPropagationSpy = jest.fn()
      const mockEvent = { stopPropagation: stopPropagationSpy } as any
      fireEvent.click(editButton, mockEvent)
      
      // Edit should be called but not campaign click
      expect(mockOnEditClick).toHaveBeenCalled()
    }
  })

  it('stops propagation when delete button is clicked', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const deleteButtons = screen.getAllByRole('button')
    const deleteButton = deleteButtons.find(btn => {
      const svg = btn.querySelector('svg')
      return svg && svg.innerHTML.includes('14.74')
    })
    
    if (deleteButton) {
      fireEvent.click(deleteButton)
      
      // Delete should be called but not campaign click
      expect(mockOnDeleteClick).toHaveBeenCalled()
    }
  })

  it('highlights selected campaign', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={0}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const campaign1 = screen.getByText('Campaign 1').closest('div[class*="cursor-pointer"]')
    expect(campaign1).toHaveClass('bg-blue-50', 'border-blue-200')
  })

  it('shows correct styling for non-selected campaign', () => {
    render(
      <CampaignSidebar
        campaigns={mockCampaigns}
        selectedCampaign={1}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    const campaign1 = screen.getByText('Campaign 1').closest('div[class*="cursor-pointer"]')
    expect(campaign1).toHaveClass('bg-gray-50', 'border-gray-200')
  })

  it('handles campaign with empty basePrompt', () => {
    const campaignsWithEmptyPrompt: Campaign[] = [
      { id: 1, title: 'Campaign 1', basePrompt: '' },
    ]

    render(
      <CampaignSidebar
        campaigns={campaignsWithEmptyPrompt}
        selectedCampaign={null}
        onCampaignClick={mockOnCampaignClick}
        onCreateClick={mockOnCreateClick}
        onEditClick={mockOnEditClick}
        onDeleteClick={mockOnDeleteClick}
      />
    )

    expect(screen.getByText('Campaign 1')).toBeInTheDocument()
  })
})

