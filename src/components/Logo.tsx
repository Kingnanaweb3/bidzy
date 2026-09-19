// Two chevrons folded into a B. The counters point left, the bowls swell
// right, and the lower half is the heavier of the two.
export function Mark({ size = 28, color = "#2F7FFF" }) {
  return (
    <svg
      width={size}
      height={size * 1.21}
      viewBox="0 0 100 121"
      fill="none"
      aria-hidden="true"
    >
      <path
        fill={color}
        fillRule="evenodd"
        d="M40 0H66C88 0 94 13 94 30C94 48 88 61 78 61H40L4 30ZM36 30L54 15V46Z
           M40 61H70C92 61 100 74 100 91C100 108 92 121 70 121H42L4 91ZM36 91L54 76V107Z"
      />
    </svg>
  );
}

export function Wordmark({ size = 18 }) {
  return (
    <span className="flex items-center gap-2.5">
      <Mark size={size * 1.15} />
      <span
        className="display font-semibold"
        style={{ fontSize: size }}
      >
        Bidzy
      </span>
    </span>
  );
}
