#!/bin/bash
# Inter for headlines, DM Sans for body. Everywhere.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

python3 - << 'PY'
p = "index.html"
s = open(p).read()
s = s.replace(
  '<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet" />',
  '<link href="https://fonts.googleapis.com/css2?family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,700&family=Inter:wght@500;600;700;800&display=swap" rel="stylesheet" />'
)
open(p, "w").write(s)
print("fonts linked")
PY

python3 - << 'PY'
p = "src/index.css"
s = open(p).read()

s = s.replace(
  '''body {
  margin: 0;
  color: #EDEDED;
  font-family: "Plus Jakarta Sans", ui-sans-serif, system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}''',
  '''body {
  margin: 0;
  color: #EDEDED;
  font-family: "DM Sans", ui-sans-serif, system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}

/* Inter carries anything that acts as a headline: page titles, card
   headings, company names, and every figure. DM Sans reads better at
   small sizes, so it keeps the running text. */
h1, h2, h3, th, .display {
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
  letter-spacing: -0.01em;
}

.num {
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.015em;
}'''
)

s = s.replace(".num { font-variant-numeric: tabular-nums; }\n", "")
open(p, "w").write(s)
print("css split between the two")
PY

# Company names and button labels read as headline, not body.
python3 - << 'PY'
import pathlib

edits = {
  "src/components/Board.tsx": [
    ('className={`h-10 text-[14px] font-semibold leading-5 ${',
     'className={`display h-10 text-[14px] font-semibold leading-5 ${'),
  ],
  "src/components/BoardMobile.tsx": [
    ('<p className="text-[13px] font-semibold leading-4">',
     '<p className="display text-[13px] font-semibold leading-4">'),
  ],
  "src/components/Sidebar.tsx": [
    ('<span className="text-[17px] font-bold tracking-tight">Bidzy</span>',
     '<span className="display text-[17px] font-bold tracking-tight">Bidzy</span>'),
  ],
  "src/pages/ProjectsPage.tsx": [
    ('<span className="text-[14px] font-semibold">{p.name}</span>',
     '<span className="display text-[14px] font-semibold">{p.name}</span>'),
  ],
  "src/pages/DocsPage.tsx": [
    ('<span className="text-[14px] font-semibold">{r.firmName}</span>',
     '<span className="display text-[14px] font-semibold">{r.firmName}</span>'),
  ],
  "src/pages/BudgetPage.tsx": [
    ('<span className="text-[13.5px] font-semibold">Total to budget</span>',
     '<span className="display text-[13.5px] font-semibold">Total to budget</span>'),
  ],
  "src/pages/InboxPage.tsx": [
    ('className="text-[12.5px] sm:text-[13px] font-medium truncate"',
     'className="display text-[12.5px] sm:text-[13px] font-medium truncate"'),
  ],
}

for path, pairs in edits.items():
    f = pathlib.Path(path)
    if not f.exists():
        continue
    t = f.read_text()
    for a, b in pairs:
        t = t.replace(a, b)
    f.write_text(t)
print("headline class applied where it belongs")
PY

echo "fonts done"
