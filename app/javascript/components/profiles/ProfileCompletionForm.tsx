import React, { useState } from 'react';
import AuthInput from '../auth/AuthInput';

interface ProfileCompletionFormProps {
  user?: {
    first_name?: string;
    last_name?: string;
    email?: string;
    workspace_name?: string;
    job_title?: string;
  };
  errors?: Record<string, string[]>;
  flashAlert?: string;
  flashNotice?: string;
  authenticityToken?: string;
}

const ProfileCompletionForm: React.FC<ProfileCompletionFormProps> = ({
  user = {},
  errors = {},
  flashAlert,
  flashNotice,
  authenticityToken
}) => {
  const [formData, setFormData] = useState({
    workspace_name: user.workspace_name || '',
    job_title: user.job_title || ''
  });

  // Format full name
  const fullName = user.first_name && user.last_name
    ? `${user.first_name} ${user.last_name}`
    : user.first_name || user.last_name || '';

  // Read-only input component
  const ReadOnlyField: React.FC<{ label: string; value: string }> = ({ label, value }) => (
    <label className="flex flex-col gap-1 text-xs md:text-sm text-slate-600">
      <span className="font-medium text-slate-800">{label}</span>
      <div className="w-full rounded-xl bg-slate-100 border border-slate-200 px-3 py-2 text-sm text-slate-600">
        {value || '—'}
      </div>
    </label>
  );

  // Derive form errors directly from the errors prop
  const derivedFormErrors: Record<string, string> = {};
  Object.keys(errors).forEach((key) => {
    if (errors[key] && errors[key].length > 0) {
      derivedFormErrors[key] = errors[key][0];
    }
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    // Extract the field name from "user[field_name]" format
    const fieldName = name.replace('user[', '').replace(']', '');
    setFormData(prev => ({ ...prev, [fieldName]: value }));
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex items-center justify-center p-4">
      <section className="w-full max-w-md">
        <div className="w-full rounded-3xl border border-slate-200 bg-white/95 backdrop-blur-2xl p-5 md:p-6 shadow-2xl shadow-slate-200/90 flex flex-col gap-5">
          <div className="flex flex-col gap-4">
            <div>
              <h2 className="text-lg md:text-xl font-semibold text-slate-900 mb-1">
                Complete your profile
              </h2>
              <p className="text-[11px] md:text-xs text-slate-600">
                Just a few more details to get you started with your AI-powered campaigns.
              </p>
            </div>

            <form 
              action="/complete-profile" 
              method="post"
              className="flex flex-col gap-3"
            >
              {authenticityToken && (
                <input type="hidden" name="authenticity_token" value={authenticityToken} />
              )}
              <input type="hidden" name="_method" value="patch" />

              <ReadOnlyField
                label="Name"
                value={fullName}
              />

              <ReadOnlyField
                label="Email"
                value={user.email || ''}
              />

              <AuthInput
                label="Workspace name"
                name="user[workspace_name]"
                placeholder="e.g. Stackly Growth"
                value={formData.workspace_name}
                onChange={handleInputChange}
                required
                autoComplete="organization"
                error={derivedFormErrors['workspace_name'] || derivedFormErrors['user[workspace_name]']}
              />

              <AuthInput
                label="Job Title / Position"
                name="user[job_title]"
                placeholder="e.g. Growth Lead"
                value={formData.job_title}
                onChange={handleInputChange}
                required
                autoComplete="organization-title"
                error={derivedFormErrors['job_title'] || derivedFormErrors['user[job_title]']}
              />

              {(flashAlert || (Object.keys(derivedFormErrors).length > 0 && !Object.keys(derivedFormErrors).some(k => k.startsWith('user[')))) && (
                <div className="rounded-xl bg-red-50 border border-red-200 p-3 text-xs text-red-700">
                  {flashAlert || Object.values(derivedFormErrors)[0]}
                </div>
              )}
              {flashNotice && (
                <div className="rounded-xl bg-emerald-50 border border-emerald-200 p-3 text-xs text-emerald-700">
                  {flashNotice}
                </div>
              )}

              <button
                type="submit"
                className="mt-2 w-full rounded-2xl border border-[#004dff] bg-[#004dff] text-white font-medium text-sm py-2.5 transition-all hover:bg-[#003dcc]"
              >
                Complete Profile
              </button>
            </form>
          </div>
        </div>
      </section>
    </div>
  );
};

export default ProfileCompletionForm;
