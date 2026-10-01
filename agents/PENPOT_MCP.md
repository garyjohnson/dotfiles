# Penpot MCP usage — read before first use

The Penpot tools operate on the currently focused page of the design open in
the Penpot app. If `execute_code` fails with a "No userToken found in session
context" error, or calls time out, the plugin connection in the app has
dropped — ask the user to reconnect it (File → MCP Server → Connect).

## Tool names

| Pi tool name | Server tool | What it does |
| --- | --- | --- |
| `mcp__penpot__high_level_overview` | `high_level_overview` | High-level instructions on Penpot tools and API. Read first. |
| `mcp__penpot__penpot_api_info` | `penpot_api_info` | API docs for one type (and optional `member`). |
| `mcp__penpot__execute_code` | `execute_code` | Run JavaScript in the Penpot plugin context (`penpot`, `penpotUtils`, `storage`). |
| `mcp__penpot__export_shape` | `export_shape` | Export a shape to PNG/SVG. `shapeId` may be a shape id, `selection`, or `page`. |

`mcp__penpot__execute_code` runs the code as the body of a function: return
whatever you want back (arbitrary JS objects are fine). It receives nothing
unless you `return` — `console.log` is not delivered back to you.

`mcp__penpot__high_level_overview` is the server's own overview (shape
hierarchy, layout systems, components, tokens). Read it ONCE if you have not
already — the tool refuses to send it a second time. Its text contains
verified errors (it documents the two-argument `addTheme(group, name)` and
claims fills/strokes arrays are immutable — both wrong, see "API semantics"
below), so where it disagrees with this file, this file wins.

## Layout guidance

- Reach for a flex layout instead of positioning children by hand. If a
  container arranges children in a row or column, it should have a flex
  layout. Use `penpotUtils.addFlexLayout(container, dir)` when the container
  already has children, so their visual order is preserved.
- Center with justifyContent/alignItems ("center"), not by nudging x/y. A
  hardcoded x only centers the one label width you had in mind; every other
  label ends up off-center by a different amount.
- Papering over layout with padding is the same bug. Symmetric padding plus
  justifyContent "center" is fine; padding used to fake a center is not.
- Set horizontalSizing/verticalSizing deliberately: "fix" to keep a size,
  "auto" to fit content, "fill" to fill the parent.

## Execution constraints (these have caused real, repeated failures)

- **Keep each `mcp__penpot__execute_code` call focused and short-lived.** This
  is the primary rule; everything below follows from it. Do one thing per
  call — create one screen, rebuild one component, or read one part of the
  tree. Do not build several screens, restyle a whole page, or mix a
  destructive rebuild with inspection in a single call. Interrupted work is
  the failure mode: a call that dies partway leaves a half-built tree that is
  worse than either the before or after state.
- **Large execute_code calls can time out or hang.** The work runs
  synchronously against a live document, so a call that touches a lot of the
  tree may not finish in time — and an abandoned request can leave the plugin
  unresponsive to the calls that follow it. Keep each call small rather than
  relying on a deadline to save you.
- **One object, one operation per call.** Prefer several flat reads over one
  nested read: deeply nested `findShape` lookups and IIFEs inside large
  `.map()` chains time out as readily as a large build does. The tree walk
  costs more than the shapes created.
- **NEVER sleep or await inside execute_code.** `await new Promise(r =>
  setTimeout(r, n))` does not yield — it HANGS the plugin context, and every
  subsequent call then times out too, until the user restarts the plugin.
  There is no way to wait for layout from inside a call. Do not try.
- **Layout is applied asynchronously, so positions read in the same call are
  stale.** A child just added to a flex container reports `parentY: 0` until
  Penpot's next layout pass. Building shapes and then inspecting/exporting
  their geometry in the SAME call will show everything stacked at the origin
  and look broken when it is not.
- Therefore: **build in one call, then read or export in a SEPARATE later
  call.** Never build-then-verify in one call. Treat a confusing all-zero or
  empty render as "layout has not settled yet", not as a structural bug —
  re-read the geometry in a fresh call before changing any code.
- `mcp__penpot__export_shape` can likewise capture a pre-layout frame. If an
  export looks empty or collapsed, re-export in a new call before concluding
  the design is wrong. Do not respond to a stale render by rebuilding the page
  — that is how a correct design gets churned for no reason.
