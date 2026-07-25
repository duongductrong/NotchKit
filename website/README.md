# NotchKit website

Marketing/docs site for [NotchKit](../README.md) — dark-first, single-page, with a live
interactive recreation of the notch island in the hero.

Built with TanStack Start (React 19) + TanStack Router, Tailwind CSS v4, Biome, and the
Cloudflare Vite plugin.

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
npm run check    # biome lint + format
npm run deploy   # build + wrangler deploy
```

## Conventions

- Design tokens are CSS variables on `:root` in `src/styles.css`, mapped into Tailwind via
  `@theme inline`. Use semantic utilities only (`bg-background`, `text-muted-foreground`,
  `border-border`) — no arbitrary values and no raw palette colors.
- Swift snippets are highlighted by a tiny hand-rolled tokenizer in
  `src/components/code-block.tsx` — no runtime dependency.
- The hero island (`src/components/notch-simulator.tsx`) is a spring-driven SVG port of
  `NotchShape`'s corner-fillet path; keep it in sync with `Sources/NotchKit/NotchShapes.swift`.
- `docs/screenshots/` holds verification captures; regenerate with the chrome-devtools
  puppeteer scripts when the page changes.
