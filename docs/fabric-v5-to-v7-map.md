# Fabric.js v5.2.1 → v7.4.0 API map for JS9

Reference for the `fabric-v7-upgrade` branch. JS9 is an astronomical FITS viewer
that uses Fabric.js for its region / shape overlay layer. This document maps,
1-to-1, every Fabric.js API that the JS9 codebase touches: what it was in
Fabric **v5.2.1**, and what it maps to in Fabric **v7.4.0**.

## 1. How to read this

- **Branch:** `fabric-v7-upgrade`.
- **Vendored fabric:** `js/fabric-v7.4.0.js` and `js/fabric-v7.4.0.min.js`. This
  is the **UMD build**, so it still exposes a browser global named `fabric`
  (the same global JS9 has always used). The v7 ESM packaging is *not* used.
- **How fabric reaches the browser:** only via `js9support.min.js`, which is the
  concatenated support bundle. There is no separate `<script>` for fabric.
- **`fabric.version`** is a plain `"x.y.z"` string in both versions. JS9 parses
  it into `fabric.major_version` / `fabric.minor_version` / `fabric.patch_version`
  (these are JS9-computed, not a fabric API), and the compat shim keys off
  `fabric.major_version >= 6`.

**Legend:**

| Tag | Meaning |
| --- | --- |
| **OK** | Identical / behaviorally the same in v7; works unchanged. |
| **SHIMMED** | Removed/changed in v7, but restored by the compat block in `js9.js` (section 2). |
| **BREAK** | Removed/changed in v7 and **NOT** yet handled — a latent bug (section 3). |

---

## 2. The compat-shim block (already handled)

There is a guarded block `if( fabric.major_version >= 6 ){ ... }` at
**`js9.js` lines ~11932–12018**. Fabric 6 was a full rewrite that dropped several
APIs JS9 relies on; this block restores them so the rest of JS9 stays unchanged.

| API | What v7 changed | How the shim restores it |
| --- | --- | --- |
| `ActiveSelection.prototype.type` | v7's `type` getter lowercases the class name, so an active selection reports `"activeselection"` instead of v5's `"activeSelection"`. | A `type` getter is forced back to `"activeSelection"` (`js9.js:11941`). JS9 compares this camelCase string in ~20 places, including the region-geometry path (`_selectShapes` / `getgroups` / `_updateShape`); without this, multi-selected regions get the wrong coordinates. **Safe** because fabric's own `isActiveSelection()` keys off `"multiSelectionStacking"` in the object, not the `type` string. |
| `fabric.isTouchSupported` | Removed from the namespace in v7. | Recomputed from `"ontouchstart" in window` / `navigator.maxTouchPoints` (`js9.js:11948`). |
| `fabric.Object.prototype.hasRotatingPoint` | The `hasRotatingPoint` flag was removed; the rotation handle is now the `"mtr"` control. | An accessor is defined on `fabric.Object.prototype` (`js9.js:11959`) mapping get → `isControlVisible("mtr")` and set → `setControlVisible("mtr", …)`, so every existing get/set of the flag keeps working. |
| `ActiveSelection.prototype.addWithUpdate` | Removed in v7. | Reimplemented to call `multiSelectAdd(obj)` (`js9.js:11975`), the v7 way to add an object to an active selection while preserving canvas-plane coordinates and stacking order. |
| `ActiveSelection.prototype.toGroup` | Removed in v7. | Reimplemented (`js9.js:11983`): `discardActiveObject()` → `remove(...objects)` → `new fabric.Group(objects)` → `add(group)` → `setActiveObject(group)`. |
| `Group.prototype.toActiveSelection` | Removed in v7. | Reimplemented (`js9.js:12002`): `removeAll()` → remove the now-empty group → re-add the children → `new fabric.ActiveSelection(objects, {canvas})` → `setActiveObject`. |

Two related fixes live **outside** that block:

- **Global object defaults** (`js9.js:~28298`, loop at 28312–28327). The
  `JS9.Fabric.opts` → defaults loop writes each key both onto
  `fabric.Object.prototype[key]` **and** into
  `fabric.InteractiveFabricObject.ownDefaults[key]`, because v7 reads per-instance
  defaults from `ownDefaults`, not the prototype. The loop also **skips the
  `"canvas"` key** (`js9.js:28318`): putting `obj.canvas = {selection:true}` on
  every object breaks v7's `add()` — `_onObjectAdded` calls `obj.canvas.remove()`
  whenever `obj.canvas` is set, so a non-canvas value throws
  *"canvas.remove is not a function"* (also surfaces via `findControl()`).