- **Do not look at exports yourself — delegate visual checks to the
  `penpot-visual-check` subagent.** Every image you pull into this
  conversation counts against the model API's 30-images-per-request cap, and
  the count is cumulative for the rest of the session. Exceed it and the turn
  fails outright with `Too many images in request: N > 30` — an error from the
  model provider, not from Penpot, so nothing about the design is wrong, and
  the accumulated images cannot be dropped mid-conversation: the only recovery
  is a fresh session. The subagent does the export, looks at the image, and
  returns a text verdict, so the pixels never enter this conversation and the
  cap never becomes reachable. Call it with a task naming the shape to inspect
  and the question to answer, e.g. "Export the primary button on the settings
  screen and report whether the label is centered and the hierarchy reads
  clearly."
- The `penpot-visual-check` subagent selects the penpot server's tools
  directly (`mcp:penpot`), but it can still fail to reach them — a server
  connection failure prevents the tools from registering. If the subagent
  reports the tools unavailable, either do a single targeted export yourself
  (numeric reads first, at most one image) or ask the user; do not retry the
  subagent repeatedly.
- **Prefer a numeric geometry read over any pixel check.** Positions, sizes
  and `parentX`/`parentY` answer "is this centered / aligned / overlapping?"
  exactly, cost no image, and do not depend on layout having settled. Reach
  for a visual check only when the question is genuinely about appearance —
  does it read clearly, is the contrast right, does the hierarchy land — and
  even then send it to the subagent rather than exporting here. Export the one
  shape you need, at `selection` or a specific shapeId, never the whole page
  or a batch of screens "to check everything".
- Different runs can disagree: the identical build code may render correctly
  once and appear un-laid-out the next time. The geometry in a follow-up read
  is the source of truth, not a screenshot from the build call.
- Prefer `penpotUtils.addFlexLayout(container, dir)` over
  `container.addFlexLayout()` on boards created via `penpot.createBoard()`
  — the util is the path known to lay out reliably.
- When a call fails with `X is not a function` or `Cannot read properties of
  undefined (reading 'Y')`, stop guessing accessors: look the type up with
  `penpot_api_info` (e.g. `type: "Penpot"`, `"Page"`, `"File"`) and read the
  member listing — members printed WITHOUT `()` are properties, members
  WITH `()` are methods.

## API semantics (verified against the live plugin; each of these caused a
real, silent failure — a wrong assumption here does NOT throw, it just
quietly does the wrong thing or nothing at all)

- **Shape numeric-ish properties are STRINGS, not numbers.** `shape.fontSize`,
  `fontWeight` and friends return strings (`"17"`, not `17`). A strict
  numeric compare silently matches NOTHING: on a real file,
  `findShapes(s => s.fontSize === 17)` returned 0 shapes while
  `s.fontSize === '17'` returned 18. The danger is that the "fix" loop then
  reports success having changed nothing. Always coerce — `String(s.fontSize)`
  or `Number(...)` — on BOTH sides of a comparison, and after a batch edit
  re-read the distribution to confirm the change actually landed rather than
  trusting the loop's own count.
- **`variantContainer.remove()` deletes every child shape and its component.**
  Verified: removing a variant container left `kidsSurvived: [false, false]`.
  The children of a variant container are its main component instances, not a
  view of them — `remove()` is a cascade, not a group teardown. This silently
  deleted two nav items out of a live screen. To dissolve a variant group, detach
  the instances first (`instance.detach()`) or ungroup; never `remove()` the
  container while the instances still matter. Take a note of every child id
  before any structural delete and re-check those ids in a following call.
- **`createComponent` and `createVariantContainer` OVERWRITE shape names.**
  Variantisation reset main-instance names to `"Component"` and the inner
  container to `"Nav"`, losing `"Nav / Listings"` vs `"Nav / Inventory"`.
  Re-assign meaningful names immediately after creating components/variants, and
  re-verify them in a later call — the rename happens asynchronously to your
  assignment.
- **Never use `/` in a component name — it is a path separator, not a
  character.** `createComponent` treats it as one: naming a component
  `"Nav Item / Default"` yielded a component actually named `"Default"`, and
  the common idiom `component.name = "Button/Primary"` produces `"Primary"`.
  Use a space or hyphen (`"Nav Item Default"`).
