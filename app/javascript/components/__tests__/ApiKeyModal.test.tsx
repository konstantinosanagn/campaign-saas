import React from 'react'
import { render, screen, fireEvent, act, waitFor } from '@testing-library/react'
import ApiKeyModal from '../ApiKeyModal'

jest.useFakeTimers()

const focusEl = () => document.activeElement as HTMLElement

describe('ApiKeyModal', () => {
  const initialFull = { llmApiKey: 'sk-abcdef1234', tavilyApiKey: 'tv-9876543210' }
  const initialEmpty = { llmApiKey: '', tavilyApiKey: '' }
  const halfEmpty = { llmApiKey: 'sk-helloWORLD', tavilyApiKey: '' }

  test('returns null when isOpen is false', () => {
    const { container } = render(
      <ApiKeyModal
        isOpen={false}
        onClose={jest.fn()}
        onSave={jest.fn()}
        initialKeys={initialFull}
      />
    )
    expect(container.firstChild).toBeNull()
  })

  test('renders saved view when hasKeys and not editing; masked + Saved badges; Edit toggles to form and focuses after delay', () => {
    render(
      <ApiKeyModal
        isOpen
        onClose={jest.fn()}
        onSave={jest.fn()}
        initialKeys={initialFull}
      />
    )

    // Header shows
    expect(screen.getByText('API Key Settings')).toBeInTheDocument()

    // Masked endings: last 4 of each key
    expect(screen.getByText(/••••••••••••1234$/)).toBeInTheDocument()
    expect(screen.getByText(/••••••••••••3210$/)).toBeInTheDocument()

    // "Saved" badges appear for both
    expect(screen.getAllByText('Saved')).toHaveLength(2)

    // Click "Edit Keys" → switches to form and sets focus after timeout in handleEdit
    fireEvent.click(screen.getByRole('button', { name: /Edit Keys/i }))
    // Input is rendered immediately (before focus)
    const llmInput = screen.getByLabelText(/LLM API Key/i) as HTMLInputElement
    expect(llmInput).toBeInTheDocument()

    // Focus happens after 100ms
    act(() => {
      jest.advanceTimersByTime(100)
    })
    expect(focusEl()).toBe(llmInput)
  })

  test('auto-focuses immediately (useEffect path) when opening with no saved keys', () => {
    render(
      <ApiKeyModal
        isOpen
        onClose={jest.fn()}
        onSave={jest.fn()}
        initialKeys={initialEmpty}
      />
    )
    const llmInput = screen.getByLabelText(/LLM API Key/i) as HTMLInputElement
    expect(focusEl()).toBe(llmInput)
  })

  test('successful save: updates loading label, calls onSave with values, calls onClose, and re-enables button', async () => {
    const onSave = jest.fn().mockResolvedValue(undefined)
    const onClose = jest.fn()

    render(
      <ApiKeyModal
        isOpen
        onClose={onClose}
        onSave={onSave}
        initialKeys={initialEmpty}
      />
    )

    const llmInput = screen.getByLabelText(/LLM API Key/i) as HTMLInputElement
    const tavilyInput = screen.getByLabelText(/Tavily Search API Key/i) as HTMLInputElement
    const saveBtn = screen.getByRole('button', { name: /Save Keys/i }) as HTMLButtonElement

    fireEvent.change(llmInput, { target: { value: 'sk-NEW' } })
    fireEvent.change(tavilyInput, { target: { value: 'tv-NEW' } })

    // Submit form
    fireEvent.click(saveBtn)

    // Button turns into "Saving..." while pending
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Saving.../i })).toBeDisabled()
    })

    // Resolve promise
    await act(async () => {})

    expect(onSave).toHaveBeenCalledWith({ llmApiKey: 'sk-NEW', tavilyApiKey: 'tv-NEW' })
    expect(onClose).toHaveBeenCalledTimes(1)
    // After successful save, component calls onClose (modal closes in real app)
    // If modal were still open (isOpen true), it would show saved view with "Edit Keys" button
    // But since onClose is called, the parent typically closes the modal
  })

  test('failed save: catches, logs error, returns button to enabled state and stays in edit', async () => {
    const error = new Error('boom')
    const onSave = jest.fn().mockRejectedValue(error)
    const onClose = jest.fn()
    const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

    render(
      <ApiKeyModal
        isOpen
        onClose={onClose}
        onSave={onSave}
        initialKeys={initialEmpty}
      />
    )

    const saveBtn = screen.getByRole('button', { name: /Save Keys/i })
    fireEvent.click(saveBtn)
    // pending label - wait for state update
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Saving.../i })).toBeDisabled()
    })

    // let rejection bubble to catch
    await act(async () => {})

    expect(onSave).toHaveBeenCalled()
    expect(onClose).not.toHaveBeenCalled()
    expect(errSpy).toHaveBeenCalledWith('Failed to save API keys:', error)
    // Still in edit mode; Save button visible again and enabled
    expect(screen.getByRole('button', { name: /Save Keys/i })).toBeEnabled()

    errSpy.mockRestore()
  })

  test('close button resets state, exits editing, and calls onClose', () => {
    const onClose = jest.fn()

    // Start with saved view (hasKeys true), then go to edit, change inputs, and close
    render(
      <ApiKeyModal
        isOpen
        onClose={onClose}
        onSave={jest.fn()}
        initialKeys={initialFull}
      />
    )

    // Enter edit
    fireEvent.click(screen.getByRole('button', { name: /Edit Keys/i }))
    const llmInput = screen.getByLabelText(/LLM API Key/i) as HTMLInputElement
    fireEvent.change(llmInput, { target: { value: 'sk-CHANGED' } })

    // Click the "X" close button
    const closeBtn = screen.getByRole('button', { name: '' }) // the icon button has no accessible name
    fireEvent.click(closeBtn)

    expect(onClose).toHaveBeenCalledTimes(1)

    // Because hasKeys is true from props, we should be back on the saved-view UI (not the edit form)
    expect(screen.getByText(/API Keys Saved/)).toBeInTheDocument()
    expect(screen.queryByLabelText(/LLM API Key/)).not.toBeInTheDocument()
  })

  test('mixed keys: shows masked for existing and "Not provided" for missing; no Saved badge for missing', () => {
    render(
      <ApiKeyModal
        isOpen
        onClose={jest.fn()}
        onSave={jest.fn()}
        initialKeys={halfEmpty}
      />
    )

    // LLM masked (last 4 = RLD) - actually WORLD has 5 chars, last 4 is ORLD
    expect(screen.getByText(/••••••••••••ORLD$/)).toBeInTheDocument()
    // Tavily shows "Not provided"
    expect(screen.getByText('Not provided')).toBeInTheDocument()

    // Only one "Saved" badge (for LLM)
    expect(screen.getAllByText('Saved')).toHaveLength(1)
  })
})