- **`rescaleBorder` / `rescaleEvenly`** (`js9.js:~12114`) are **JS9's own custom
  methods** added to `fabric.Object.prototype` — they are **not** fabric APIs.
  Adding *methods* to the prototype still works fine in v7; only default
  *values* must move to `ownDefaults`. No action needed.

---

## 3. ⚠️ NOT-yet-handled BREAKS (read this first)

These v5 APIs JS9 still calls are **removed or changed in v7 with no shim**.
They are *latent*: each fires only on a specific path, which is why basic use
looks fine. Listed with the v7 replacement, JS9 call sites, and when the path
fires.

| v5 API (still called) | v7 replacement | JS9 call sites | Fires when |
| --- | --- | --- | --- |
| `canvas.setWidth(w)` / `canvas.setHeight(h)` | `canvas.setDimensions({width, height})` | `js9.js:10395`, `js9.js:10396` (`layer.canvas.setWidth/setHeight`) | On any resize of the main layer's canvas. |
| `canvas.sendToBack(obj)` | `canvas.sendObjectToBack(obj)` | `js9.js:14052`, `js9.js:15688`, `js9.js:16189` | When a region is non-changeable (`params.changeable === false`, at 14052/15688), or on the deactivate-and-send-to-back path (16189). |
| `obj.sendToBack()` (object method) | `canvas.sendObjectToBack(obj)` | `js9.js:12560` | The `sortOverlapping` overlap-reorder path (inside a `try/catch`; **off by default**, so it currently fails silently). |
| `canvas.bringToFront(obj)` | `canvas.bringObjectToFront(obj)` | `js9.js:15693` | Only when a region's `opts.send === "front"`. |
| `fabric.devicePixelRatio` (a number in v5) | `fabric.config.devicePixelRatio` | `magnifier.js:193–196` | Whenever the magnifier draws regions: it multiplies `sx/sy/sw/sh` by it; in v7 the old name is `undefined` → `NaN`, breaking magnifier scaling. |

---

## 4. Namespace / classes (`fabric.X`)

| API | JS9 site | Status |
| --- | --- | --- |
| `fabric.Canvas` | `js9.js:12324` (`new fabric.Canvas(el)`) | **OK** — UMD global, same constructor. |
| `fabric.StaticCanvas` | — | **OK** — UMD global. |
| `fabric.Rect`, `fabric.Circle`, `fabric.Ellipse`, `fabric.Polygon`, `fabric.Polyline`, `fabric.Text`, `fabric.Group`, `fabric.ActiveSelection` | construction sites throughout | **OK** — UMD globals; construction unchanged. |
| `fabric.InteractiveFabricObject` / `.ownDefaults` | `js9.js:~28298` | **v7-only.** Did not exist in v5 (v5 used the prototype). JS9 writes global object defaults here. |
| `fabric.version` | parsed into `major/minor/patch_version` | **OK** — plain `"x.y.z"` string in both. The `*_version` fields are JS9-computed, not fabric API. |

> In v7 the canonical class names are `FabricObject` / `FabricText` /
> `FabricImage`; `fabric.Object` / `fabric.Text` / `fabric.Image` are retained
> aliases, so JS9's references keep resolving.

---

## 5. Canvas methods

All present and behaviorally the same in v7 unless noted. (Removed canvas
methods are in **section 3**.)

| Method | Status |
| --- | --- |
| `add` | OK |
| `remove` | OK |
| `insertAt` | OK |
| `getObjects` | OK |
| `getActiveObject` | OK |
| `getActiveObjects` | OK |
| `setActiveObject` | OK |
| `discardActiveObject` | OK |
| `renderAll` | OK |
| `requestRenderAll` | OK |
| `forEachObject` | OK |
| `getWidth` | OK |
| `getHeight` | OK |
| `setZoom` | OK |
| `getZoom` | OK |
| `clear` | OK |
| `item` | OK |
| `dispose` | OK |
| `setWidth` / `setHeight` | **BREAK** → `setDimensions({width, height})` (section 3) |
| `sendToBack` | **BREAK** → `sendObjectToBack` (section 3) |
| `bringToFront` | **BREAK** → `bringObjectToFront` (section 3) |

> `getPointer` is **deprecated** in v7 (→ `getScenePoint` / `getViewportPoint`),
> but JS9 does **not** use it.

---

## 6. Object methods

