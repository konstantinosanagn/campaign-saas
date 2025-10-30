// AgentOutputModal.test.tsx
import React from 'react'
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import AgentOutputModal from '../AgentOutputModal'

const toLocaleSpy = jest.spyOn(Date.prototype, 'toLocaleString').mockReturnValue('LOCAL_TIME')

// Mock window.alert properly for jsdom
Object.defineProperty(window, 'alert', {
  value: jest.fn(),
  writable: true
})

const alertSpy = window.alert as jest.Mock

afterAll(() => {
  toLocaleSpy.mockRestore()
  alertSpy.mockRestore()
})

type AgentOutput = {
  agentName: 'SEARCH' | 'WRITER' | 'CRITIQUE' | 'DESIGNER'
  status: 'queued' | 'completed' | 'failed'
  createdAt: string
  outputData?: any
  errorMessage?: string
}

const baseCreatedAt = '2024-01-02T03:04:05.000Z'

const searchOutput: AgentOutput = {
  agentName: 'SEARCH',
  status: 'completed',
  createdAt: baseCreatedAt,
  outputData: {
    domain: 'example.com',
    sources: [
      { title: 'Doc A', url: 'https://a.example.com', content: 'A content' },
      { title: 'Doc B', url: 'https://b.example.com', content: 'B content' },
    ],
  },
}

const writerOutput: AgentOutput = {
  agentName: 'WRITER',
  status: 'completed',
  createdAt: baseCreatedAt,
  outputData: {
    email: 'Hello from writer',
  },
}

const critiqueWithFeedback: AgentOutput = {
  agentName: 'CRITIQUE',
  status: 'completed',
  createdAt: baseCreatedAt,
  outputData: {
    critique: 'Needs stronger hook in the first sentence.',
  },
}

const critiqueApproved: AgentOutput = {
  agentName: 'CRITIQUE',
  status: 'completed',
  createdAt: baseCreatedAt,
  outputData: {}, // no critique -> approved branch
}

const failedWriter: AgentOutput = {
  agentName: 'WRITER',
  status: 'failed',
  createdAt: baseCreatedAt,
  errorMessage: 'Rate limit hit.',
}

const designerDefault: AgentOutput = {
  agentName: 'DESIGNER', // hits the default JSON rendering path
  status: 'completed',
  createdAt: baseCreatedAt,
  outputData: { banner: true, theme: 'blue' },
}

const fullOutputs: AgentOutput[] = [
  searchOutput,
  writerOutput,
  critiqueWithFeedback,
  critiqueApproved,
  failedWriter,
  designerDefault,
]

