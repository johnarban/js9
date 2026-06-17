# Fabric.js 5.2.1 → 7.4.0 — changelog

Changes to upgrade JS9's vendored Fabric.js. Narrative: [fabric-v7-upgrade-summary.md](fabric-v7-upgrade-summary.md).
API map: [fabric-v5-to-v7-map.md](fabric-v5-to-v7-map.md). All shims live in one
`if (fabric.major_version >= 6)` block in `js9.js`.

## Vendored
- Bumped Fabric.js **5.2.1 → 7.4.0** — UMD build at `js/fabric-v7.4.0.{js,min.js}`,
  `js/fabric.{js,min.js}` symlinks repointed; bundles regenerated.
- Stripped the trailing `//# sourceMappingURL=` comment from the vendored files —
  with no final newline it swallowed pako's first line in the concatenated
  `js9support` bundle.

## Added — compat shims (APIs removed/renamed in fabric 6)
- `fabric.isTouchSupported` — recomputed from `window`/`navigator`.
- `hasRotatingPoint` — accessor mapping the removed flag to the `mtr` rotation control.
- `ActiveSelection.addWithUpdate` → `multiSelectAdd`.
- `ActiveSelection.toGroup` / `Group.toActiveSelection` — reimplemented on the v6 group model.
- `canvas.setWidth` / `setHeight` → `setDimensions`.
- `canvas.sendToBack` / `bringToFront` and `obj.sendToBack` → `sendObjectToBack` /
  `bringObjectToFront` — guarded to only reorder objects already on the canvas.
- `fabric.devicePixelRatio` → `fabric.config.devicePixelRatio` (magnifier relied on it).
- `ActiveSelection` `type` getter restored to `"activeSelection"` — v6 lowercased it
  and JS9 compares the camelCase string in ~20 places, including the region geometry.

## Changed
- Global object defaults are now set on `InteractiveFabricObject.ownDefaults` in v6+
  (the prototype is ignored at construction); v5 path unchanged. The canvas-level
  `"canvas"` opt is never written to objects.

## Fixed
- **Crash on region add** — stop copying the `"canvas"` opt onto object defaults
  (v6 `add()` calls `obj.canvas.remove()` → throws).
- **Grouped/multi-selected region coordinates** — don't re-compose the group position
  in `_updateShape`; v6 `getCenterPoint()` is already absolute (was double-counted,
  feeding wrong coords to analysis/save/WCS).
- **Orphan "selection frame"** after moving a multi-selection — the `sendToBack` shim
  no longer injects the active selection into `canvas._objects`.
- **Polygon edit anchors lingering** after deselect — `before:selection:cleared` now
  handles v6's `opts.deselected` payload (cleanup only ran on the old `opts.target`).
- **Magnifier region overlay missing** — `devicePixelRatio` shim (was `NaN` → silent
  `drawImage` no-op).

## Docs
- `fabric-v5-to-v7-map.md` — 1-to-1 v5↔v7 map of every fabric API JS9 uses, plus a
  group-coordinate test procedure and design rationale.
- `fabric-v7-upgrade-summary.md`, `fabric-v7-changelog.md` (this file).

## Not changed (verified non-issues)
- `selection:updated` ignores `opts.deselected` — original JS9 behavior, identical
  under v5.2.1; not a v7 regression.
