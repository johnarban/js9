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

> An earlier revision of this doc tracked five **unshimmed** v7 breaks under a
> "BREAK" tag. All five are now handled in the compat block, so they appear as
> **SHIMMED**; see section 3 for their call sites and history.

---

## 2. The compat-shim block (already handled)

There is a guarded block `if( fabric.major_version >= 6 ){ ... }` at
**`js9.js` lines 11932–12059**. Fabric 6 was a full rewrite that dropped several
APIs JS9 relies on; this block restores them so the rest of JS9 stays unchanged.

| API | What v7 changed | How the shim restores it |
| --- | --- | --- |
| `ActiveSelection.prototype.type` | v7's `type` getter lowercases the class name, so an active selection reports `"activeselection"` instead of v5's `"activeSelection"`. | A `type` getter is forced back to `"activeSelection"` (`js9.js:11941`). JS9 compares this camelCase string in ~20 places, including the region-geometry path (`_selectShapes` / `getgroups` / `_updateShape`); without this, multi-selected regions get the wrong coordinates. **Safe** because fabric's own `isActiveSelection()` keys off `"multiSelectionStacking"` in the object, not the `type` string. |
| `fabric.isTouchSupported` | Removed from the namespace in v7. | Recomputed from `"ontouchstart" in window` / `navigator.maxTouchPoints` (`js9.js:11948`). |
| `fabric.Object.prototype.hasRotatingPoint` | The `hasRotatingPoint` flag was removed; the rotation handle is now the `"mtr"` control. | An accessor is defined on `fabric.Object.prototype` (`js9.js:11959`) mapping get → `isControlVisible("mtr")` and set → `setControlVisible("mtr", …)`, so every existing get/set of the flag keeps working. |
| `ActiveSelection.prototype.addWithUpdate` | Removed in v7. | Reimplemented to call `multiSelectAdd(obj)` (`js9.js:11975`), the v7 way to add an object to an active selection while preserving canvas-plane coordinates and stacking order. |
| `ActiveSelection.prototype.toGroup` | Removed in v7. | Reimplemented (`js9.js:11983`): `discardActiveObject()` → `remove(...objects)` → `new fabric.Group(objects)` → `add(group)` → `setActiveObject(group)`. |
| `Group.prototype.toActiveSelection` | Removed in v7. | Reimplemented (`js9.js:12002`): `removeAll()` → remove the now-empty group → re-add the children → `new fabric.ActiveSelection(objects, {canvas})` → `setActiveObject`. |

**Canvas/object stacking + sizing** (these five shims were the previously
unshimmed breaks — section 3 — now folded into the compat block. They are
defined on `StaticCanvas.prototype`, which `Canvas` inherits):

| API | What v7 changed | How the shim restores it |
| --- | --- | --- |
| `StaticCanvas.prototype.setWidth(v)` | Removed; sizing folded into `setDimensions({width, height})` (which preserves the other dimension and recomputes the offset). | Reimplemented as `this.setDimensions({width: v})` (`js9.js:12020`). Restores `layer.canvas.setWidth(...)` on every layer-canvas resize (`js9.js:10395`). |
| `StaticCanvas.prototype.setHeight(v)` | Removed (same as above). | Reimplemented as `this.setDimensions({height: v})` (`js9.js:12025`). Restores `layer.canvas.setHeight(...)` (`js9.js:10396`). |
| `canvas.sendToBack(obj)` | Renamed/moved to `canvas.sendObjectToBack(obj)`. | Reimplemented as `this.sendObjectToBack(obj)` on `StaticCanvas.prototype` (`js9.js:12033`). Restores the non-changeable-region paths (`js9.js:14093`, `15729`), the `opts.send === "back"` path (`js9.js:15740`), and the deactivate-and-send-to-back path (`js9.js:16230`). |
| `canvas.bringToFront(obj)` | Renamed/moved to `canvas.bringObjectToFront(obj)`. | Reimplemented as `this.bringObjectToFront(obj)` on `StaticCanvas.prototype` (`js9.js:12038`). Restores the `opts.send === "front"` path (`js9.js:15734`). |
| `obj.sendToBack()` (object method) | Removed from `fabric.Object`. | Reimplemented on `fabric.Object.prototype` (`js9.js:12044`): `if(this.canvas) this.canvas.sendObjectToBack(this)`. Restores the `sortOverlapping` overlap-reorder path (`js9.js:12601`, inside a `try/catch`, off by default). |