| Method | Status |
| --- | --- |
| `getCenterPoint` | OK (but see group/parent caveat, sections 7 & "Open questions") |
| `setCoords` | OK |
| `getScaledWidth` | OK |
| `getScaledHeight` | OK |
| `set` | OK |
| `get` | OK |
| `scale` | OK |
| `toSVG` | OK |
| `intersectsWithObject` | OK |
| `containsPoint` | OK |
| `forEachObject` (Group) | OK |
| `getObjects` (Group) | OK |
| `removeAll` (Group) | OK |
| `multiSelectAdd` (ActiveSelection) | OK (v7 way; the shim routes `addWithUpdate` here) |
| `setControlVisible` / `isControlVisible` | OK |
| `addWithUpdate` (ActiveSelection) | **SHIMMED** → `multiSelectAdd` (section 2) |
| `toGroup` (ActiveSelection) | **SHIMMED** (section 2) |
| `toActiveSelection` (Group) | **SHIMMED** (section 2) |
| `sendToBack` (object) | **BREAK** → `canvas.sendObjectToBack(obj)` (section 3) |
| `bringToFront` (object) | **BREAK** → `canvas.bringObjectToFront(obj)` (section 3) |

---

## 7. Object properties (read/write)

These instance properties are the **same** in v5 and v7:
`scaleX`, `scaleY`, `angle`, `left`, `top`, `width`, `height`, `radius`,
`rx`, `ry`, `points`, `strokeWidth`, `strokeUniform`, `opacity`, `fill`,
`stroke`, `visible`, `lockMovementX`, `lockMovementY`, `selectable`, `evented`,
`hasControls`, `hasBorders`.

Special cases:

| Property | v5 | v7 | Status / note |
| --- | --- | --- | --- |
| `originX` / `originY` | default `left` / `top` | default **`center`** (and deprecated) | JS9 sets `center` explicitly in `JS9.Fabric.opts`, so it's fine — but noted as a behavioral default change. |
| `type` | class name as-is | class name **lowercased** | `Rect` → `"rect"` (same), but `ActiveSelection` v5 `"activeSelection"` → v7 `"activeselection"` → **SHIMMED** back (section 2). |
| `hasRotatingPoint` | real boolean property | removed | **SHIMMED** as an accessor onto `controls.mtr` visibility (section 2). |
| `canvas` | instance ref set when added to a canvas | same | OK as an instance ref — but must **not** be set as a default on objects (the `"canvas"`-key skip, section 2). |
| `group` vs `parent` | `obj.group` is the containing group | v7 adds `obj.parent` as the public containing-group ref (`obj.group` still exists internally) | JS9 uses both `obj.group` **and** its own `params.parent` (a JS9 concept, distinct from fabric's). **Flag for review.** |

---

## 8. Events

Canvas events JS9 binds — **same names** in v5 and v7:
`mouse:down`, `mouse:up`, `mouse:move`, `mouse:over`, `mouse:out`,
`mouse:dblclick`, `object:modified`, `object:scaling`, `object:moving`,
`object:rotating`, `selection:created`, `selection:updated`,
`before:selection:cleared`.

Notes:

- **Mouse payload:** v7 dropped the `button` field (JS9 doesn't read it), and
  `getPointer` is deprecated (JS9 doesn't use it).
- **`selection:created` / `selection:updated` payload:** v5 supplied
  `opts.target` for the active object; v7 supplies `opts.selected` /
  `opts.deselected` arrays. JS9 **already handles both** — its handlers branch
  on `opts.target` vs `opts.selected` (labeled "fabric v4" / "fabric v5" in
  `js9.js:~12599–12640`).
- **Object-level events** `obj.on("moving" | "scaling" | "rotating")`
  (`js9.js:16106`, `js9.js:16117–16123`) still fire in v7 (verified).

---

## Open questions / to review

1. **Section-3 breaks** need either shims or call-site fixes:
   - `setWidth`/`setHeight` → `setDimensions({width, height})` (`js9.js:10395–10396`).
   - `canvas.sendToBack` → `canvas.sendObjectToBack` (`js9.js:14052`, `15688`, `16189`).
   - `obj.sendToBack()` → `canvas.sendObjectToBack(obj)` (`js9.js:12560`).
   - `canvas.bringToFront` → `canvas.bringObjectToFront` (`js9.js:15693`).
   - `fabric.devicePixelRatio` → `fabric.config.devicePixelRatio` (`magnifier.js:193–196`).
2. **Group / parent coordinate semantics.** The v6 LayoutManager rewrite means
   `getCenterPoint` for objects inside groups / active-selections now returns
   **canvas-absolute** coordinates. This interacts with JS9's manual
   group-coordinate math in `_updateShape` and with its mix of `obj.group`,
   `obj.parent`, and JS9's own `params.parent`. **Flag for browser
   verification — not yet resolved.**
