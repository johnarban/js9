# JS9 Developer Guide

A new-developer knowledge base for **this** repository (the `js9` branch — the full
stack: browser frontend **+** Node.js backend helper **+** native/WebAssembly C code).

> JS9 is an astronomical FITS image viewer that runs in the browser. FITS decoding,
> WCS, reprojection and region analysis are done in C compiled to WebAssembly, so the
> browser does near-native image processing. An optional Node.js "helper" server adds
> server-side file handling and analysis tasks.

Upstream is archived and unmaintained (see the warnings at the top of [README.md](../README.md)).
This fork keeps it alive for the Center for Astrophysics Science Education projects.

## Read these in order

1. **[01-architecture.md](01-architecture.md)** — the three layers, and which files
   belong to each. Read this first; everything else assumes it.
2. **[02-build.md](02-build.md)** — the autoconf + nested-Makefile build, the
   concatenate/minify bundling pipeline, and what's already prebuilt for you.
3. **[03-run.md](03-run.md)** — five ways to run JS9, from "open an HTML file" to a
   full web install with the helper.
4. **[04-test.md](04-test.md)** — `npm test`, the Python `smoke` suites, and linting.
5. **[05-branches.md](05-branches.md)** — how this `js9` branch relates to the
   frontend-only `js94l` (JS9-4L) branch.

### Fabric.js — the region/shape layer

JS9 vendors **Fabric.js 7.4.0** (upgraded from 5.2.1) for its region overlay:

- **[fabric-v5-to-v7-map.md](fabric-v5-to-v7-map.md)** — the reference: a 1-to-1
  v5↔v7 map of every fabric API JS9 uses, the compat shims, and design rationale.
- **[fabric-v7-changelog.md](fabric-v7-changelog.md)** — concise list of the
  upgrade's vendoring, shims, and fixes.
- **[fabric-v7-upgrade-summary.md](fabric-v7-upgrade-summary.md)** — narrative of
  how the upgrade went.
- **[06-fabric-upgrade.md](06-fabric-upgrade.md)** — the procedure to (re)build and
  vendor a new Fabric.js version and regenerate the bundles.

## TL;DR — fastest paths

```bash
# 0. Nothing to build for the common case: the bundled JS, the wasm, and
#    node_modules are all committed to the repo.

# 1. Frontend only, no backend — just open the page in a browser:
open js9.html            # macOS; or drag js9.html into Chrome/Firefox/Safari

# 2. Frontend + Node helper + a test image (the canonical smoke run):
npm start                # == build/quicktest  (starts the helper, opens a browser)
npm test                 # == build/quicktest build/i800400.fits.gz (loads a FITS file)

# 3. Just the backend helper, on port 2718:
node js9Helper.js
```

## The one-paragraph mental model

The browser loads `js9.html`, which pulls in three bundles — `js9support.min.js`
(third-party libs), `js9.min.js` (the JS9 core), and `js9plugins.js` (UI plugins) —
plus the `astroem` WebAssembly module that does the FITS/WCS/region math. That is a
**complete, self-contained app**; no server is required. The optional **helper**
(`js9Helper.js`, a Node.js + socket.io server on port 2718) is what lets a web page
reach the file system, run server-side analysis tasks, and be scripted from the shell
(`./js9 …`) or Python (`pyjs9`). A third path wraps the same frontend in **Electron**
(`js9Electron.js`) to make a desktop app.

## What you can and cannot rebuild on this machine right now

| Artifact | Tool needed | Installed here? | Notes |
|---|---|---|---|
| Frontend bundles (`js9-allinone.js`, `js9.min.js`, `js9support.js`) | `node`, `make`, Java (closure-compiler) | node ✅ / make via `./configure` | Source files are plain JS; bundling just concatenates + minifies. See [02-build.md](02-build.md). |
| `astroem.js`, `astroemw.js/.wasm` (the C→wasm module) | **Emscripten (`emcc`)** | ❌ not installed | Prebuilt copies are committed, so you only need `emcc` if you change the C code in `astroem/`. |
| `js9helper` native binary | A C compiler + cfitsio | C compiler ✅ | Built by `./configure --with-helper=nodejs && make`. Optional. |
| `configure` script | `autoconf` | ❌ not installed | Already committed/generated — you run it as-is; you only need autoconf to regenerate it from `configure.ac`. |
| Backend helper (`js9Helper.js`) | `node` + `node_modules` | both ✅ (node_modules committed) | No build step — it's plain Node.js. |

See [05-branches.md](05-branches.md) for the `js94l` relationship and
[GLOSSARY.md](GLOSSARY.md) for the astronomy/FITS jargon.
