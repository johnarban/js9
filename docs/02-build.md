# 02 · Build system

The build has three independent pieces. **You rarely need all of them** — most of the
time you only touch the frontend bundling.

| Piece | Tool | When you run it |
|---|---|---|
| A. Frontend bundling (concat + minify) | `make` + Java (closure-compiler, committed) | After editing `js9.js`, `plugins/**`, `js/**`, `css/**` |
| B. Native helper binary | `./configure` + C compiler + cfitsio | Only for the optional `js9helper` program |
| C. WebAssembly module | **Emscripten (`emcc`)** | Only after editing C in `astroem/` |

Everything is driven by **autoconf**: `./configure` turns `Makefile.in` → `Makefile`
(and `src/Makefile.in` → `src/Makefile`), substituting in your paths and helper choice.

> The generated `configure` script **is committed** — you do **not** need `autoconf`
> installed to run it. You only need `autoconf` to regenerate `configure` from
> [configure.ac](../configure.ac) (it is *not* installed on this machine).

---

## Step 0 — configure (creates the top-level Makefile)

There is **no `Makefile` until you configure** (confirm with `ls Makefile` — absent on a
fresh checkout). To get one:

```bash
./configure \
    --with-webdir=/path/to/web/install \   # where 'make install' copies the site
    --with-cfitsio=/path/to/cfitsio    \   # for the native helper (omit if not building it)
    --prefix=/path/to/bin/install      \   # where scripts/binaries install
    --with-helper=nodejs                   # none | nodejs | get | post
```

`--with-helper` is the key switch:
- `none` → no compiler needed, no backend; pure static frontend.
- `nodejs` → use `js9Helper.js` (recommended backend).
- `get` / `post` → use the CGI helper (`build/js9Helper-default.cgi`) for non-Node sites.

For **frontend bundling only** (piece A), a minimal `./configure --with-helper=none` is
enough to produce a `Makefile` with the `js9support` / `js9min` / `allinone` targets.

---

## A. Frontend bundling — the concat + minify pipeline

This is the build you'll use most. The source-of-truth files are concatenated into
bundles, then minified. All of this is defined in [Makefile.in](../Makefile.in).

```bash
make js9support   # rebuild js9support.{js,css} and js9plugins.js, then allinone
make js9min       # minify js9.js -> js9.min.js, then rebuild allinone
make allinone     # rebuild js9-allinone.{js,css} only
```

What each does (from the `Makefile.in` recipes):

- **`make js9support`** — concatenates:
  - `CSSFILES` + `PLCSSFILES` → `js9support.css`
  - `JSFILES` (the `js/*.min.js` third-party libs) → `js9support.min.js`, and their
    non-min versions → `js9support.js`
  - `PLUGINFILES` (every `plugins/**/*.js`) → `js9plugins.js`
  - a manifest of what went where → `js9support.txt`
  - then calls `build/mkallinone`.
  > **Add a plugin or a third-party lib by editing the `JSFILES` / `PLUGINFILES`
  > / `CSSFILES` lists in `Makefile.in`, then `make js9support`.** The lists are the
  > registry; dropping a file in `plugins/` is not enough.

- **`make js9min`** — `touch js9.js; build/minify js9.js` (runs closure-compiler from
  [build/closure-compiler/](../build/closure-compiler/)) to produce `js9.min.js`, then
  rebuilds the allinone bundle.

- **`build/mkallinone`** — stitches the min bundles + css into `js9-allinone.js` /
  `js9-allinone.css` (the single-file deployment), stamping the version.

Minification uses the **committed** `build/closure-compiler/compiler.jar`, so you need a
JRE (`java`) but not an internet download.

### Other frontend-related targets
- `make js9support` also regenerates after `make regSelect` (rebuilds the region-select
  parser from `src/regSelect.jison` using **jison** — only if you change region syntax).
- `make inline` (`build/mkinline`) regenerates inline support.
- `make eslint` / `make eslint2` lint the core / plugin JS (see [04-test.md](04-test.md)).

---

## B. Native helper binary (`js9helper`)

Optional C program the Node helper shells out to for heavy FITS ops. Requires a C
compiler and **cfitsio** (pointed to by `--with-cfitsio`).

```bash
./configure --with-cfitsio=/path/to/cfitsio --with-helper=nodejs --with-webdir=...
make            # 'all' == progs + helper; builds src/js9helper
```

Driven by [src/Makefile.in](../src/Makefile.in): compiles `js9helper.c` plus shared
`jsfitsio.c` / `healpix.c` / `listhdu.c` (from `astroem/`) and `util/` into the
`js9helper` binary, linking against cfitsio. A C compiler **is** available on this
machine, but you must supply cfitsio.

---

## C. WebAssembly module (`astroem`) — needs Emscripten

You only rebuild this if you change C code under `astroem/`. **`emcc` is not installed
here**, and the outputs (`astroem.js`, `astroemw.js`, `astroemw.wasm`) are committed, so
skip this unless you're modifying the C math layer.

To rebuild (with Emscripten on PATH):
```bash
cd astroem
make            # builds libastroem.a, then astroem.js (asm.js) and astroemw.js/.wasm
make install    # copies the outputs up to the repo root, then runs `make js9support`
make clean
```
Or from the top level: `make astroem` (see the `astroem:` target in `Makefile.in`).

Key Makefile knobs ([astroem/Makefile](../astroem/Makefile)):
- `EMFLAGS = -O3` (production). Comment in the `-g` / `ASSERTIONS=1` / `SAFE_HEAP=1`
  lines for debug builds.
- `EMOPTS` sets initial/growable memory and pulls zlib+bzip2 from emscripten-ports.
- `EMEXPORTS` is the **explicit allow-list of C functions** exposed to JS. If you add a
  C entry point that JS needs to call, add its `_name` here or it'll be dead-stripped.

The prebuilt static libs it links (`lib/libcfitsio.a`, `libwcs.a`, `libregions.a`,
`libutil.a`, `libem.a`) are committed in [astroem/lib/](../astroem/lib/).

---

## `make install` (deploying a web site)

After `./configure --with-webdir=…` and `make`:

```bash
make install      # == install-binaries + install-scripts + install-web
```

`install-web` copies the web dirs (`plugins params js css font images help`), the web
files (the bundles, wasm, html), and — if a Node helper was configured — the backend
dirs (`node_modules analysis-plugins analysis-wrappers`) into `$WEBDIR`. It carefully
**does not overwrite** an existing, modified `js9Prefs.json` (use `make install-prefs`
to force). Related: `make install-demos`, `install-tests`, `install-webdata`,
`install-gzip`.

---

## Cleaning

```bash
make clean          # objects, bund-build temp files; recurses into src/ and astroem/
make distclean      # also removes generated Makefile, config.*, prefs files
make scriptclean    # restore the js9 script to its build/js9.in template
```

## Cheat sheet

| I changed… | I run… |
|---|---|
| `js9.js` (core) | `make js9min` |
| a file in `plugins/**` (and added it to `PLUGINFILES`) | `make js9support` |
| a third-party lib in `js/**` or css in `css/**` | `make js9support` |
| region grammar `src/regSelect.jison` | `make regSelect` |
| C in `astroem/**` | `cd astroem && make && make install` (needs `emcc`) |
| C in `src/js9helper.c` | `make` (needs C compiler + cfitsio) |
| `js9Helper.js` (Node backend) | nothing — just restart `node js9Helper.js` |

Next: **[03-run.md](03-run.md)**.
