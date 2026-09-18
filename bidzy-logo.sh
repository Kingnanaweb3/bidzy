#!/bin/bash
# Favicon, app icon and social card, all from the sidebar mark.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }
mkdir -p public

# The mark: a roofline over a baseline. Two strokes, reads at 16px.
cat > public/favicon.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="16" fill="#2F7FFF"/>
  <g fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
    <path d="M14 46 32 18l18 28"/>
    <path d="M24 46h16"/>
  </g>
</svg>
EOF

cat > public/logo.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 56" fill="none">
  <rect width="56" height="56" rx="14" fill="#2F7FFF"/>
  <g fill="none" stroke="#fff" stroke-width="5.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 40 28 15l16 25"/>
    <path d="M21 40h14"/>
  </g>
  <text x="70" y="37" font-family="Inter, system-ui, sans-serif"
        font-size="27" font-weight="700" letter-spacing="-0.8" fill="#EDEDED">Bidzy</text>
</svg>
EOF

# Social card, 1200x630, for the X and LinkedIn post
cat > public/og.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#171717"/>
  <rect x="64" y="64" width="1072" height="502" rx="28" fill="#1A1A1A" stroke="#2A2A2A" stroke-width="2"/>

  <rect x="112" y="112" width="60" height="60" rx="15" fill="#2F7FFF"/>
  <g fill="none" stroke="#fff" stroke-width="5.6" stroke-linecap="round" stroke-linejoin="round">
    <path d="M125 158 142 132l17 26"/>
    <path d="M134 158h16"/>
  </g>
  <text x="188" y="155" font-family="Inter, system-ui, sans-serif"
        font-size="30" font-weight="700" fill="#EDEDED" letter-spacing="-0.6">Bidzy</text>

  <text x="112" y="268" font-family="Inter, system-ui, sans-serif"
        font-size="52" font-weight="700" fill="#EDEDED" letter-spacing="-1.4">
    The cheapest quote is rarely
  </text>
  <text x="112" y="330" font-family="Inter, system-ui, sans-serif"
        font-size="52" font-weight="700" fill="#EDEDED" letter-spacing="-1.4">
    the cheapest job.
  </text>

  <text x="112" y="392" font-family="Inter, system-ui, sans-serif"
        font-size="23" fill="#A1A1A1">
    An agent that chases contractor quotes over email and works out the real cost.
  </text>

  <g font-family="Inter, system-ui, sans-serif">
    <rect x="112" y="440" width="215" height="76" rx="14" fill="#242424" stroke="#2E2E2E" stroke-width="1.5"/>
    <text x="132" y="470" font-size="15" fill="#A1A1A1">They quoted</text>
    <text x="132" y="500" font-size="27" font-weight="700" fill="#A1A1A1">$11,900</text>

    <text x="348" y="492" font-size="30" font-weight="600" fill="#5A5A5A">+</text>

    <rect x="390" y="440" width="235" height="76" rx="14" fill="#2E2410" stroke="#443415" stroke-width="1.5"/>
    <text x="410" y="470" font-size="15" fill="#FBBF24">Work left out</text>
    <text x="410" y="500" font-size="27" font-weight="700" fill="#FBBF24">$4,900</text>

    <text x="648" y="492" font-size="30" font-weight="600" fill="#5A5A5A">=</text>

    <rect x="690" y="440" width="235" height="76" rx="14" fill="#0F2C1F" stroke="#1B4A33" stroke-width="1.5"/>
    <text x="710" y="470" font-size="15" fill="#4ADE80">Real cost</text>
    <text x="710" y="500" font-size="27" font-weight="700" fill="#4ADE80">$16,800</text>
  </g>
</svg>
EOF

python3 - << 'PY'
p = "index.html"
s = open(p).read()
if 'favicon.svg' not in s:
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

# convert to PNG if the tooling is around; SVG is fine without it
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 1200 -h 630 public/og.svg -o public/og.png
  rsvg-convert -w 512 -h 512 public/favicon.svg -o public/icon-512.png
  echo "PNGs written"
else
  echo "(no rsvg-convert — SVGs only. brew install librsvg if you want PNGs for the social post.)"
fi

echo "logo done"
