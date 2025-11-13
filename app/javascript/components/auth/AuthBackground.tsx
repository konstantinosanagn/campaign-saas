import React from 'react';

const AuthBackground: React.FC = () => {
  return (
    <div className="pointer-events-none fixed inset-0 overflow-hidden -z-10">
      <div className="absolute -top-32 -left-16 h-72 w-72 rounded-full bg-[#004dff]/10 blur-3xl" />
      <div className="absolute top-1/3 -right-10 h-72 w-72 rounded-full bg-[#004dff]/5 blur-3xl" />
      <div className="absolute bottom-0 left-1/4 h-64 w-64 rounded-full bg-emerald-300/10 blur-3xl" />
    </div>
  );
};

export default AuthBackground;