- **`createVariantContainer` may add a spurious second property axis**
  (`"Property 2"`) alongside the one you asked for. I could not reproduce this
  deterministically on clean scratch boards (both a plain and a pre-named pair
  produced a single clean `State` axis), so treat the trigger as unknown rather
  than assuming a cause. It matters because **the variant API has no way to
  remove a property** — only `addProperty`/`renameProperty` exist — so a junk
  axis cannot be deleted, only renamed. Inspect `container.variants.properties`
  immediately after creating a variant group and, if it is not exactly what
  you intended, rebuild the group rather than trying to repair it in place.
- **`setVariantProperty(pos, value)` counts positions over the CURRENT property
  list**, so `pos` shifts if a property was added. It threw
  `Value not valid: 1. Code: :pos` for me in a state where the property list had
  just changed. Re-read `variants.properties` and index off that rather than
  hardcoding a position from an earlier read.
- **`tokenCatalog.addTheme` takes ONE object, not two arguments.**
  `addTheme(group, name)` fails with an opaque `Value not valid. Code: :error`;
  the working call is `addTheme({ group, name })`. The same opaque `:error`
  also means a partially-applied call was rolled back cleanly — after any such
  error, re-read the collection to confirm nothing was left half-created before
  retrying.
- **`shape.tokens` is the reliable way to audit what is bound.** It maps a
  property name (`fill`, `strokeColor`, `borderRadiusTopLeft`, `rowGap`, …)
  to a token name, so a file-wide count of `Object.keys(s.tokens).length > 0`
  tells you instantly whether tokens were ever applied. On a real file that
  count was **0 of 459 shapes** — a populated token catalog with nothing wired
  to it is a common and invisible failure.
- **Binding a token to a value that already matches it is lossless.** Mapping
  each hardcoded hex to the token with the identical resolved value changed
  zero pixels while making the design themeable. Prefer this over "normalizing"
  colours: when a hardcoded value does NOT match any token, stop and report it
  rather than silently remapping to the nearest one.
