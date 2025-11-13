import React from 'react';

interface AuthInputProps {
  label: string;
  type?: string;
  placeholder?: string;
  name: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
  required?: boolean;
  error?: string;
  autoComplete?: string;
}

const AuthInput: React.FC<AuthInputProps> = ({ 
  label, 
  type = "text", 
  placeholder, 
  name, 
  value, 
  onChange, 
  required, 
  error,
  autoComplete
}) => (
  <label className="flex flex-col gap-1 text-xs md:text-sm text-slate-600">
    <span className="font-medium text-slate-800">{label}</span>
    <input
      type={type}
      name={name}
      placeholder={placeholder}
      value={value}
      onChange={onChange}
      required={required}
      autoComplete={autoComplete}
      className={`w-full rounded-xl bg-white border px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-[#004dff]/70 focus:border-[#004dff] backdrop-blur-md ${
        error ? 'border-red-300' : 'border-slate-200'
      }`}
    />
    {error && <span className="text-xs text-red-600">{error}</span>}
  </label>
);

export default AuthInput;

