import React from 'react';
import Cube from '@/components/shared/Cube';

const AuthNavbar: React.FC = () => {
  return (
    <nav className="bg-transparent shadow-sm relative z-[10000]">
      <div className="w-full px-2 sm:px-4 lg:px-12 xl:px-16 py-4">
        <div className="flex justify-between">
          <div className="flex items-center">
            <a href="/login" className="flex-shrink-0 flex items-center px-6 sm:px-8 md:px-10 gap-4 md:gap-5">
              <Cube />
              <div className="flex flex-col">
                <span className="text-xs uppercase tracking-[0.2em] text-slate-500">
                  Campaign AI
                </span>
                <span className="text-sm md:text-base font-semibold text-slate-900">
                  Multi-Agent Outreach Studio
                </span>
              </div>
            </a>
          </div>
          <div className="flex items-center gap-3 text-xs md:text-sm">
            <button 
              type="button"
              className="px-4 py-2 rounded-2xl border border-[#004dff] bg-[#004dff] text-white font-medium transition-all"
            >
              View Demo
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default AuthNavbar;

