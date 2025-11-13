import React from 'react';

interface AuthToggleButtonProps {
  active?: boolean;
  label: string;
  onClick: (e: React.MouseEvent<HTMLButtonElement>) => void;
}

const AuthToggleButton: React.FC<AuthToggleButtonProps> = ({ active, label, onClick }) => (
  <button
    type="button"
    onClick={onClick}
    className={`flex-1 rounded-2xl px-3 py-2 text-xs md:text-sm font-medium border transition-all duration-200 ${
      active
        ? "bg-[#004dff] text-white border-[#004dff]"
        : "bg-transparent text-slate-600 border-transparent hover:bg-slate-100"
    }`}
  >
    {label}
  </button>
);

export default AuthToggleButton;

