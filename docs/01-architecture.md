# 01 · Architecture

JS9 is three loosely-coupled layers plus two "shells" that repackage layer 1.

```
                         ┌─────────────────────────────────────────────┐
   LAYER 1: FRONTEND     │  browser: js9.html                          │
   (runs in the browser) │    js9support.min.js  (3rd-party libs)      │
                         │    js9.min.js         (JS9 core API)         │
                         │    js9plugins.js      (UI plugins)           │
                         │    astroemw.wasm      (FITS/WCS/region math) │ ◄── LAYER 2
                         └───────────────┬─────────────────────────────┘
                                         │ socket.io (port 2718), optional
                         ┌───────────────▼─────────────────────────────┐
   LAYER 3: BACKEND      │  node js9Helper.js                          │
   (Node.js helper)      │    + analysis-plugins/  analysis-wrappers/   │
                         │    + js9helper native binary (src/js9helper.c)│
                         └─────────────────────────────────────────────┘

   SHELLS over layer 1:  Electron desktop app (js9Electron.js)
                         Shell CLI / scripting (./js9, js9msg, js9load, js9wait)
```

---

## Layer 1 — Frontend (browser JavaScript)

All of this is plain, hand-written JavaScript (no transpiler, no bundler framework —
the "build" is literally `cat` + minify; see [02-build.md](02-build.md)).

| File | Role |
|---|---|
| [js9.js](../js9.js) | **The core.** ~900 KB of source: the JS9 public API, display engine, FITS handling glue, regions, colormaps, scaling, WCS calls into wasm. This is where you spend most of your time. |
| [js9plugins.js](../js9plugins.js) | Concatenation of every file under [plugins/](../plugins/) — the UI panels (menubar, colorbar, magnifier, panner, imexam tools, archive, …). **Generated** from `plugins/**/*.js`. |
| [js9support.js](../js9support.js) | Concatenation of third-party libs in [js/](../js/) — jQuery, jQuery-UI, fabric.js (canvas), flot (plots), pako (gzip), spectrum (color picker), etc. **Generated** from `js/*.js`. |
| [js9.css](../js9.css), [js9support.css](../js9support.css) | Styling, similarly concatenated. |
| [js9worker.js](../js9worker.js) | Web Worker for off-main-thread FITS work. |
| [js9prefs.js](../js9prefs.js) / [js9Prefs.json](../js9Prefs.json) | Site preferences loaded by the page / read by the helper. Sets `helperPort`, `dataPath`, analysis dirs, default colormap/scale. |
| [js9.html](../js9.html) | The reference page. Shows the canonical script include order and the `JS9Menubar` / `JS9Toolbar` / `JS9` / `JS9Statusbar` div pattern. |

**Generated bundles** (committed, served in production — do not hand-edit):
- `js9.min.js` — minified `js9.js`
- `js9plugins.min.js`, `js9support.min.js` — minified plugin/support bundles
- `js9-allinone.js` / `js9-allinone.css` — *everything* in one file (single-`<script>` deployment)

> Rule of thumb: edit `js9.js`, `plugins/**`, `js/**`, or `css/**` (the **sources**);
> then regenerate the bundles. Never edit a `*.min.js`, `js9plugins.js`,
> `js9support.js`, or `js9-allinone.*` by hand — they're build outputs.

---

## Layer 2 — `astroem`: C compiled to WebAssembly

[astroem/](../astroem/) bundles several C libraries and compiles them with
**Emscripten** into a module the browser (and Node) can call. This is why JS9 can
decode FITS and do WCS/reprojection at near-native speed.

What goes in (see [astroem/Makefile](../astroem/Makefile)):
- **cfitsio** — FITS file I/O (`astroem/lib/libcfitsio.a`)
- **wcslib** — World Coordinate System / sky-coordinate transforms (`libwcs.a`)
- **montage** (`astroem/montage/`) — image reprojection / mosaicking
- **zscale** (`astroem/zscale/`) — IRAF zscale auto-contrast
- **regions** (`libregions.a`) — region (circle/box/ellipse/…) pixel math
- JS9's own glue: `astroem/jsfitsio/`, `astroem/wrappers/`, and shared `src/js9helper.c`

