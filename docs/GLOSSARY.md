# Glossary

Domain terms and project-specific names you'll hit reading the code.

## Astronomy / imaging
- **FITS** — *Flexible Image Transport System.* The standard astronomical file format:
  one or more HDUs, each an ASCII header (key/value cards) + a binary data array (image,
  table, or cube). JS9's whole job is to display these.
- **HDU** — *Header/Data Unit.* One extension of a FITS file. A "MEF" (Multi-Extension
  FITS) file has several; `listhdu` enumerates them.
- **WCS** — *World Coordinate System.* The mapping from pixel (x,y) to sky coordinates
  (RA/Dec, galactic, etc.). Handled by **wcslib** in the wasm layer
  (`_initwcs`, `_pix2wcsstr`, `_wcs2pixstr`).
- **zscale** — IRAF auto-contrast algorithm that picks display low/high limits from a
  sample of pixels. C in `astroem/zscale/`, exported as `_zscale`.
- **reproject / Montage** — resampling an image onto a different WCS/projection (for
  alignment or mosaicking). The **Montage** library in `astroem/montage/`
  (`_reproject`, `_madd`, `_imgtbl`).
- **region** — a shape (circle, box, ellipse, polygon, annulus, point, …) drawn on an
  image, used to select pixels for analysis. Pixel math is `libregions.a`
  (`_imcircle`, `_regcnts`, …); DS9 and JS9 region file formats interoperate
  (`./js9 -r` converts JS9→DS9).
- **counts in regions / funcnts** — summing pixel values inside regions (photometry).
  `tests/smoke4` exercises this and diffs `countsInRegions.log`.
- **colormap / scale** — display lookup (grey, heat, cool, viridis, …) and the transfer
  function (linear, log, …). Defaults set in `js9prefs.js` / `js9Prefs.json`.
- **imexam** — interactive examination tools (radial profile, pixel table, histograms,
  3D plot, contours). The `plugins/imexam/` panels.

## Toolchain / build
- **astroem** — this project's name for the bundle of C libraries (cfitsio, wcslib,
  Montage, zscale, regions) compiled to JS/WebAssembly via Emscripten. See
  [01-architecture.md](01-architecture.md).
- **cfitsio** — NASA's reference C library for reading/writing FITS. The core of layer 2.
- **Emscripten / `emcc`** — LLVM-based C→WebAssembly compiler used to build `astroem`.
  Not installed on this machine; outputs are committed.
- **closure-compiler** — Google's JS minifier (committed jar in
  `build/closure-compiler/`), used by `build/minify` to make `*.min.js`.
- **allinone** — the single-file bundle (`js9-allinone.js/.css`) combining core +
  support + plugins for one-`<script>` deployment.
- **jison** — parser generator; builds the region-selection parser from
  `src/regSelect.jison` (`make regSelect`). Rarely needed.
- **autoconf / `configure` / `Makefile.in`** — the GNU build config. `configure`
  (committed, generated) substitutes paths/options into `Makefile.in` → `Makefile`.

## Runtime / backend
- **helper** — the optional backend server (`js9Helper.js`, Node.js + socket.io on port
  2718) that gives a web page file-system access, server-side analysis, and scripting.
  Also has a CGI variant (`--with-helper=get|post`).
- **analysis plugin / wrapper** — a server-side task: a JSON descriptor in
  `analysis-plugins/` (menu item + command) and the executable it runs in
  `analysis-wrappers/` (e.g. `js9Xeq`).
- **pyjs9** — the Python client (separate repo) for driving JS9 over the helper; used by
  the `smoke` tests. **`js9`/`js9msg`** are the shell equivalents.
- **Electron app** — the desktop packaging of the frontend (`js9Electron.js`), launched
  with `./js9 -a`.
- **hostfs** — flag letting the Electron/Node-backed JS9 read the host file system
  directly (`--hostfs true`); off by default for safety.
- **workDir / `tmp`** — per-client scratch directory the helper creates under `./tmp`,
  auto-removed shortly after disconnect.
- **JS9-4L** — "JS9 For Learners", the frontend-only `js94l` branch used by CfA Science
  Education projects. See [05-branches.md](05-branches.md).
