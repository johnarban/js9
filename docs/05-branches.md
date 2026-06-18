# 05 · Branch layout: `js9` vs `js94l`

This repo carries the upstream history plus two locally-important branches. Knowing
which one you're on (and why) saves a lot of confusion.

```
main / master  ── tracks upstream ericmandel/js9 (the original full package)
   │
   ├── js9      ── THIS branch: full stack at the repo ROOT
   │              (frontend + Node helper + native/wasm build, all top-level)
   │
   └── js94l    ── "JS9-4L" (JS9 For Learners): FRONTEND-ONLY,
                  everything relocated UNDER src/js9/ + a PHP entry wrapper
```

Remotes seen in this clone: `johnarban/*` (this fork), `si_moodle_js94l/*` and
`si_website_js9/*` (Smithsonian deployment remotes). `js94l` corresponds to the
`si_moodle_*` deployment; `js9` to the `si_website_*` one.

---

## `js9` (this branch) — the full stack

- Layout: **flat, at the repository root** — `js9.js`, `js9Helper.js`, `astroem/`,
  `src/`, `plugins/`, `Makefile.in`, `configure`, etc. (This is the structure the rest
  of these docs describe.)
- Contents: all three layers from [01-architecture.md](01-architecture.md) — browser
  frontend **+** the Node.js backend helper **+** the native/WebAssembly C build.
- Use it when you need server-side analysis, scripting, the helper, or you're changing
  the C/wasm layer.

## `js94l` — JS9 For Learners (frontend only)

- Purpose (from its README): *"The JS9 installation used throughout Center for
  Astrophysics Science Education Department projects"* — **YouthAstroNet, Observing With
  NASA (OWN), Astro Photo Challenge, DIY Planet Search.**
- Layout: the **entire** JS9 tree was moved down into **`src/js9/`**, with a thin
  **`src/js9Main.php`** wrapper at the top as the integration entry point. The repo root
  contains only `README.md`, `.github/`, `.eslintrc.json`, `.gitignore`, and `src/`.
- It is a **frontend-oriented packaging**: a self-contained JS9 you embed in a host
  learning platform (the PHP file is the glue into that platform). The backend helper
  files still exist inside `src/js9/` (it's the same upstream tree), but the branch's
  reason for existing is the embeddable frontend + the PHP entry point — not running a
  standalone helper.

### Practical differences when moving between them

| | `js9` (here) | `js94l` |
|---|---|---|
| JS9 tree location | repo root | `src/js9/` |
| Extra entry point | — | `src/js9Main.php` |
| Framing | standalone full-stack package | frontend embedded in a learning platform |
| Build/run commands | run from root (`make`, `node js9Helper.js`, `./js9 …`) | run from `src/js9/` (`cd src/js9` first) |
| When to use | server-side features, C/wasm changes, scripting | the education deployments (Moodle/learning sites) |

> **Porting a fix between branches:** a change to `js9.js` (or any frontend file) made
> on `js9` lives at the root; the same file on `js94l` is at `src/js9/js9.js`. A plain
> `git cherry-pick` will usually conflict on paths because of the `src/js9/` move — be
> prepared to apply the change by hand or with path rewriting. Confirm with the repo
> owner which branch is the source of truth for a given change before porting.

---

## Which branch am I on?

```bash
git branch --show-current
ls js9.js 2>/dev/null      && echo "-> root layout: you are on js9 (or main)"
ls src/js9/js9.js 2>/dev/null && echo "-> src/js9 layout: you are on js94l"
```
