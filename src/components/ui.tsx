export const PAD = "px-4 sm:px-6";
export const HEAD_H = "min-h-[58px] sm:min-h-[64px] py-3 sm:py-0";

export function Card({ children, className = "" }) {
  return (
    <div className={`bg-[#171715] border border-[#262624] rounded-2xl ${className}`}>
      {children}
    </div>
  );
}

// Every card header is the same height with the same padding, so cards
// sitting side by side line up on the same baselines.
export function CardHead({ icon, title, note, right }) {
  return (
    <div className={`${HEAD_H} ${PAD} flex items-center gap-3 border-b border-[#242422] flex-wrap sm:flex-nowrap`}>
      {icon && <IconBox>{icon}</IconBox>}
      <div className="min-w-0">
        <h2 className="text-[length:var(--step-0)] sm:text-[length:var(--step-1)] font-semibold leading-5">{title}</h2>
        {note && (
          <p className="text-[length:var(--step--2)] sm:text-[length:var(--step--1)] text-[#6E6C66] leading-4 mt-0.5 truncate">
            {note}
          </p>
        )}
      </div>
      {right && <div className="ml-auto flex items-center gap-2">{right}</div>}
    </div>
  );
}

export function Chip({ children, tone = "neutral" }) {
  const tones = {
    neutral: "bg-[#242422] text-[#B5B3AA]",
    good: "bg-[#0F2C1F] text-[#4ADE80]",
    warn: "bg-[#2E2410] text-[#FBBF24]",
    bad: "bg-[#2E1515] text-[#F87171]",
    info: "bg-[#12243D] text-[#60A5FA]",
  };
  return (
    <span
      className={`inline-flex items-center h-[22px] px-2 rounded-md text-[length:var(--step--2)] font-medium leading-none whitespace-nowrap shrink-0 ${tones[tone]}`}
    >
      {children}
    </span>
  );
}

export function IconBox({ children }) {
  return (
    <div className="h-8 w-8 sm:h-9 sm:w-9 rounded-xl bg-[#242422] grid place-items-center text-[#B5B3AA] shrink-0">
      {children}
    </div>
  );
}

export function Primary({ children, onClick, disabled }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="h-9 sm:h-10 px-3.5 sm:px-4 rounded-xl text-[length:var(--step--1)] sm:text-[length:var(--step-0)] font-semibold bg-[#2F7FFF] text-white
        hover:bg-[#1F6FEF] transition disabled:bg-[#242422] disabled:text-[#6E6C66]"
    >
      {children}
    </button>
  );
}

export function Ghost({ children, onClick, disabled }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="h-9 sm:h-10 px-3.5 sm:px-4 rounded-xl text-[length:var(--step--1)] sm:text-[length:var(--step-0)] font-medium bg-[#1C1C1A] text-[#D6D4CC]
        border border-[#262624] hover:bg-[#2C2C2C] hover:text-white transition
        disabled:opacity-40"
    >
      {children}
    </button>
  );
}

export function Empty({ children }) {
  return (
    <div className="px-6 py-14 text-center text-[length:var(--step-0)] text-[#6E6C66]">
      {children}
    </div>
  );
}

export const money = (n) =>
  n == null ? "—" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export const when = (t) =>
  new Date(t).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });

const s = (d) => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{d}</svg>
);

export const I = {
  home: s(<><path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z" /></>),
  mail: s(<><rect x="3" y="5" width="18" height="14" rx="2" /><path d="m3 7 9 6 9-6" /></>),
  doc: s(<><path d="M14 3v5h5" /><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z" /></>),
  scale: s(<><path d="M12 3v18M5 7h14M7 7l-3 7h6zM17 7l-3 7h6z" /></>),
  clock: s(<><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>),
  alert: s(<><path d="M12 8v5M12 17h.01" /><circle cx="12" cy="12" r="9" /></>),
  wallet: s(<><rect x="3" y="6" width="18" height="13" rx="2" /><path d="M3 10h18M17 14h.01" /></>),
  search: s(<><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></>),
};


// The quiet row at the foot of a card: what is happening on the left,
// when it last moved on the right.
export function Meta({ left, right }) {
  return (
    <div className="mt-3 pt-3 border-t border-[#242422]">
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <span className="text-[#8E8C84]" style={{ fontSize: "var(--step--2)" }}>
          {left}
        </span>
        {right && (
          <span className="text-[#6E6C66] ml-auto shrink-0"
                style={{ fontSize: "var(--step--2)" }}>
            {right}
          </span>
        )}
      </div>
    </div>
  );
}

export function Dot({ tone = "neutral" }) {
  const tones = {
    neutral: "bg-[#6E6C66]",
    good: "bg-[#4ADE80]",
    warn: "bg-[#FBBF24]",
    bad: "bg-[#F87171]",
    info: "bg-[#2F7FFF]",
  };
  return <span className={`h-2 w-2 rounded-full shrink-0 ${tones[tone]}`} />;
}

export function Action({ children, onClick }) {
  return (
    <button
      onClick={onClick}
      className="h-8 px-3 rounded-lg font-medium whitespace-nowrap
        bg-[#262624] text-[#FBFBF7] border border-[#2E2E2B]
        hover:bg-[#383838] transition"
    >
      {children}
    </button>
  );
}

export const ago = (t) => {
  const m = Math.round((Date.now() - t) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.round(h / 24)}d ago`;
};


// A small mono label above a section. It is the cheapest way to make an
// interface feel authored rather than assembled.
export function Eyebrow({ children }) {
  return (
    <div className="flex items-center gap-2 mb-3">
      <span className="h-[3px] w-4 rounded-full bg-[#2F7FFF]" />
      <span className="mono text-[length:var(--step--2)] uppercase tracking-[.08em] text-[#6E6C66]">
        {children}
      </span>
    </div>
  );
}
