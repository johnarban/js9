# 06 — (Re)vendoring & rebuilding Fabric.js

The v5 → v7 upgrade is **done**. This is the *procedure* for rebuilding the
vendored Fabric.js (e.g. to bump 7.4.0 → a later release) and regenerating the
JS9 bundles. For **what** changed and **why**, see the three reference docs:

- [fabric-v5-to-v7-map.md](fabric-v5-to-v7-map.md) — 1-to-1 v5↔v7 API map, the
  compat shims, and design rationale.
- [fabric-v7-changelog.md](fabric-v7-changelog.md) — concise list of changes.
- [fabric-v7-upgrade-summary.md](fabric-v7-upgrade-summary.md) — narrative of how
  the upgrade went.

---

## 1. How Fabric is wired in

Fabric is **vendored**, not an npm dependency. It lives in `js/` behind two
symlinks that the build references:

```
js/fabric.js      -> fabric-v7.4.0.js       (unminified UMD, global `fabric`)
js/fabric.min.js  -> fabric-v7.4.0.min.js   (minified UMD)
```

`JSFILES` in `Makefile.in` lists `js/fabric.min.js`; `make js9support` concatenates
those into `js9support.min.js`, and the same list with `.min` stripped builds
`js9support.js`. So **Fabric reaches the browser only through the support bundle**
(and the all-in-one) — never a direct `<script>`. Bumping the version is just:
build the UMD → repoint the symlinks → rebuild the bundles. Older versions
(`fabric-v4.*`, `fabric-v5.2.1.*`) are kept; leave them.

## 2. Build the UMD bundles (in the fabric.js source tree)

The fabric.js checkout's committed `dist/` has only the minified UMD + ESM builds;
build to get both UMD files:

```bash
cd /Users/johnlewis/github/fabric.js
npm ci
MINIFY=1 npm run build      # -> dist/index.js (UMD) and dist/index.min.js (UMD)
```

`MINIFY=1` is required for the minified UMD. Use the **UMD** outputs, not the ESM
`.mjs` (JS9 loads Fabric as a plain `<script>` and reads a global `fabric`).

## 3. Vendor into JS9 (strip the sourcemap comment, repoint symlinks)

```bash
cd /Users/johnlewis/github/js9/js
VER=7.4.0   # set to the new version
perl -pe 's{^//# sourceMappingURL=.*\n?$}{}' /Users/johnlewis/github/fabric.js/dist/index.js     > fabric-v$VER.js
perl -pe 's{^//# sourceMappingURL=.*\n?$}{}' /Users/johnlewis/github/fabric.js/dist/index.min.js > fabric-v$VER.min.js
for f in fabric-v$VER.js fabric-v$VER.min.js; do [ "$(tail -c1 "$f")" != "" ] && printf '\n' >> "$f"; done
ln -sf fabric-v$VER.js     fabric.js
ln -sf fabric-v$VER.min.js fabric.min.js
```

> **Why strip the sourcemap comment.** The dist files end with
> `//# sourceMappingURL=…` and *no trailing newline*. `make js9support` builds the
> bundle with `cat $(JSFILES)`, and Fabric sits immediately before
> `js/pako_inflate.min.js` — so the concatenation puts pako's first line *inside*
> that comment, breaking the whole bundle with a `SyntaxError`. Stripping the
> comment (it points at unshipped `.map` files anyway) fixes it.

## 4. Rebuild the JS9 bundles

```bash
cd /Users/johnlewis/github/js9
./rebuild.sh                 # = configure (if needed) + make js9support + make js9min
```

(or run `make js9support` and `make js9min` directly). This is frontend-only — no
wasm or native-helper rebuild needed. Then validate the concatenation didn't break
(these are browser scripts, so parse them in *script* mode, not CommonJS):

```bash
node -e 'const vm=require("vm"),fs=require("fs");
for(const f of ["js9.min.js","js9support.js","js9support.min.js","js9-allinone.js"]){
  try{ new vm.Script(fs.readFileSync(f,"utf8")); console.log("OK   "+f); }
  catch(e){ console.log("FAIL "+f+": "+e.message); }
}'
```

All four must print `OK`. (`node --check` gives false positives here — it parses as
CommonJS and the bundled `pako` uses browserify module-factory functions.)

## 5. Verify

```bash
make eslint        # lint js9.js
npm start          # load a FITS in the browser (quit Chrome first; see 03-run.md)
```

Regions are the whole point of the Fabric layer, so smoke-test them:

- [ ] `fabric.version` reads the new version in the console; no load errors.
- [ ] Create each region: circle, ellipse, box, polygon, line, annulus, cross, text.
- [ ] Select → move, scale (corner handles), rotate (the `mtr` rotate handle).
- [ ] Annulus / cross (group shapes) move and scale as one unit.
- [ ] Multi-select (shift-click) several regions, move them, then click away — they
      split cleanly with **no leftover selection frame**, and coordinates are correct.
- [ ] Polygon edit handles appear on select and **disappear on deselect**.
- [ ] `make smokeall` if you have the Python `pyjs9` + Electron setup ([04-test.md](04-test.md)).

> If a new fabric version changes APIs again, add shims to the
> `if (fabric.major_version >= 6)` block in `js9.js` — and **replicate the v5
> semantics, not just the renamed call** (see the rationale in the map doc; a naive
> rename is what caused the orphan-selection-frame bug).
