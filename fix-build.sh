#!/bin/bash
set -e
npm i --save-dev @types/node --silent

cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": false,
    "noImplicitAny": false,
    "strictNullChecks": false,
    "types": ["node"]
  },
  "include": ["src", "convex"]
}
EOF

python3 - << 'PY'
import json
p = "package.json"
d = json.load(open(p))
d["scripts"]["build"] = "vite build"
json.dump(d, open(p, "w"), indent=2)
print("build script now: vite build")
PY
