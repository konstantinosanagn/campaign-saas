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

  const handleGoogleLogin = () => {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = "/users/auth/google_oauth2";

    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content");

    if (csrfToken) {
      const csrfInput = document.createElement("input");
      csrfInput.type = "hidden";
      csrfInput.name = "authenticity_token";
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
    }

    document.body.appendChild(form);
    form.submit();
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

          <div className="mt-4">
            <button
              type="button"
              onClick={handleGoogleLogin}
              className="w-full rounded-2xl border border-slate-300 bg-white text-slate-900 font-medium text-sm py-2.5 transition-all hover:bg-slate-50 flex items-center justify-center gap-2"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              Continue with Google
            </button>
          </div>
        </div>
      </div>
    </section>
  );
};

export default AuthForm;