**devicePixelRatio**

| API | What v7 changed | How the shim restores it |
| --- | --- | --- |
| `fabric.devicePixelRatio` (a number in v5) | Removed from the namespace; the value now lives at `fabric.config.devicePixelRatio`. | When `fabric.devicePixelRatio` is undefined it is set to `(fabric.config && fabric.config.devicePixelRatio) \|\| window.devicePixelRatio \|\| 1` (`js9.js:12054`). The magnifier multiplies `sx/sy/sw/sh` by it (`plugins/core/magnifier.js:193–196`); with the old name undefined those become `NaN`, and per the canvas spec `drawImage` with a NaN source arg is a **silent no-op** — so the magnifier's **region overlay was silently dropped** (the base magnified image still drew, which is why it *looked* fine). The shim restores the overlay. |

Two related fixes live **outside** that block:

- **Global object defaults** (`js9.js:~28350`, loop at 28353–28368). The
  `JS9.Fabric.opts` → defaults loop writes each key both onto
  `fabric.Object.prototype[key]` **and** into
  `fabric.InteractiveFabricObject.ownDefaults[key]` (`js9.js:28365`), because v7
  reads per-instance defaults from `ownDefaults`, not the prototype. The loop
  also **skips the `"canvas"` key** (`js9.js:28359`): putting
  `obj.canvas = {selection:true}` on every object breaks v7's `add()` —
  `_onObjectAdded` calls `obj.canvas.remove()` whenever `obj.canvas` is set, so a
  non-canvas value throws *"canvas.remove is not a function"* (also surfaces via
  `findControl()`).
- **`rescaleBorder` / `rescaleEvenly`** (`js9.js:12155–12156`) are **JS9's own custom
  methods** added to `fabric.Object.prototype` — they are **not** fabric APIs.
  Adding *methods* to the prototype still works fine in v7; only default
  *values* must move to `ownDefaults`. No action needed.

---

## 3. Resolved breaks (now shimmed)

These five v5 APIs JS9 still calls were **removed or changed in v7**, and an
earlier revision of this doc flagged them as unshimmed (the old "BREAK" tag).
They are now **all handled** by the compat block (section 2). Each is *latent* —
it fires only on a specific path, which is why basic use looked fine — so the
call sites are kept here to document **where/when** each fires.

| v5 API (still called) | v7 replacement | JS9 call sites | Fires when | Status / shim |
| --- | --- | --- | --- | --- |
| `canvas.setWidth(w)` / `canvas.setHeight(h)` | `canvas.setDimensions({width, height})` | `js9.js:10395`, `js9.js:10396` (`layer.canvas.setWidth/setHeight`) | On any resize of the main layer's canvas. | **SHIMMED** — `StaticCanvas.prototype.setWidth/setHeight` → `setDimensions(...)` (`js9.js:12020`, `12025`). |
| `canvas.sendToBack(obj)` | `canvas.sendObjectToBack(obj)` | `js9.js:14093`, `js9.js:15740`, `js9.js:16230` | When a region is non-changeable (`params.changeable === false`, at 14093/15729), on the `opts.send === "back"` path (15740), or on the deactivate-and-send-to-back path (16230). | **SHIMMED** — `StaticCanvas.prototype.sendToBack` → `sendObjectToBack` (`js9.js:12033`). |
| `obj.sendToBack()` (object method) | `canvas.sendObjectToBack(obj)` | `js9.js:12601` | The `sortOverlapping` overlap-reorder path (inside a `try/catch`; **off by default**). | **SHIMMED** — `fabric.Object.prototype.sendToBack` → `if(this.canvas) this.canvas.sendObjectToBack(this)` (`js9.js:12044`). |
| `canvas.bringToFront(obj)` | `canvas.bringObjectToFront(obj)` | `js9.js:15734` | Only when a region's `opts.send === "front"`. | **SHIMMED** — `StaticCanvas.prototype.bringToFront` → `bringObjectToFront` (`js9.js:12038`). |
| `fabric.devicePixelRatio` (a number in v5) | `fabric.config.devicePixelRatio` | `plugins/core/magnifier.js:193–196` | Whenever the magnifier draws regions: it multiplies `sx/sy/sw/sh` by it; in v7 the old name is `undefined` → `NaN`, and `drawImage` with a NaN source arg is a silent no-op, so the magnifier's **region overlay was silently dropped** (the base magnified image still drew). | **SHIMMED** — `fabric.devicePixelRatio` set from `fabric.config.devicePixelRatio` / `window.devicePixelRatio` / `1` (`js9.js:12054`). |

