import React, { useState, useEffect } from "react";

interface EmailConfigResponse {
  email: string;
  has_app_password: boolean;
  requires_2fa: boolean;
  app_password_link?: string;
}

interface EmailConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function EmailConfigModal({ isOpen, onClose }: EmailConfigModalProps) {
  const [email, setEmail] = useState("");
  const [appPassword, setAppPassword] = useState("");

  const [requires2FA, setRequires2FA] = useState(false);
  const [appPasswordLink, setAppPasswordLink] = useState("");
  const [hasAppPassword, setHasAppPassword] = useState(false);

  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) loadConfig();
  }, [isOpen]);

  const loadConfig = async () => {
    try {
      setLoading(true);
      setError(null);

      const res = await fetch("/api/v1/email_config");
      if (!res.ok) throw new Error("Failed to load");

      const data: EmailConfigResponse = await res.json();

      setEmail(data.email);
      setHasAppPassword(data.has_app_password);
      setRequires2FA(data.requires_2fa);
      setAppPasswordLink(data.app_password_link || "");
      setAppPassword("");
    } catch {
      setError("Failed to load email settings");
    } finally {
      setLoading(false);
    }
  };

  const saveEmailSettings = async () => {
    setSaving(true);
    setError(null);

    const res = await fetch("/api/v1/email_config", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: email,
        app_password: appPassword || null
      })
    });

    const json = await res.json();
    if (!res.ok) {
      setError(json.error || "Failed to save settings");
    } else {
      // loadConfig();
      onClose();
    }

    setSaving(false);
  };

  if (!isOpen) return null;

  // True when app password is required but user hasn't provided one yet
  const isMissingRequiredAppPassword =
    requires2FA && !hasAppPassword && !appPassword;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
        <h2 className="text-xl font-semibold mb-4 text-gray-900">Email Configuration</h2>


        {loading ? (
          <p className="text-gray-500">Loading…</p>
        ) : (
          <>
            {/* Email */}
            <label className="block text-sm font-medium text-gray-700 mb-1">Send From Email</label>
            <input
              type="email"
              className="w-full border border-gray-300 p-2 rounded text-gray-900"
              value={email}
              onChange={e => setEmail(e.target.value)}
            />
            <div className="mt-4">
              {/* App Password */}
              <label className="block text-sm font-medium text-gray-700 mb-1">App Password</label>
              <input
                type="password"
                className="w-full border p-2 rounded mb-2"
                placeholder={hasAppPassword ? "Already saved — enter to replace" : ""}
                value={appPassword}
                onChange={e => setAppPassword(e.target.value)}
              />
            </div>

            {/* 2FA Required */}
            {requires2FA && (
              <div className="p-3 bg-yellow-50 border border-yellow-300 text-yellow-800 rounded mb-3 text-sm">
                <strong>This provider requires a 2FA App Password.</strong>
                <br />
                To generate one, open:
                <br />
                <a
                  href={appPasswordLink}
                  className="text-blue-600 underline"
                  target="_blank"
                  rel="noreferrer"
                >
                  Generate App Password
                </a>
              </div>
            )}

            {/* Hard block if 2FA needed but password missing */}
            {isMissingRequiredAppPassword && (
              <div className="p-3 bg-red-50 border border-red-200 text-red-700 rounded mb-3 text-sm">
                This provider requires an App Password. Please generate one and paste
                it above before sending emails or running a test.
              </div>
            )}

            {/* Errors */}
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 text-red-700 rounded mb-3">
                {error}
              </div>
            )}

            {/* Footer */}
            <div className="flex justify-between">
              <button
                onClick={onClose}
                className="px-4 py-2 bg-gray-200 text-gray-800 rounded"
              >
                Close
              </button>

              <button
                onClick={saveEmailSettings}
                className="px-4 py-2 bg-blue-600 text-white rounded"
                disabled={saving || !email.trim()}
              >
                {saving ? "Saving…" : "Save"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
