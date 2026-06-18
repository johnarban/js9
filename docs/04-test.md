# 04 · Testing & linting

JS9 has no unit-test framework. Testing is **end-to-end**: drive a live JS9 instance
(through the helper) and exercise the public API, plus lint the JavaScript. There is one
GitHub Actions workflow, and it only manages stale issues — **there is no CI that builds
or tests the code**, so local testing is on you.

---

## 1. `npm test` — quick load smoke

```bash
npm test     # == build/quicktest build/i800400.fits.gz
```

Starts the helper (if needed), opens `js9.html` in a browser, loads the committed test
image [build/i800400.fits.gz](../build/i800400.fits.gz), and applies a log scale +
viridis colormap + magnifier. It's a "does the whole stack light up" check, not a
pass/fail assertion suite — **you eyeball the result in the browser**. See
[03-run.md](03-run.md) for the Chrome-must-be-quit caveat.

---

## 2. The `smoke` suites — Python + pyjs9 (the real regression tests)

The substantive tests live in [tests/](../tests/) and are driven from `Makefile.in`.
They launch a JS9 app, then run a Python script that calls the public API via **pyjs9**
and compares results.

```bash
make smoke      # tests/smoke.py   — broad public-API coverage
make smoke2     # tests/smoke2.py
make smoke3     # tests/smoke3.py  — adds --savedir handling
make smoke4     # shell scripting + hostfs; diffs countsInRegions.log against a baseline
make smokeall   # all of the above
```

Each `smoke*` target (see the recipes in [Makefile.in](../Makefile.in)):
1. checks no JS9 is already running (`js9 targets`),
2. launches `js9 -a -v --webpage tests/smoke.html …`,
3. waits until a target is available,
4. runs the matching `python3 tests/smoke*.py`.

`smoke4` is different: it runs `tests/ebands`, then `js9 -a --hostfs true --cmdfile
tests/ecnts.js`, and **diffs `countsInRegions.log` against the committed baseline in
`tests/`** — that's the closest thing to an assertion in the suite.

### Prerequisites (read this — they're not all installed here)

| Dependency | Status on this machine | Notes |
|---|---|---|
| `python3` | ✅ (`miniconda3`) | |
| `astropy` | ✅ | used by `smoke.py` (`from astropy.io import fits`) |
| **`pyjs9`** | ❌ **not installed** | the Python client that talks to JS9 — install before running smoke tests |
| Electron | needed for `js9 -a` | the smoke targets launch the app |
| Running helper | started by the target | drives the socket protocol |

Install the missing client:
```bash
pip install pyjs9            # or: git clone https://github.com/ericmandel/pyjs9 && pip install -e pyjs9
```
`pyjs9` connects to the helper on port 2718, so a helper/app must be up (the `make
smoke*` targets handle launching it).

Supporting test files: `tests/smoke.html` (the page the app loads),
`tests/smokesubs.py` (shared helpers), `tests/test0..7.html` (manual interactive test
pages), `tests/data/` (test images).

---

## 3. Linting

```bash
make eslint     # lints the core/server JS (JSLINT list in Makefile.in:
                #   js9.js, js9worker.js, js9Helper.js, js9Msg.js, the Electron files,
                #   js9PostMessage.js, js9Regions.js, astroem/post.js)
make eslint2    # lints plugins/core/*.js and plugins/fitsy/binning.js
```

Config is [.eslintrc.json](../.eslintrc.json) (ES2017, browser+node+jquery globals,
`no-bitwise`/`eqeqeq`/`no-unused-vars` enforced). The badge in the main README points at
**DeepScan**, an external static analyzer run on the upstream repo.

Run eslint directly if you don't have a configured `Makefile`:
```bash
npx eslint js9.js
```

---

## Recommended local test loop

For frontend changes:
1. `make js9min` (or `make js9support`) to rebuild bundles — see [02-build.md](02-build.md).
2. `npm test` (or just reload `js9.html`) and eyeball.
3. `npx eslint <changed file>`.

For a real regression pass (needs `pyjs9` + Electron):
```bash
make smokeall
```

There is **no** `make check` / `make test` target — use the `smoke*` targets above.
