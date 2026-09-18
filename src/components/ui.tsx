export const PAD = "px-6";
export const HEAD_H = "h-[64px]";

export function Card({ children, className = "" }) {
  return (
    <div className={`bg-[#1F1F1F] border border-[#2E2E2E] rounded-2xl ${className}`}>
      {children}
    </div>
  );
}

// Every card header is the same height with the same padding, so cards
// sitting side by side line up on the same baselines.
export function CardHead({ icon, title, note, right }) {
  return (
    <div className={`${HEAD_H} ${PAD} flex items-center gap-3 border-b border-[#2A2A2A]`}>
      {icon && <IconBox>{icon}</IconBox>}
      <div className="min-w-0">
        <h2 className="text-[14px] font-semibold leading-5">{title}</h2>
        {note && (
          <p className="text-[12px] text-[#5A5A5A] leading-4 mt-0.5 truncate">
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
    neutral: "bg-[#2A2A2A] text-[#A1A1A1]",
    good: "bg-[#0F2C1F] text-[#4ADE80]",
    warn: "bg-[#2E2410] text-[#FBBF24]",
    bad: "bg-[#2E1515] text-[#F87171]",
    info: "bg-[#12243D] text-[#60A5FA]",
  };
  return (
    <span
      className={`inline-flex items-center h-[22px] px-2 rounded-md text-[11px] font-medium leading-none whitespace-nowrap shrink-0 ${tones[tone]}`}
    >
      {children}
    </span>
  );
}

export function IconBox({ children }) {
  return (
    <div className="h-9 w-9 rounded-xl bg-[#2A2A2A] grid place-items-center text-[#A1A1A1] shrink-0">
      {children}
    </div>
  );
}

export function Primary({ children, onClick, disabled }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="h-10 px-4 rounded-xl text-[13px] font-semibold bg-[#2F7FFF] text-white
        hover:bg-[#1F6FEF] transition disabled:bg-[#2A2A2A] disabled:text-[#5A5A5A]"
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
      className="h-10 px-4 rounded-xl text-[13px] font-medium bg-[#242424] text-[#C9C9C9]
        border border-[#2E2E2E] hover:bg-[#2C2C2C] hover:text-white transition
        disabled:opacity-40"
    >
      {children}
    </button>
  );
}

export function Empty({ children }) {
  return (
    <div className="px-6 py-14 text-center text-[13px] text-[#5A5A5A]">
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