describe('AgentOutputModal', () => {
  it('returns null when isOpen=false', () => {
    const { container } = render(
      <AgentOutputModal
        isOpen={false}
        onClose={() => {}}
        leadName="Lead X"
        outputs={[]}
        loading={false}
      />
    )
    expect(container.firstChild).toBeNull()
  })

  it('renders header, tabs (with counts), close button; shows empty state; handles onClose', () => {
    const onClose = jest.fn()
    render(
      <AgentOutputModal
        isOpen
        onClose={onClose}
        leadName="Lead Alpha"
        outputs={[]}
        loading={false}
      />
    )

    // Header + close button
    expect(screen.getByText('Agent Outputs - Lead Alpha')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: '' })) // the header close button (SVG only)
    expect(onClose).toHaveBeenCalled()

    // Tabs with counts
    expect(screen.getByText('All Outputs')).toBeInTheDocument()
    expect(screen.getByText('Search')).toBeInTheDocument()
    expect(screen.getByText('Writer')).toBeInTheDocument()
    expect(screen.getByText('Critique')).toBeInTheDocument()

    // Empty state (outputs=[])
    expect(screen.getByText('No agent outputs available for this lead')).toBeInTheDocument()
  })

  it('shows loading state', () => {
    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Alpha"
        outputs={[]}
        loading
      />
    )
    expect(screen.getByText('Loading outputs...')).toBeInTheDocument()
  })

  it('initializes searchOutputData on open and renders ALL tab (default) with all outputs', () => {
    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead A"
        leadId={42}
        outputs={fullOutputs as any}
        loading={false}
      />
    )

    // ALL tab shows entries; pick a few to validate
    expect(screen.getByText('SEARCH')).toBeInTheDocument()
    expect(screen.getAllByText('WRITER')).toHaveLength(2) // One completed, one failed
    expect(screen.getAllByText('CRITIQUE').length).toBeGreaterThan(0)
    expect(screen.getByText('DESIGNER')).toBeInTheDocument()

    // Date formatting stabilized - check for the actual date format used
    expect(screen.getAllByText(/1\/1\/2024, 10:04:05 PM/).length).toBeGreaterThan(0)

    // SEARCH section (within ALL) shows domain & sources count line
    expect(screen.getByText(/Domain: example\.com/)).toBeInTheDocument()
    expect(screen.getByText(/Found 2 sources/i)).toBeInTheDocument()

    // WRITER completed (non-editing mode) shows the email content
    expect(screen.getByText('Hello from writer')).toBeInTheDocument()

    // CRITIQUE with feedback path
    expect(screen.getByText('Feedback Required')).toBeInTheDocument()
    expect(screen.getByText('Needs stronger hook in the first sentence.')).toBeInTheDocument()

    // CRITIQUE approved (no critique) path
    expect(screen.getByText('Email approved - no feedback provided')).toBeInTheDocument()

    // FAILED path (writer failed)
    expect(screen.getByText('Agent Failed')).toBeInTheDocument()
    expect(screen.getByText('Rate limit hit.')).toBeInTheDocument()

    // DEFAULT JSON path for DESIGNER
    expect(screen.getByText(/"banner": true/)).toBeInTheDocument()
    expect(screen.getByText(/"theme": "blue"/)).toBeInTheDocument()
  })

  it('tab filters: Search / Writer / Critique; shows counts in labels', () => {
    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Tabs"
        leadId={5}
        outputs={fullOutputs as any}
        loading={false}
      />
    )

    // Counts: 6 total; SEARCH 1; WRITER 2 (one completed + one failed); CRITIQUE 2
    expect(screen.getByText('All Outputs (6)')).toBeInTheDocument()
    expect(screen.getByText('Search (1)')).toBeInTheDocument()
    expect(screen.getByText('Writer (2)')).toBeInTheDocument()
    expect(screen.getByText('Critique (2)')).toBeInTheDocument()

    // Switch to SEARCH tab
    fireEvent.click(screen.getByText('Search (1)'))
    // Only search output content visible
    expect(screen.getByText(/Domain: example\.com/)).toBeInTheDocument()
    // Writer/Designer content not displayed inside this filtered section
    expect(screen.queryByText('Hello from writer')).not.toBeInTheDocument()
    expect(screen.queryByText(/"theme": "blue"/)).not.toBeInTheDocument()

    // Switch to WRITER tab
    fireEvent.click(screen.getByText('Writer (2)'))
    expect(screen.getByText('Hello from writer')).toBeInTheDocument()
    // Should not show search domain line in writer-only filter
    expect(screen.queryByText(/Domain:/)).not.toBeInTheDocument()

    // Switch to CRITIQUE tab
    fireEvent.click(screen.getByText('Critique (2)'))
    // Both critique variants appear (feedback + approved)
    expect(screen.getByText('Feedback Required')).toBeInTheDocument()
    expect(screen.getByText('Email approved - no feedback provided')).toBeInTheDocument()
  })

  it('writer: edit -> cancel keeps original; edit -> save calls onUpdateOutput and exits editing', async () => {
    const onUpdateOutput = jest.fn().mockResolvedValue(undefined)

    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Writer"
        leadId={9}
        outputs={[writerOutput] as any}
        loading={false}
        onUpdateOutput={onUpdateOutput}
      />
    )

    // Enter edit mode (button is shown only if leadId & onUpdateOutput are provided)
    const editBtn = screen.getByTitle('Edit email')
    fireEvent.click(editBtn)

    // Wait for the component to initialize the editedEmail state
    await waitFor(() => {
      const textarea = screen.getByPlaceholderText('Edit email content...') as HTMLTextAreaElement
      expect(textarea.value).toBe('Hello from writer')
    })

    // "Save Changes" should be enabled since editedEmail is not empty
    const saveBtn = screen.getByRole('button', { name: /Save Changes/i })
    expect(saveBtn).not.toBeDisabled()

    // Now modify it
    const textarea = screen.getByPlaceholderText('Edit email content...') as HTMLTextAreaElement
    fireEvent.change(textarea, { target: { value: 'Updated email' } })
    expect(saveBtn).not.toBeDisabled()

    // Cancel path (should exit editing and clear state)
    const cancelBtn = screen.getByRole('button', { name: /Cancel/i })
    fireEvent.click(cancelBtn)
    // Back to view mode with original email content
    expect(screen.getByText('Hello from writer')).toBeInTheDocument()

    // Enter edit again and save
    fireEvent.click(screen.getByTitle('Edit email'))
    const textareaAgain = screen.getByPlaceholderText('Edit email content...') as HTMLTextAreaElement
    fireEvent.change(textareaAgain, { target: { value: 'Save this email' } })
    const saveAgain = screen.getByRole('button', { name: /Save Changes/i })
    expect(saveAgain).not.toBeDisabled()

    // Trigger save
    fireEvent.click(saveAgain)

    // While saving, button shows "Saving..."
    await waitFor(() => {
      expect(onUpdateOutput).toHaveBeenCalledWith(9, 'WRITER', 'Save this email')
    })

    // Back to view mode after save
    await waitFor(() => {
      expect(screen.getByText('Hello from writer')).toBeInTheDocument()
    })
  })

  it('writer: save handles failure path (console.error) and stays in edit mode', async () => {
    const onUpdateOutput = jest.fn().mockRejectedValue(new Error('boom'))
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Writer"
        leadId={10}
        outputs={[writerOutput] as any}
        loading={false}
        onUpdateOutput={onUpdateOutput}
      />
    )

    fireEvent.click(screen.getByTitle('Edit email'))
    const textarea = screen.getByPlaceholderText('Edit email content...') as HTMLTextAreaElement
    fireEvent.change(textarea, { target: { value: 'Will fail' } })

    fireEvent.click(screen.getByRole('button', { name: /Save Changes/i }))

    await waitFor(() => {
      expect(onUpdateOutput).toHaveBeenCalledWith(10, 'WRITER', 'Will fail')
    })
    // After failure, editing should remain (Save Changes still visible)
    expect(screen.getByRole('button', { name: /Save Changes/i })).toBeInTheDocument()
    expect(errorSpy).toHaveBeenCalled()

    errorSpy.mockRestore()
  })

  it('writer: edit button is hidden when leadId or onUpdateOutput is missing', () => {
    const { rerender } = render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Writer"
        // Missing leadId & handler -> no edit button
        outputs={[writerOutput] as any}
        loading={false}
      />
    )
    expect(screen.queryByTitle('Edit email')).not.toBeInTheDocument()

    // Provide only leadId (still hidden)
    rerender(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Writer"
        leadId={1}
        outputs={[writerOutput] as any}
        loading={false}
      />
    )
    expect(screen.queryByTitle('Edit email')).not.toBeInTheDocument()

    // Provide only handler (still hidden)
    rerender(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Writer"
        outputs={[writerOutput] as any}
        loading={false}
        onUpdateOutput={jest.fn()}
      />
    )
    expect(screen.queryByTitle('Edit email')).not.toBeInTheDocument()
  })

  it('search: removes a source successfully and calls onUpdateSearchOutput with updated data', async () => {
    const onUpdateSearchOutput = jest.fn().mockResolvedValue(undefined)

    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Search"
        leadId={77}
        outputs={[searchOutput] as any}
        loading={false}
        onUpdateSearchOutput={onUpdateSearchOutput}
      />
    )

    // Initially 2 sources
    expect(screen.getByText(/Found 2 sources/)).toBeInTheDocument()

    // Go to SEARCH tab explicitly (optional; ALL already shows it)
    fireEvent.click(screen.getByText('Search (1)'))

    // Two remove buttons (hover opacity is irrelevant to tests)
    const removeButtons = screen.getAllByTitle('Remove this source')
    expect(removeButtons).toHaveLength(2)

    // Remove the first one
    fireEvent.click(removeButtons[0])

    // UI updates immediately to show 1 source
    await waitFor(() => {
      expect(screen.getByText(/Found 1 sources/)).toBeInTheDocument()
    })

    // Handler called with updated sources array (length 1, with original second item remaining)
    await waitFor(() => {
      expect(onUpdateSearchOutput).toHaveBeenCalledTimes(1)
      const [leadId, agentName, updatedData] = onUpdateSearchOutput.mock.calls[0]
      expect(leadId).toBe(77)
      expect(agentName).toBe('SEARCH')
      expect(updatedData.sources).toHaveLength(1)
      expect(updatedData.sources[0].title).toBe('Doc B')
    })
  })

  it('search: failed removal reverts local state and alerts user', async () => {
    const failing = jest.fn().mockRejectedValue(new Error('remove failed'))

    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Search"
        leadId={88}
        outputs={[searchOutput] as any}
        loading={false}
        onUpdateSearchOutput={failing}
      />
    )

    // 2 sources initially
    expect(screen.getByText(/Found 2 sources/)).toBeInTheDocument()

    const removeButtons = screen.getAllByTitle('Remove this source')
    fireEvent.click(removeButtons[1]) // attempt to remove second

    // UI optimistically shows 1 source
    await waitFor(() => {
      expect(screen.getByText(/Found 1 sources/)).toBeInTheDocument()
    })

    // Then it fails -> revert + alert
    await waitFor(() => {
      expect(failing).toHaveBeenCalled()
    })

    // After failure, we should see reverted count back to 2
    await waitFor(() => {
      expect(screen.getByText(/Found 2 sources/)).toBeInTheDocument()
    })

    expect(alertSpy).toHaveBeenCalled()
  })

  it('search: shows "All sources have been removed" with empty sources array and default domain', () => {
    const searchNoSources: AgentOutput = {
      agentName: 'SEARCH',
      status: 'completed',
      createdAt: baseCreatedAt,
      outputData: {
        // domain intentionally omitted to trigger default 'N/A'
        sources: [],
      },
    }

    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Search Empty"
        leadId={1}
        outputs={[searchNoSources] as any}
        loading={false}
        onUpdateSearchOutput={jest.fn()}
      />
    )

    expect(screen.getByText(/Domain: N\/A/)).toBeInTheDocument()
    expect(screen.getByText('All sources have been removed')).toBeInTheDocument()
  })

  it('writer/search/critique null/invalid outputData is handled gracefully (returns null subtrees)', () => {
    const invalids: AgentOutput[] = [
      { agentName: 'WRITER', status: 'completed', createdAt: baseCreatedAt, outputData: null as any },
      { agentName: 'SEARCH', status: 'completed', createdAt: baseCreatedAt, outputData: 'not-an-object' as any },
      { agentName: 'CRITIQUE', status: 'completed', createdAt: baseCreatedAt, outputData: null as any },
    ]

    render(
      <AgentOutputModal
        isOpen
        onClose={() => {}}
        leadName="Lead Invalids"
        outputs={invalids as any}
        loading={false}
      />
    )

    // They render their cards but the inner formatted content is null (no crash).
    expect(screen.getByText('WRITER')).toBeInTheDocument()
    expect(screen.getByText('SEARCH')).toBeInTheDocument()
    expect(screen.getByText('CRITIQUE')).toBeInTheDocument()
  })
})
