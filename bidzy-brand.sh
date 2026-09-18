#!/bin/bash
# The Bidzy mark, traced from the original, wired through the app.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }
mkdir -p public src/components

# ---- the mark as a React component, one source of truth ----
cat > src/components/Logo.tsx << 'EOF'
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
        className="display font-bold tracking-tight"
        style={{ fontSize: size }}
      >
        Bidzy
      </span>
    </span>
  );
}
EOF

# ---- favicon ----
cat > public/favicon.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="28" fill="#2F7FFF"/>
  <g transform="translate(37 25) scale(0.45)">
    <path fill="#fff" fill-rule="evenodd"
      d="M40 0H66C88 0 94 13 94 30C94 48 88 61 78 61H40L4 30ZM36 30L54 15V46Z
         M40 61H70C92 61 100 74 100 91C100 108 92 121 70 121H42L4 91ZM36 91L54 76V107Z"/>
  </g>
</svg>
EOF

cat > public/logo.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 64" fill="none">
  <g transform="translate(8 6) scale(0.43)">
    <path fill="#2F7FFF" fill-rule="evenodd"
      d="M40 0H66C88 0 94 13 94 30C94 48 88 61 78 61H40L4 30ZM36 30L54 15V46Z
         M40 61H70C92 61 100 74 100 91C100 108 92 121 70 121H42L4 91ZM36 91L54 76V107Z"/>
  </g>
  <text x="62" y="42" font-family="Inter, system-ui, sans-serif"
        font-size="30" font-weight="700" letter-spacing="-1" fill="#EDEDED">Bidzy</text>
</svg>
EOF

# ---- social card ----
cat > public/og.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#171717"/>
  <rect x="64" y="64" width="1072" height="502" rx="28" fill="#1A1A1A" stroke="#2A2A2A" stroke-width="2"/>

  <g transform="translate(112 108) scale(0.45)">
    <path fill="#2F7FFF" fill-rule="evenodd"
      d="M40 0H66C88 0 94 13 94 30C94 48 88 61 78 61H40L4 30ZM36 30L54 15V46Z
         M40 61H70C92 61 100 74 100 91C100 108 92 121 70 121H42L4 91ZM36 91L54 76V107Z"/>
  </g>
  <text x="178" y="152" font-family="Inter, system-ui, sans-serif"
        font-size="32" font-weight="700" fill="#EDEDED" letter-spacing="-0.8">Bidzy</text>

  <text x="112" y="272" font-family="Inter, system-ui, sans-serif"
        font-size="54" font-weight="700" fill="#EDEDED" letter-spacing="-1.6">
    The cheapest quote is rarely
  </text>
  <text x="112" y="336" font-family="Inter, system-ui, sans-serif"
        font-size="54" font-weight="700" fill="#EDEDED" letter-spacing="-1.6">
    the cheapest job.
  </text>

  <text x="112" y="396" font-family="Inter, system-ui, sans-serif"
        font-size="23" fill="#A1A1A1">
    An agent that chases contractor quotes over email and works out the real cost.
  </text>

  <g font-family="Inter, system-ui, sans-serif">
    <rect x="112" y="444" width="215" height="76" rx="14" fill="#242424" stroke="#2E2E2E" stroke-width="1.5"/>
    <text x="132" y="474" font-size="15" fill="#A1A1A1">They quoted</text>
    <text x="132" y="504" font-size="27" font-weight="700" fill="#A1A1A1">$11,900</text>

    <text x="348" y="496" font-size="30" font-weight="600" fill="#5A5A5A">+</text>

    <rect x="390" y="444" width="235" height="76" rx="14" fill="#2E2410" stroke="#443415" stroke-width="1.5"/>
    <text x="410" y="474" font-size="15" fill="#FBBF24">Work left out</text>
    <text x="410" y="504" font-size="27" font-weight="700" fill="#FBBF24">$4,900</text>

    <text x="648" y="496" font-size="30" font-weight="600" fill="#5A5A5A">=</text>

    <rect x="690" y="444" width="235" height="76" rx="14" fill="#0F2C1F" stroke="#1B4A33" stroke-width="1.5"/>
    <text x="710" y="474" font-size="15" fill="#4ADE80">Real cost</text>
    <text x="710" y="504" font-size="27" font-weight="700" fill="#4ADE80">$16,800</text>
  </g>
</svg>
EOF

# ---- use it in the sidebar ----
python3 - << 'PY'
p = "src/components/Sidebar.tsx"
s = open(p).read()
if "Wordmark" not in s:
    s = s.replace('import { I } from "./ui";', 'import { I } from "./ui";\nimport { Wordmark } from "./Logo";')
    start = s.index('<div className="h-9 flex items-center gap-2.5 px-2 mb-8">')
    end = s.index("</div>", s.index("Bidzy</span>")) + len("</div>")
    s = s[:start] + '<div className="h-9 flex items-center px-2 mb-8">\n          <Wordmark size={18} />\n        </div>' + s[end:]
    open(p, "w").write(s)
    print("sidebar uses the mark")
PY

python3 - << 'PY'
p = "index.html"
s = open(p).read()
if "favicon.svg" not in s:
    s = s.replace(
        '    <link rel="preconnect" href="https://fonts.googleapis.com" />',
        '''    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="theme-color" content="#171717" />
    <meta name="description" content="An agent that chases contractor quotes over email, reads whatever comes back, and works out which price is actually cheapest." />
    <meta property="og:title" content="Bidzy — the cheapest quote is rarely the cheapest job" />
    <meta property="og:description" content="An agent that chases contractor quotes over email and works out the real cost." />
    <meta property="og:image" content="/og.svg" />
    <meta name="twitter:card" content="summary_large_image" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />'''
    )
    open(p, "w").write(s)
    print("head updated")
PY

echo "brand done"