- **In-place mutation of `fills`/`strokes`/`shadows` WORKS — the
  widely-repeated "these arrays are immutable, so `shape.fills[0].fillColor =
  '#00FF00'` fails" claim is wrong on both counts.** Verified on a live plugin:
  that exact assignment does not throw, and the change PERSISTS across separate
  calls (checked for `fillColor`, `fillOpacity` and `strokeColor`, all
  survived). An earlier draft of this guidance said the opposite and was itself
  incorrect — do not repeat the "silently no-ops" framing.
  Reassigning the whole array (`shape.fills = [{ fillColor, fillOpacity }]`) is
  still the tidier habit and what the Penpot docs model, so prefer it for
  AUTHORING. But do not rewrite a working index-based edit loop on the belief
  that mutations are discarded: they are not, and the parallel claim that you
  get "a quiet success for a write that never landed" is unfounded.
- **`text.getRange()` with no arguments throws** (`Value not valid. Code:
  :getRange-start`). The working form is `text.getRange(0, text.characters.length)`.
  Note you can usually skip ranges entirely for reads: `fontSize`,
  `fontWeight`, `fontFamily` and `lineHeight` are readable directly on the
  text shape.

## API quick reference (verified surface area; every call here was checked
against a live plugin — use these rather than guessing a signature)

- **Shapes**: `penpot.createBoard()`, `createRectangle()`, `createText(str)`,
  `createEllipse()`, `createShapeFromSvg(svg)`. Position with absolute `x`/`y`
  (or `penpotUtils.setParentXY`), size with `resize(w, h)` — `width`/`height`
  are read-only.
- **Flex**: `board.addFlexLayout()` → `dir` (row/column/row-reverse/
  column-reverse), `alignItems`, `justifyContent`, `rowGap`/`columnGap`,
  `top/right/bottom/leftPadding`, `horizontalSizing`/`verticalSizing`
  (fix/auto/fill), `wrap`. Per-child: `child.layoutChild` with
  `horizontalSizing`/`verticalSizing`/`alignSelf`/margins/`absolute`.
- **Grid**: `board.addGridLayout()` → `addColumn(type, value)`,
  `addRow(type, value)` where type is `"flex" | "fixed" | "percent"`; plus
  gaps, padding, `alignItems`/`justifyItems`. Place a child with
  `grid.appendChild(shape, row, column)` (1-based).
- **Style**: `shape.fills = [{ fillColor, fillOpacity }]` (`[]` for none);
  `shape.strokes = [{ strokeColor, strokeOpacity, strokeWidth, strokeStyle,
  strokeAlignment }]`; `shape.shadows = [{ style: "drop-shadow"|"inner-shadow",
  offsetX, offsetY, blur, spread, color: { color, opacity } }]`. Gradients via
  `fillColorGradient` with `type: "linear"|"radial"` and `stops`.
- **Text**: the common readable/writable properties exist directly on the text
  shape (`characters`, `fontSize`, `fontWeight`, `fontFamily`, `lineHeight`,
  `letterSpacing`, `align`, `textTransform`, `textDecoration`,
  `growType`). Use `getRange(start, end)` only when styling PART of a string.
  Colour strings must be hex with caps.
- **Tokens**: `penpot.library.local.tokens` → `addSet({ name })`,
  `addTheme({ group, name })` (ONE object), `set.addToken({ type, name, value })`,
  `set.toggleActive()`. Apply with `shape.applyToken(token, [props])`; audit with
  `shape.tokens`; look up with `penpotUtils.findTokenByName(name)` and
  `tokenOverview()`. Token types include color, dimension, spacing, typography,
  shadow, opacity, borderRadius, borderWidth, fontSizes, fontWeights,
  fontFamilies, letterSpacing, textCase, textDecoration.
- **Components**: `createComponent(shapes)` → `.instance()`, `.mainInstance()`,
  `.detach()`. Variants exist and are the sharp edge — see the warnings above
  before touching `createVariantContainer` or `createVariantFromComponents`.
- **Code generation**: `penpot.generateStyle(shapes, { type: "css",
  withChildren: true })` and `penpot.generateMarkup(shapes, { type: "html" })`
  both return strings; `generateFontFaces(shapes)` is async. This is the
  Design→Code path.
- **Images**: `await penpot.uploadMediaUrl(name, url)` or
  `await penpot.uploadMediaData(name, bytes, mime)`, then
  `shape.fills = [{ fillOpacity: 1, fillImage: img }]`.
- **Context accessors are PROPERTIES, not functions**: `penpot.currentFile`
  (File), `penpot.currentPage` (Page), `penpot.root`, `penpot.selection` —
  no parentheses. `penpot.currentPage()` throws `penpot.currentPage is not a
  function`. `File` exposes only `id`, `name`, `revn`, `pages` — the design
  library is NOT on the file; it lives at `penpot.library.local` (keys:
  `colors`, `typographies`, `components`, `tokens`).
- **Enumerate a page via `page.root.children`** — `page.children` is
  `undefined`. `Page` also offers `findShapes({ name, nameLike, type })`
  (searches the whole page) and `getShapeById(id)`. Library components:
  `penpot.library.local.components` — each has `.name`, `.instance()`,
  `.mainInstance()`, `.detach()`.
- **Traversal**: `penpotUtils.getPages()`, `getPageByName(name)`,
  `shapeStructure(shape, maxDepth)`, `findShape(predicate)`,
  `findShapes(predicate, root)`, `findShapeById(id)`,
  `isContainedIn(shape, container)`, `analyzeDescendants(root, fn)`.
- `storage` persists across `mcp__penpot__execute_code` calls in a session —
  use it to carry shape ids and intermediate results between calls (essential
  given the build-then-verify-in-a-separate-call rule above).

## Links

- Official plugin API reference: <https://doc.plugins.penpot.app/> — typedoc;
  per-type pages at `/interfaces/<Type>`, e.g.
  <https://doc.plugins.penpot.app/interfaces/Page>
- Plugin development guides: <https://help.penpot.app/plugins/>
- TypeScript definitions: `@penpot/plugin-types` (npm) — the same surface
  the `penpot_api_info` tool reports in-band; prefer the tool, it matches the
  live plugin version.

Caveat: the official docs and the server's `high_level_overview` text contain
errors verified against the live plugin (the overview documents the
two-argument `addTheme(group, name)` and claims fills/strokes arrays are
immutable — both wrong; see "API semantics"). The notes in this file outrank
both.
