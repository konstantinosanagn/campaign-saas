import React from 'react';
import TypewriterText from './TypewriterText';

const AuthHeroSection: React.FC = () => {
  const metrics = [
    { label: "Leads", value: "3" },
    { label: "Writer", value: "0" },
    { label: "Designer", value: "0" },
  ];

  const infoCards = [
    {
      title: "Agent Canvas",
      description: "Visualize Search, Writer, Critique, Designer & Sender agents working together on every campaign."
    },
    {
      title: "Lead Intelligence",
      description: "Enrich each lead with research summaries before the first email ever leaves your outbox."
    },
    {
      title: "Safe to Iterate",
      description: "Queue drafts, review them in bulk, and only send when you're ready."
    }
  ];

  return (
    <section className="w-full flex flex-col gap-6 md:gap-8">
      <div id="auth-promo-card" className="relative rounded-3xl border border-slate-200 bg-white/80 backdrop-blur-2xl p-5 md:p-7 shadow-xl shadow-slate-200/70">
        <div className="inline-flex items-center gap-2 rounded-full border border-emerald-300/60 bg-emerald-50 px-3 py-1 text-[10px] md:text-xs text-emerald-700 mb-4">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span>Orchestrate agents, not just emails.</span>
        </div>

        <h1 className="text-2xl md:text-4xl font-semibold tracking-tight text-slate-900 mb-3">
          Turn <span className="text-[#004dff]">cold leads</span> into warm
          <br className="hidden md:block" />
          conversations with
          <br className="hidden md:block" />
          <span className="block mt-2 text-[#004dff]">
            <TypewriterText
              words={[
                "search, writer & designer agents",
                "lead-specific research in seconds",
                "multi-touch outreach sequences",
              ]}
            />
          </span>
        </h1>

        <p className="text-xs md:text-sm text-slate-600 leading-relaxed max-w-xl">
          Connect your leads, hit <span className="font-semibold">Run Agents</span>,
          and watch coordinated AI specialists research, draft, design, and
          schedule hyper-personalized campaigns—without leaving the app
          view you already know.
        </p>

        {/* Mini preview strip mirroring the campaigns page */}
        <div className="mt-5 md:mt-6 grid grid-cols-3 gap-3 text-[10px] md:text-xs">
          {metrics.map((metric) => (
            <div
              key={metric.label}
              className="rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2 flex flex-col gap-1"
            >
              <span className="text-slate-500">{metric.label}</span>
              <span className="text-lg md:text-xl font-semibold text-slate-900">
                {metric.value}
              </span>
            </div>
          ))}
        </div>

        {/* Bottom status row */}
        <div className="mt-5 flex flex-wrap items-center gap-3 text-[10px] md:text-xs text-slate-500 border-t border-slate-100 pt-3">
          <div className="flex items-center gap-2">
            <span className="h-1.5 w-1.5 rounded-full bg-[#004dff] animate-pulse" />
            <span>Real-time agent status per lead</span>
          </div>
        </div>
      </div>

      {/* Secondary info cards */}
      <div className="grid md:grid-cols-3 gap-3 md:gap-4">
        {infoCards.map((card) => (
          <div 
            key={card.title}
            className="rounded-2xl border border-slate-200 bg-white/90 backdrop-blur-xl p-3 md:p-4 flex flex-col gap-1 text-[11px] md:text-xs"
          >
            <span className="font-semibold text-slate-900">{card.title}</span>
            <span className="text-slate-600">{card.description}</span>
          </div>
        ))}
      </div>
    </section>
  );
};

export default AuthHeroSection;

