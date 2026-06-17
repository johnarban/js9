# Fabric.js 5.2.1 → 7.4.0 upgrade — work summary

A narrative of how the upgrade went, for context. The precise per-change list is
in [fabric-v7-changelog.md](fabric-v7-changelog.md); the API reference is in
[fabric-v5-to-v7-map.md](fabric-v5-to-v7-map.md).

## Goal

JS9 vendors Fabric.js to power its region/shape overlay layer. This branch moves
that from the long-committed **5.2.1** to **7.4.0**. (A separate effort,
`fabric-svg-xss-fix`, stays on 5.2.1 and only backports a security fix — that is
*not* this work.)

## How it went

**1. Vendoring the build.** Fabric 6 dropped the old `fabric.js` build for a UMD
bundle (`dist/index.js` / `index.min.js`). We built it (`MINIFY=1 npm run build`)
and dropped it in as `js/fabric-v7.4.0.{js,min.js}`. One gotcha: the dist files
end with a `//# sourceMappingURL=` comment and no trailing newline, which — because
`js9support` is built by `cat`-ing files together and fabric sits right before
`pako` — swallowed pako's first line and broke the whole bundle. Stripping that
comment fixed it.

**2. The API shims.** Fabric 6 was a full rewrite. Rather than edit hundreds of
call sites, we restored the removed/renamed APIs in one guarded block
(`if (fabric.major_version >= 6)`) near the top of the fabric section in `js9.js`:
`isTouchSupported`, the `hasRotatingPoint` flag (now the `mtr` control),
`addWithUpdate`, `toGroup`/`toActiveSelection`, `setWidth`/`setHeight`,
`sendToBack`/`bringToFront`, and `devicePixelRatio`. Global object defaults moved
to `InteractiveFabricObject.ownDefaults` (v6 ignores the prototype at
construction).

**3. The bugs — found mostly by use, then pinned down headlessly.** Each surfaced
a v6 behavior change, and most shared one root cause: a shim that *renamed* a call
without replicating its v5 *semantics*.

- **Crash on first region add** — JS9 copied a canvas-level `canvas:{selection:true}`
  option onto every object's *defaults*, so each object was born with
  `obj.canvas = {selection:true}` — a plain config object, not a real canvas. v6's
  `add()` first *detaches* an object from any previous canvas
  (`if (obj.canvas && obj.canvas !== this) obj.canvas.remove(obj)`), so it called
  `.remove()` on that config object and threw. The fix is *not* to hand objects a
  real canvas — a fresh object should have **no** canvas until `add()` assigns the
  real one, which makes that detach check false and skips the `remove` entirely. So
  we simply stop putting the `canvas` key on object defaults; `add()` then sets the
  real canvas itself.
- **Wrong region coordinates after grouping/multi-select** — v6's child
  `getCenterPoint()` returns canvas-*absolute* coords (v5 was group-relative), so
  `_updateShape` double-counted the group transform and fed bad coords to analysis,
  save and WCS. Fixed by not re-composing position in v6+ (angle/scale stay
  relative, so those are still composed).
- **`activeSelection` type rename** — v6 lowercased the type to `"activeselection"`;
  JS9 compares the camelCase string in ~20 places (including the geometry path).
  Restored via a `type` getter.
- **Orphan "selection frame"** — moving a multi-selection left an invisible,
  selectable frame. Traced (live stack trace) to the `sortOverlapping` code calling
  `sendToBack()` on the active selection; the shim's `sendObjectToBack()` *inserts*
  non-members into `canvas._objects`. Fixed by guarding membership.
- **Polygon edit anchors not clearing** — `before:selection:cleared` only read
  `opts.target`, but v6 sends `opts.deselected`, so the deselect cleanup never ran.
  Added the `opts.deselected` branch.
- **Magnifier region overlay silently gone** — `fabric.devicePixelRatio` is now
  `undefined`, so the overlay draw became a `NaN` no-op. Shimmed.

**4. Testing.** Beyond manual use, a headless Playwright harness drove the real
build with a test FITS, using per-step `canvas.getObjects()` dumps and method
instrumentation to find root causes and prove fixes (e.g. the group-coordinate
move/scale/rotate test, and the `_objects.unshift` stack trace that nailed the
orphan).

**5. Consolidation.** A review of the patch series found the code already fairly
clean; the one real leftover (writing defaults to both the prototype and
`ownDefaults`) was version-gated, and the "replicate v5 semantics, not just the
name" rule was written into the compat block so the next change doesn't repeat the
`sendToBack` mistake.

## State

Fabric **7.4.0** is vendored and the known region / analysis / selection bugs are
fixed and verified. One pre-existing item (`selection:updated` ignoring
`opts.deselected`) was confirmed identical to v5 behavior and left as-is — not a
v7 regression.
