#!/bin/bash
# One product: the app takes the landing's palette, type and texture.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# ---------- fonts: Geist everywhere, Geist Mono for machine data ----------
python3 - << 'PY'
p = "app/index.html"
s = open(p).read()
s = s.replace(
  '<link href="https://fonts.googleapis.com/css2?family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,700&family=Inter:wght@500;600;700;800&family=Geist+Mono:wght@400;500&display=swap" rel="stylesheet" />',
  '<link href="https://fonts.googleapis.com/css2?family=Geist:wght@100..900&family=Geist+Mono:wght@100..900&display=swap" rel="stylesheet" />'
)
s = s.replace('content="#171717"', 'content="#0C0C0C"')
open(p, "w").write(s)
print("app loads Geist")
PY

cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { color-scheme: dark; }

html, body { background: #0C0C0C; }

body {
  margin: 0;
  color: #FBFBF7;
  font-family: "Geist", ui-sans-serif, system-ui, sans-serif;
  /* the two properties that carry the texture: Geist's stylistic
     alternates, and a global negative track */
  font-feature-settings: "cv02", "cv03", "cv04", "cv11";
  letter-spacing: -0.4px;
  font-optical-sizing: auto;
  font-synthesis: none;
  -webkit-font-smoothing: antialiased;
}

/* Figures line up in columns and never jitter as they change. */
.num {
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.5px;
}

/* Machine data reads as machine data: addresses, ids, sources, file
   names. Never a human-written sentence. */
.mono {
  font-family: "Geist Mono", ui-monospace, "SF Mono", monospace;
  font-size: 0.92em;
  letter-spacing: 0;
}

.display { letter-spacing: -0.5px; }

::selection { background: #1E3A5F; }
*:focus-visible { outline: 2px solid #2F7FFF; outline-offset: 2px; }
input, select, button { font-family: inherit; letter-spacing: inherit; }
input::placeholder { color: #6E6C66; }

::-webkit-scrollbar { height: 8px; width: 8px; }
::-webkit-scrollbar-thumb { background: #2A2A28; border-radius: 4px; }
::-webkit-scrollbar-track { background: transparent; }

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
}
EOF
echo "type system swapped"

# ---------- palette: the landing's values, applied everywhere ----------
python3 - << 'PY'
import pathlib, re

# darker, warmer, one step deeper than before so it matches the landing
MAP = [
    ("#171717", "#0C0C0C"),   # page
    ("#1A1A1A", "#121212"),   # shell
    ("#1F1F1F", "#171715"),   # card
    ("#242424", "#1C1C1A"),   # raised surface
    ("#2A2A2A", "#242422"),   # divider on a card
    ("#2E2E2E", "#262624"),   # card border
    ("#333330", "#333330"),
    ("#3A3A3A", "#2E2E2B"),   # faintest text
    ("#EDEDED", "#FBFBF7"),   # ink
    ("#C9C9C9", "#D6D4CC"),
    ("#A1A1A1", "#B5B3AA"),   # muted
    ("#8A8A8A", "#8E8C84"),
    ("#5A5A5A", "#6E6C66"),   # faint
    ("#4A4A4A", "#55534E"),
    ("#465468", "#55534E"),
    ("#0A0A0A", "#0C0C0C"),
]

files = [p for p in pathlib.Path("src").rglob("*.tsx")]
n = 0
for f in files:
    t = f.read_text()
    o = t
    for a, b in MAP:
        t = t.replace(a, b).replace(a.lower(), b)
    if t != o:
        f.write_text(t)
        n += 1
print(f"palette applied to {n} files")
PY

# ---------- a mono eyebrow above every section, as the landing does ----------
python3 - << 'PY'
p = "src/components/ui.tsx"
s = open(p).read()
if "export function Eyebrow" not in s:
    s += '''

// A small mono label above a section. It is the cheapest way to make an
// interface feel authored rather than assembled.
export function Eyebrow({ children }) {
  return (
    <div className="flex items-center gap-2 mb-3">
      <span className="h-[3px] w-4 rounded-full bg-[#2F7FFF]" />
      <span className="mono text-[10.5px] uppercase tracking-[.08em] text-[#6E6C66]">
        {children}
      </span>
    </div>
  );
}
'''
    open(p, "w").write(s)
    print("Eyebrow added")
PY

python3 - << 'PY'
import pathlib

# headers get an eyebrow naming what the screen is for
p = pathlib.Path("src/components/Header.tsx")
s = p.read_text()
if "Eyebrow" not in s:
    s = s.replace('import { I, Primary, Ghost } from "./ui";',
                  'import { I, Primary, Ghost, Eyebrow } from "./ui";')
    s = s.replace(
      '          <h1 className="text-[21px] sm:text-[25px] font-bold tracking-tight leading-7 sm:leading-8">{title}</h1>',
      '          <Eyebrow>{project.scopeNote}</Eyebrow>\n          <h1 className="display text-[21px] sm:text-[25px] font-semibold leading-7 sm:leading-8">{title}</h1>')
    p.write_text(s)
    print("header eyebrow in")
PY

# ---------- the sidebar mark links home ----------
python3 - << 'PY'
p = "src/components/Sidebar.tsx"
s = open(p).read()
if 'href="/"' not in s:
    s = s.replace(
      '        <div className="h-9 flex items-center px-2 mb-8">\n          <Wordmark size={18} />\n        </div>',
      '        <a href="/" className="h-9 flex items-center px-2 mb-8 hover:opacity-80 transition">\n          <Wordmark size={18} />\n        </a>')
    open(p, "w").write(s)
    print("wordmark links to the landing")
PY

# ---------- weights: Geist carries hierarchy at 500, not 700 ----------
python3 - << 'PY'
import pathlib
n = 0
for f in pathlib.Path("src").rglob("*.tsx"):
    t = f.read_text(); o = t
    t = t.replace("font-bold tracking-tight", "font-semibold")
    t = t.replace("font-semibold tracking-tight", "font-semibold")
    if t != o:
        f.write_text(t); n += 1
print(f"weights eased on {n} files")
PY

echo ""
echo "Then: npm run dev"
