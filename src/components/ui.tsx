export function Card({ children, className = "" }) {
  return (
    <div className={`bg-[#1F1F1F] border border-[#2E2E2E] rounded-2xl ${className}`}>
      {children}
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
    <span className={`text-[11px] font-medium px-2 py-1 rounded-md ${tones[tone]}`}>
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
      className="text-[13px] font-semibold rounded-xl px-4 py-2.5 bg-[#2F7FFF]
        text-white hover:bg-[#1F6FEF] transition
        disabled:bg-[#2A2A2A] disabled:text-[#5A5A5A]"
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
      className="text-[13px] font-medium rounded-xl px-4 py-2.5 bg-[#252525]
        text-[#C9C9C9] border border-[#2E2E2E] hover:bg-[#2C2C2C] hover:text-white
        transition disabled:opacity-40"
    >
      {children}
    </button>
  );
}

export const I = {
  home: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>,
  mail: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>,
  doc: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M14 3v5h5"/><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z"/></svg>,
  scale: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M12 3v18M5 7h14M7 7l-3 7h6zM17 7l-3 7h6z"/></svg>,
  clock: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>,
  alert: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M12 9v4M12 17h.01"/><circle cx="12" cy="12" r="9"/></svg>,
  wallet: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M17 14h.01"/></svg>,
  search: <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>,
};