Outputs (committed at the repo root):
- `astroem.js` — asm.js / no-wasm fallback build
- `astroemw.js` + `astroemw.wasm` — the WebAssembly build (the default)

The exported C functions are listed explicitly in `EMEXPORTS` in the Makefile
(`_openFITSFile`, `_zscale`, `_reproject`, `_regcnts`, `_pix2wcsstr`, …). `pre.js` /
`post.js` / `shell-pre.js` / `shell-post.js` wrap the Emscripten output so it works in
both a browser and a Node shell.

> You need `emcc` on PATH only to **rebuild** this. It is not installed on this
> machine; the prebuilt `.wasm`/`.js` are committed, so the app runs without it.

---

## Layer 3 — Backend (the "helper")

Optional. Adds capabilities the browser sandbox can't do alone: reach the server file
system, run analysis tasks server-side, broadcast messages between pages, and accept
commands from the shell/Python.

| File | Role |
|---|---|
| [js9Helper.js](../js9Helper.js) | **The Node.js server.** An `http` + `socket.io` server (default port **2718**, all interfaces). Manages per-client work dirs under `./tmp`, runs analysis wrappers via `child_process`, enforces quotas, and relays messages. Config defaults live in the `globalOpts` object near the top and are overridden by `js9Prefs.json` / `js9Secure.json`. |
| [src/js9helper.c](../src/js9helper.c) | Native C helper program (`js9helper` binary) the Node server shells out to for heavy FITS ops. Built by the top-level `make` when `--with-helper` is set. Shares code with `astroem` (`jsfitsio`, `wrappers`). |
| [analysis-plugins/](../analysis-plugins/) | JSON definitions of server-side analysis tasks (`fits2fits.json`, `imsection.json`, `listhdus.json`, `uploadfits.json`, …). Each describes a menu item + the command to run. |
| [analysis-wrappers/](../analysis-wrappers/) | The executables those tasks invoke (e.g. `js9Xeq`). |
| [build/js9Helper-default.cgi](../build/js9Helper-default.cgi) | Alternative CGI helper (`get`/`post` modes) for sites without Node. Chosen via `--with-helper=get|post`. |

Backend dependencies (`socket.io`, `uuid`, `rimraf`, `open`, `ps-list`, `minimist`)
are declared in [package.json](../package.json) **and committed under
[node_modules/](../node_modules/)** — so the helper runs with no `npm install`.

---

## The two shells over Layer 1

- **Electron desktop app** — [js9Electron.js](../js9Electron.js),
  `js9ElectronPreload.js`, `js9ElectronMainMenu.js`. Wraps the frontend in a native
  window. Launched via `./js9 -a`. Lets JS9 run as a Desktop app with optional host
  file-system access (`--hostfs`).
- **Shell CLI / scripting** — [js9](../js9) (bash), plus `js9msg`, `js9load`,
  `js9wait`. These talk to a running helper/app over its socket to drive the public API
  from the command line: `./js9 cmap heat`, `./js9 SetScale log`, `./js9load file.fits`.
  `js9msg` uses curl/wget so it works even without Node. The `js9` script is generated
  by `build/mkjs9`, which bakes in `JS9_SRCDIR`/`JS9_INSTALLDIR`.

The Python equivalent of the CLI is **pyjs9** (separate repo), which the
[smoke tests](04-test.md) use to drive a live JS9 over the helper.

---

## How a FITS file flows through the system (example)

1. User drags `m13.fits` onto the page (or `./js9load m13.fits`).
2. Frontend (`js9.js`) hands the bytes to **astroem** (wasm): `_openFITSMem` →
   `_getImageToArray` decode the pixels; `_initwcs`/`_pix2wcsstr` set up sky coords.
3. `zscale` (wasm) computes auto-contrast limits; the chosen colormap + scale render to
   a `<canvas>` (via fabric.js from `js9support`).
4. If a server-side task is requested (e.g. *reproject*, *counts in regions*), the
   frontend sends it over socket.io to **`js9Helper.js`**, which runs the matching
   `analysis-wrapper` / `js9helper` binary and streams results back.

Next: **[02-build.md](02-build.md)** for how the generated files above get made.
