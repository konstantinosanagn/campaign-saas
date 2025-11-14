import React, { useState } from "react";
import AuthNavbar from './AuthNavbar';
import AuthBackground from './AuthBackground';
import AuthHeroSection from './AuthHeroSection';
import AuthForm from './AuthForm';

interface AuthPageProps {
  initialMode?: 'login' | 'signup';
  errors?: Record<string, string[]>;
  flashAlert?: string;
  flashNotice?: string;
  authenticityToken?: string;
}

const AuthPage: React.FC<AuthPageProps> = ({ 
  initialMode = 'login',
  errors = {},
  flashAlert,
  flashNotice,
  authenticityToken
}) => {
  const [mode, setMode] = useState<"login" | "signup">(initialMode);
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    password_confirmation: '',
    first_name: '',
    last_name: '',
    workspace_name: '',
    job_title: ''
  });
  // Derive form errors directly from the errors prop to avoid extra state updates in effects
  const derivedFormErrors: Record<string, string> = {};
  Object.keys(errors).forEach((key) => {
    if (errors[key] && errors[key].length > 0) {
      derivedFormErrors[key] = errors[key][0];
    }
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    
    // Handle nested names like "user[email]" -> "email"
    let stateKey = name;
    if (name.startsWith('user[') && name.endsWith(']')) {
      stateKey = name.slice(5, -1); // Extract "email" from "user[email]"
    }
    
    setFormData(prev => ({ ...prev, [stateKey]: value }));
    
    // Clear error when user starts typing
    // Clearing errors is handled by derivedFormErrors on the next render
  };

  const handleModeChange = (newMode: 'login' | 'signup') => {
    setMode(newMode);
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col">
      <AuthBackground />
      <AuthNavbar />

      {/* Main content */}
      <main id="auth-main-content" className="flex-1 grid w-full" style={{ gridTemplateColumns: '2fr 5fr 3fr 2fr' }}>
        {/* Empty column - 2 */}
        <div className="border-r border-gray-200"></div>
        
        {/* Promo card and siblings - 5 */}
        <div className="w-full p-4 md:p-6 border-r border-gray-200 flex items-center">
          <AuthHeroSection />
        </div>
        
        {/* Login/Signup cards - 3 */}
        <div className="w-full p-4 md:p-6 border-r border-gray-200 flex items-center">
          <AuthForm
            mode={mode}
            formData={formData}
            formErrors={derivedFormErrors}
            flashAlert={flashAlert}
            flashNotice={flashNotice}
            authenticityToken={authenticityToken}
            onModeChange={handleModeChange}
            onInputChange={handleInputChange}
          />
        </div>
        
        {/* Empty column - 2 */}
        <div></div>
      </main>

      {/* Footer */}
      <footer className="w-full border-t border-gray-200">
        <div className="grid w-full" style={{ gridTemplateColumns: '2fr 5fr 3fr 2fr' }}>
          <div className="border-r border-gray-200"></div>
          <div className="p-4 md:p-6 border-r border-gray-200"></div>
          <div className="p-4 md:p-6 border-r border-gray-200"></div>
          <div></div>
        </div>
      </footer>
    </div>
  );
};

export default AuthPage;