---

## 4. Namespace / classes (`fabric.X`)

| API | JS9 site | Status |
| --- | --- | --- |
| `fabric.Canvas` | `js9.js:12365` (`new fabric.Canvas(el)`) | **OK** — UMD global, same constructor. |
| `fabric.StaticCanvas` | — | **OK** — UMD global. |
| `fabric.Rect`, `fabric.Circle`, `fabric.Ellipse`, `fabric.Polygon`, `fabric.Polyline`, `fabric.Text`, `fabric.Group`, `fabric.ActiveSelection` | construction sites throughout | **OK** — UMD globals; construction unchanged. |
| `fabric.InteractiveFabricObject` / `.ownDefaults` | `js9.js:~28350` (loop 28353–28368) | **v7-only.** Did not exist in v5 (v5 used the prototype). JS9 writes global object defaults here. |
| `fabric.version` | parsed into `major/minor/patch_version` | **OK** — plain `"x.y.z"` string in both. The `*_version` fields are JS9-computed, not fabric API. |

> In v7 the canonical class names are `FabricObject` / `FabricText` /
> `FabricImage`; `fabric.Object` / `fabric.Text` / `fabric.Image` are retained
> aliases, so JS9's references keep resolving.

---

## 5. Canvas methods

All present and behaviorally the same in v7 unless noted. (Removed canvas
methods are restored by the compat block — see **section 2**, with history in
**section 3**.)

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
| `setWidth` / `setHeight` | **SHIMMED** → `setDimensions({width, height})` (section 2) |
| `sendToBack` | **SHIMMED** → `sendObjectToBack` (section 2) |
| `bringToFront` | **SHIMMED** → `bringObjectToFront` (section 2) |

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
| `sendToBack` (object) | **SHIMMED** → `obj.canvas.sendObjectToBack(obj)` (section 2) |
| `bringToFront` (object) | Not called by JS9 (only `obj.sendToBack()` is; the object-level shim covers that). |

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
  `js9.js:~12644–12679`).
- **Object-level events** `obj.on("moving" | "scaling" | "rotating")`
  (`js9.js:16147`, `js9.js:16158–16164`) still fire in v7 (verified).

---

## Open questions / to review

> The five section-3 breaks (`setWidth`/`setHeight`, `canvas.sendToBack`,
> `obj.sendToBack`, `canvas.bringToFront`, `fabric.devicePixelRatio`) are now
> **shimmed** in the compat block (section 2) and are no longer open.

1. **Group / parent coordinate semantics.** The v6 LayoutManager rewrite means
   `getCenterPoint` for objects inside groups / active-selections now returns
   **canvas-absolute** coordinates. This interacts with JS9's manual
   group-coordinate math in `_updateShape` and with its mix of `obj.group`,
   `obj.parent`, and JS9's own `params.parent`. **Flag for browser
   verification — not yet resolved.** A concrete test procedure is at the end of
   this document.

---

## Test procedure: group / parent coordinate semantics

**Goal:** confirm whether the Fabric v6/v7 group-coordinate rewrite broke JS9's
region geometry.

### The suspected bug (read first)

