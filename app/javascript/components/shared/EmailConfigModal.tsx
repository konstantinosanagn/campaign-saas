import React, { useState, useEffect } from 'react'

interface EmailConfigModalProps {
  isOpen: boolean
  onClose: () => void
}

interface EmailConfig {
  email: string
  oauth_configured: boolean
  oauth_url?: string
}

export default function EmailConfigModal({ isOpen, onClose }: EmailConfigModalProps) {
  const [email, setEmail] = useState('')
  const [oauthConfigured, setOauthConfigured] = useState(false)
  const [oauthAvailable, setOauthAvailable] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (isOpen) {
      loadEmailConfig()
      checkOauthStatus()
    }
  }, [isOpen])

  const checkOauthStatus = async () => {
    try {
      const response = await fetch('/api/v1/oauth_status', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        console.log('OAuth status response:', data)
        setOauthAvailable(data.oauth_configured || false)
      } else {
        console.error('OAuth status check failed:', response.status, response.statusText)
        const text = await response.text()
        console.error('Response body:', text)
        setOauthAvailable(false)
      }
    } catch (err) {
      console.error('Error checking OAuth status:', err)
      setOauthAvailable(false)
    }
  }

  const loadEmailConfig = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await fetch('/api/v1/email_config', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        }
      })

      if (response.ok) {
        const data = await response.json() as EmailConfig
        setEmail(data.email || '')
        setOauthConfigured(data.oauth_configured || false)
      } else {
        setError('Failed to load email configuration')
      }
    } catch (err) {
      console.error('Error loading email config:', err)
      setError('Failed to load email configuration')
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    if (!email.trim()) {
      setError('Email is required')
      return
    }

    try {
      setSaving(true)
      setError(null)
      const response = await fetch('/api/v1/email_config', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        },
        body: JSON.stringify({ email: email.trim() })
      })

      if (response.ok) {
        await loadEmailConfig()
        onClose()
      } else {
        const data = await response.json()
        setError(data.error || 'Failed to save email configuration')
      }
    } catch (err) {
      console.error('Error saving email config:', err)
      setError('Failed to save email configuration')
    } finally {
      setSaving(false)
    }
  }

  const handleAuthorizeGmail = async () => {
    try {
      // Check if OAuth is configured by trying to get authorization URL
      // This will fail gracefully if not configured
      window.location.href = '/oauth/gmail/authorize'
    } catch (err) {
      console.error('Error initiating Gmail OAuth:', err)
      setError('Failed to initiate Gmail authorization. Please check if OAuth is configured.')
    }
  }

  const handleRevokeGmail = async () => {
    if (!confirm('Are you sure you want to revoke Gmail OAuth? You will need to re-authorize to send emails.')) {
      return
    }

    try {
      setLoading(true)
      const response = await fetch('/oauth/gmail/revoke', {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        }
      })

      if (response.ok) {
        await loadEmailConfig()
      } else {
        setError('Failed to revoke OAuth')
      }
    } catch (err) {
      console.error('Error revoking OAuth:', err)
      setError('Failed to revoke OAuth')
    } finally {
      setLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Email Configuration</h2>
        </div>

        <div className="px-6 py-4 space-y-4">
          {loading && !saving ? (
            <div className="text-center py-4">
              <div className="text-gray-500">Loading...</div>
            </div>
          ) : (
            <>
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
                  Send From Email Address
                </label>
                <input
                  type="email"
                  id="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-gray-900 outline-none ring-1 ring-transparent transition-colors duration-150 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
                  placeholder="your-email@gmail.com"
                  disabled={saving}
                />
                <p className="mt-1 text-xs text-gray-500">
                  This email will be used as the sender address when sending campaign emails.
                </p>
              </div>

              <div className="border-t border-gray-200 pt-4">
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <h3 className="text-sm font-medium text-gray-900">Gmail OAuth</h3>
                    <p className="text-xs text-gray-500 mt-1">
                      Authorize Gmail to send emails securely without passwords
                    </p>
                  </div>
                  <div className={`px-2 py-1 rounded text-xs font-medium ${
                    oauthConfigured 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-gray-100 text-gray-600'
                  }`}>
                    {oauthConfigured ? 'Authorized' : 'Not Authorized'}
                  </div>
                </div>

                {oauthConfigured ? (
                  <button
                    onClick={handleRevokeGmail}
                    disabled={loading || saving}
                    className="w-full px-4 py-2 text-sm font-medium text-red-700 bg-red-50 border border-red-200 rounded-md hover:bg-red-100 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? 'Revoking...' : 'Revoke Gmail Authorization'}
                  </button>
                ) : (
                  <>
                    {!oauthAvailable && (
                      <div className="mb-3 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                        <p className="text-xs text-yellow-800">
                          ⚠️ Gmail OAuth is not configured. Please contact your administrator to set up GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET.
                        </p>
                      </div>
                    )}
                    <button
                      onClick={handleAuthorizeGmail}
                      disabled={loading || saving || !email.trim() || !oauthAvailable}
                      className="w-full px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-blue-600 rounded-md hover:bg-blue-700 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                      title={!oauthAvailable ? 'Gmail OAuth is not configured by administrator' : !email.trim() ? 'Please enter an email address first' : ''}
                    >
                      Authorize Gmail
                    </button>
                    {oauthAvailable && (
                      <p className="mt-2 text-xs text-gray-500 text-center">
                        Click to authorize sending emails from your Gmail account
                      </p>
                    )}
                  </>
                )}
              </div>

              {error && (
                <div className="bg-red-50 border border-red-200 rounded-md p-3">
                  <p className="text-sm text-red-800">{error}</p>
                </div>
              )}
            </>
          )}
        </div>

        <div className="px-6 py-4 border-t border-gray-200 flex justify-end space-x-3">
          <button
            onClick={onClose}
            disabled={saving || loading}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Close
          </button>
          <button
            onClick={handleSave}
            disabled={saving || loading || !email.trim()}
            className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {saving ? 'Saving...' : 'Save Email'}
          </button>
        </div>
      </div>
    </div>
  )
}

