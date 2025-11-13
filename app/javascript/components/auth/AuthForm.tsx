import React from 'react';
import AuthToggleButton from './AuthToggleButton';
import AuthInput from './AuthInput';

interface AuthFormProps {
  mode: 'login' | 'signup';
  formData: {
    email: string;
    password: string;
    password_confirmation: string;
    first_name: string;
    last_name: string;
    workspace_name: string;
    job_title: string;
  };
  formErrors: Record<string, string>;
  flashAlert?: string;
  flashNotice?: string;
  authenticityToken?: string;
  onModeChange: (mode: 'login' | 'signup') => void;
  onInputChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
}

const AuthForm: React.FC<AuthFormProps> = ({
  mode,
  formData,
  formErrors,
  flashAlert,
  flashNotice,
  authenticityToken,
  onModeChange,
  onInputChange,
}) => {
  const getFormAction = () => {
    return mode === 'login' ? '/login' : '/signup';
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    if (mode === 'signup') {
      // Add first_name and last_name as separate fields
      const firstNameField = document.createElement('input');
      firstNameField.type = 'hidden';
      firstNameField.name = 'first_name';
      firstNameField.value = formData.first_name;
      e.currentTarget.appendChild(firstNameField);

      const lastNameField = document.createElement('input');
      lastNameField.type = 'hidden';
      lastNameField.name = 'last_name';
      lastNameField.value = formData.last_name;
      e.currentTarget.appendChild(lastNameField);

      // Add workspace_name and job_title
      const workspaceField = document.createElement('input');
      workspaceField.type = 'hidden';
      workspaceField.name = 'workspace_name';
      workspaceField.value = formData.workspace_name;
      e.currentTarget.appendChild(workspaceField);

      const jobTitleField = document.createElement('input');
      jobTitleField.type = 'hidden';
      jobTitleField.name = 'job_title';
      jobTitleField.value = formData.job_title;
      e.currentTarget.appendChild(jobTitleField);
    }
    // Form will submit normally
  };

  return (
    <section className="w-full flex items-center">
      <div className="w-full rounded-3xl border border-slate-200 bg-white/95 backdrop-blur-2xl p-5 md:p-6 shadow-2xl shadow-slate-200/90 flex flex-col gap-5">
        {/* Mode toggle */}
        <div className="flex gap-2 p-1 rounded-2xl border border-slate-200 bg-slate-100">
          <AuthToggleButton
            label="Log In"
            active={mode === "login"}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onModeChange("login");
            }}
          />
          <AuthToggleButton
            label="Sign Up"
            active={mode === "signup"}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onModeChange("signup");
            }}
          />
        </div>

        <div className="flex flex-col gap-4">
          <div>
            <h2 className="text-lg md:text-xl font-semibold text-slate-900 mb-1">
              {mode === "login" ? "Welcome back" : "Create your workspace"}
            </h2>
            <p className="text-[11px] md:text-xs text-slate-600">
              {mode === "login"
                ? "Sign in to view your campaigns, monitor agents, and keep your outreach in one focused lane."
                : "Spin up a new space for your team, connect email, and launch your first AI-powered campaign in minutes."}
            </p>
          </div>

          <form 
            action={getFormAction()} 
            method="post"
            onSubmit={handleSubmit}
            className="flex flex-col gap-3"
          >
            {authenticityToken && (
              <input type="hidden" name="authenticity_token" value={authenticityToken} />
            )}

            {mode === "signup" && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <AuthInput
                  label="First name"
                  name="first_name"
                  placeholder="Jane"
                  value={formData.first_name}
                  onChange={onInputChange}
                  required
                  autoComplete="given-name"
                  error={formErrors['first_name'] || formErrors['user[first_name]']}
                />
                <AuthInput
                  label="Last name"
                  name="last_name"
                  placeholder="Doe"
                  value={formData.last_name}
                  onChange={onInputChange}
                  required
                  autoComplete="family-name"
                  error={formErrors['last_name'] || formErrors['user[last_name]']}
                />
              </div>
            )}

            <AuthInput
              label="Work email"
              type="email"
              name="user[email]"
              placeholder="you@company.com"
              value={formData.email}
              onChange={onInputChange}
              required
              autoComplete="email"
              error={formErrors['email'] || formErrors['user[email]']}
            />

            <AuthInput
              label="Password"
              type="password"
              name="user[password]"
              placeholder="••••••••"
              value={formData.password}
              onChange={onInputChange}
              required
              autoComplete={mode === "login" ? "current-password" : "new-password"}
              error={formErrors['password'] || formErrors['user[password]']}
            />

            {mode === "signup" && (
              <>
                <AuthInput
                  label="Password confirmation"
                  type="password"
                  name="user[password_confirmation]"
                  placeholder="••••••••"
                  value={formData.password_confirmation}
                  onChange={onInputChange}
                  required
                  autoComplete="new-password"
                  error={formErrors['password_confirmation'] || formErrors['user[password_confirmation]']}
                />
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <AuthInput
                    label="Workspace name"
                    name="workspace_name"
                    placeholder="e.g. Stackly Growth"
                    value={formData.workspace_name}
                    onChange={onInputChange}
                    required
                    autoComplete="organization"
                    error={formErrors['workspace_name'] || formErrors['user[workspace_name]']}
                  />
                  <AuthInput
                    label="Job Title / Position"
                    name="job_title"
                    placeholder="e.g. Growth Lead"
                    value={formData.job_title}
                    onChange={onInputChange}
                    required
                    autoComplete="organization-title"
                    error={formErrors['job_title'] || formErrors['user[job_title]']}
                  />
                </div>
              </>
            )}

            {mode === "login" && (
              <div className="flex items-center justify-between text-[10px] md:text-[11px]">
                <label className="flex items-center gap-2 text-slate-600">
                  <input
                    type="checkbox"
                    name="user[remember_me]"
                    className="h-3 w-3 rounded border border-slate-300 bg-white"
                  />
                  <span>Remember me</span>
                </label>
                <a 
                  href="/users/password/new" 
                  className="text-[#004dff] hover:underline"
                >
                  Forgot password?
                </a>
              </div>
            )}

            {mode === "signup" && (
              <label className="flex items-start gap-2 text-[10px] md:text-[11px] text-slate-600 mt-1">
                <input
                  type="checkbox"
                  name="user[terms]"
                  className="mt-[3px] h-3 w-3 rounded border border-slate-300 bg-white"
                />
                <span>
                  I agree to the Terms and understand agents will only send
                  emails after my explicit approval.
                </span>
              </label>
            )}

            {(flashAlert || (Object.keys(formErrors).length > 0 && !Object.keys(formErrors).some(k => k.startsWith('user[')))) && (
              <div className="rounded-xl bg-red-50 border border-red-200 p-3 text-xs text-red-700">
                {flashAlert || Object.values(formErrors)[0]}
              </div>
            )}
            {flashNotice && (
              <div className="rounded-xl bg-emerald-50 border border-emerald-200 p-3 text-xs text-emerald-700">
                {flashNotice}
              </div>
            )}

            <button
              type="submit"
              className="mt-2 w-full rounded-2xl border border-[#004dff] bg-[#004dff] text-white font-medium text-sm py-2.5 transition-all"
            >
              {mode === "login" ? "Log in to Campaigns" : "Create workspace"}
            </button>
          </form>
        </div>
      </div>
    </section>
  );
};

export default AuthForm;