- Fabric **v6** rewrote groups around a **LayoutManager**. Key behavioral change:
  for an object **inside** a `Group` or an `ActiveSelection`, `getCenterPoint()`
  (and the object's `left`/`top`) now return **canvas-ABSOLUTE** coordinates that
  **already include the parent group's transform**. In **v5**, a child's
  `getCenterPoint()` was **group-RELATIVE**.
- JS9's `JS9.Fabric._updateShape` (in `js9.js`, line 14613 onward) computes each
  region's image / physical / WCS position from the fabric object. When a region
  is inside a group it does **manual composition** (`js9.js:14756–14786`):

  ```js
  dpos = obj.getCenterPoint();                 // child center
  // group branch:
  gpos = ginfo.group.getCenterPoint();
  dpos = { x: gpos.x + (dpos.x * group.scaleX),
           y: gpos.y + (dpos.y * group.scaleY) };
  if( group.angle ) dpos = JS9.rotatePoint(dpos, group.angle, gpos);
  // parallel active-selection branch (agroup):
  apos = agroup.getCenterPoint();
  dpos = { x: apos.x + (dpos.x * agroup.scaleX),
           y: apos.y + (dpos.y * agroup.scaleY) };
  if( agroup.angle ) dpos = JS9.rotatePoint(dpos, agroup.angle, apos);
  ```

  That math **assumes the v5 (group-relative) semantics**. Under v7, where the
  child center is already canvas-absolute, this **double-counts the group
  transform** → **WRONG** region coordinates. Those coordinates then feed:
  analysis tools (counts-in-region, radial profiles), region save/export, and the
  WCS readout (`pub.x/pub.y` → `ipos` → `pix2wcs`).
- **Region types that are fabric GROUPS in JS9:** `annulus` and `cross`
  (concentric / composite shapes). Plus any user-created region group
  (`GroupRegions`) and any set of regions multi-selected together (an
  `ActiveSelection`).
- **Important nuance:** a freshly created annulus that is **NOT moved**
  round-trips correctly (`AddRegions` → `GetRegions` gives exact radii/center).
  The breakage is expected to appear only **after** the group/selection is
  **MOVED, SCALED, or ROTATED**, or **while** regions are part of a
  multi-selection.

---

### (A) Manual in-browser procedure (primary deliverable)

**Setup**

1. Serve JS9 and open a display:
   - `npm start` (or `python3 -m http.server` in the js9 dir), then open the demo
     page in a browser.
   - Load any test FITS image. Prefer one **with WCS** so the WCS readout
     (`ra`/`dec` or `l`/`b`) can also be checked:
     `JS9.Load("data/.../something.fits");`
   - Open the browser **console**; all steps below run there.

**Annulus (a fabric Group)**

2. Add an annulus at a known image pixel and read it back immediately
   (un-moved baseline):

   ```js
   JS9.AddRegions("annulus", {x:300, y:300, radii:[10,20,30]});
   JSON.stringify(JS9.GetRegions("all"));
   ```

   Record `x`, `y`, `radii`, `angle`, and (if WCS) `ra`/`dec`. Expect
   center `≈ (300,300)` and radii `≈ [10,20,30]` — this should be correct on
   both v5 and v7.

3. **Move** it: drag the annulus in the UI by a known amount (e.g. ~50 px right).
   Read back:

   ```js
   JSON.stringify(JS9.GetRegions("all"));
   ```

   **Correct:** center shifts by exactly the drag (image-space equivalent of the
   pixels dragged); radii **unchanged**; WCS shifts consistently.
   **Failure signature:** center **jumps / double-shifts** (moves roughly twice
   the intended amount, or in a transformed direction), and/or radii change even
   though you only translated; WCS readout is wrong by the same factor.

4. **Scale** it: drag a corner handle to grow it ~2×. Read back. **Correct:**
   radii scale ~2×, center essentially unchanged. **Failure:** center drifts
   and/or radii scale by the wrong factor.

5. **Rotate** it: drag the rotation handle ~30°. Read back. **Correct:** center
   unchanged, radii unchanged, `angle ≈ 30`. **Failure:** center swings around
   the wrong pivot (the double-rotation in the `JS9.rotatePoint(...,group.angle,
   gpos)` step) and/or radii shift.

**Cross (a fabric Group)**

6. Repeat steps 2–5 for a cross:

   ```js
   JS9.AddRegions("cross", {x:300, y:300, width:40, height:40});
   ```

   Record `x`, `y`, `width`, `height`, `angle`, WCS — before and after
   move/scale/rotate.

**Two circles multi-selected (an ActiveSelection)**

7. Add two separate circles at known centers:

   ```js
   JS9.AddRegions("circle", {x:250, y:250, radius:15});
   JS9.AddRegions("circle", {x:350, y:350, radius:15});
   ```

   Read back and record each center/radius.

8. **Multi-select** both (rubber-band drag a box around them, or shift-click the
   second). Then **drag the selection** as a group by a known amount. Read back
   `JS9.GetRegions("all")`. **Correct:** both centers shift by the same drag,
   radii unchanged. **Failure:** centers double-shift / diverge (the `agroup`
   active-selection branch double-counting the selection transform).

9. Optionally **scale** and **rotate** the multi-selection and re-read, applying
   the same correct-vs-failure checks.

**User-created region group (GroupRegions)**

10. With two regions present, group them and move the group:

    ```js
    JS9.GroupRegions("all");          // or select then group via the menu
    // drag the group in the UI by a known amount
    JSON.stringify(JS9.GetRegions("all"));
    ```

    **Correct:** member centers shift by the drag, sizes unchanged.
    **Failure:** centers double-shift / mis-rotate as above.

> While checking, also sanity-check an **analysis tool** on a moved annulus
> (e.g. counts-in-region or a radial profile): if the geometry is wrong, the
> region the analysis uses won't line up with what's drawn on the image.

---

### (B) v5-vs-v7 differential approach (most reliable)

v5 is the **ground truth**. Run the *same* script on the v5 baseline and on this
v7 branch and **diff the `GetRegions` output**.

1. **v5 baseline branch:** `fabric-svg-xss-fix` (or `js9`) is still on Fabric
   **5.2.1**. This v7 branch is `fabric-v7-upgrade`.

2. **Switch + rebuild.** Fabric ships **inside the support bundle**
   (`js9support.min.js`), not as a separate `<script>`. After switching branches,
   rebuild it:

   ```sh
   git checkout fabric-svg-xss-fix     # v5 baseline
   make js9support                     # regenerate js9support(.min).js
   ```

   Then repeat on `fabric-v7-upgrade`. Confirm the live version in the console
   with `fabric.version` (`5.2.1` vs `7.4.0`).

3. **Keep the test inputs identical.** The **same** FITS image and the **same**
   region script must be used on both branches — otherwise the diff is
   meaningless. A reusable script:

   ```js
   JS9.AddRegions("annulus", {x:300, y:300, radii:[10,20,30]});
   JS9.AddRegions("cross",   {x:300, y:300, width:40, height:40});
   // (then apply the identical move/scale/rotate — see appendix for automation)
   console.log(JSON.stringify(JS9.GetRegions("all"), null, 2));
   ```

4. **Diff.** Copy each branch's `GetRegions` JSON to a file and `diff` them. Any
   field that differs **beyond the intended transform** (especially `x`, `y`,
   `radii`/`width`/`height`, `angle`, `ra`/`dec`) localizes the bug to the
   group-coordinate math.

---

### Appendix: optional headless automation (Playwright)

A headless, scripted version makes the move/scale/rotate **reproducible** across
branches (manual drags are hard to repeat identically).

- The sibling repo `/Users/johnlewis/github/fabric.js` already has
  **Playwright + Chromium** installed
  (`/Users/johnlewis/github/fabric.js/node_modules/.bin/playwright`).
- Serve the js9 dir: `python3 -m http.server` (from `/Users/johnlewis/github/js9`).
- Drive the public API in the page: `JS9.Load(...)`,
  `JS9.AddRegions(...)`, `JS9.GetRegions("all")`.
- For **real drags** (so the group transform actually changes), use
  `page.mouse.move/down/up` with **display coordinates**: get the image with
  `JS9.GetImage()` / `im`, convert image pixels with
  `im.imageToDisplayPos({x, y})`, then add the regions canvas's screen offset
  from `layer.canvas.upperCanvasEl.getBoundingClientRect()` (the regions layer's
  `upperCanvasEl`). Read `GetRegions` before and after each gesture.
- Run the identical script against both the v5-baseline build and the v7 build
  and assert on the JSON. Keep this **optional** — the manual procedure (A) is the
  primary deliverable.

---

### What to capture / pass-fail checklist

For **each** region type below, on **both v5 and v7**, record the fields
**before** and **after** the transform:

| Region type | Transform(s) | Record |
| --- | --- | --- |
| annulus (Group) | move, scale, rotate | image `x,y`; `radii`; `angle`; WCS `ra,dec` (or `l,b`) |
| cross (Group) | move, scale, rotate | image `x,y`; `width,height`; `angle`; WCS |
| 2 circles multi-selected (ActiveSelection) | move (then scale/rotate) | each `x,y`; each `radius`; `angle`; WCS |
| user group (GroupRegions) | move | each member `x,y`; size; `angle`; WCS |

**Pass:** un-moved regions round-trip exactly; after a transform, every field on
v7 matches v5 (allowing only the intended transform), and on-image position/size
match what's drawn.

**Fail (flag it):** any field — `x`, `y`, `radii`/`width`/`height`, `angle`,
`ra`/`dec` (`l`/`b`) — that **differs between v5 and v7 beyond the intended
transform**. Classic signatures: center **double-shifts** after a move,
**mis-pivots** after a rotate, or radii change on a pure translate — i.e. the
`_updateShape` group/`agroup` composition double-counting the parent transform.
