# OpenUSD language support for Notepad++

Syntax highlighting, code folding, comment toggling, and autocompletion for
[OpenUSD](https://openusd.org) `.usda` text files in
[Notepad++](https://notepad-plus-plus.org).

It is implemented as a Notepad++ **User Defined Language (UDL)** plus an
autocompletion list — no compiled plugin DLL is required, so it works on any
Notepad++ version 7.6 or newer and installs in seconds.

> **Why a UDL and not a C++ plugin?**
> Notepad++ language support comes in two flavors. A compiled C++ plugin (`.dll`)
> can do deep semantic features but must be rebuilt for every Notepad++ /
> architecture combination and is heavyweight to maintain. A UDL is the
> officially supported, portable way to add a *new* language: it drives the same
> Scintilla lexer the built-in languages use and covers everything most people
> want from "language support" — coloring, folding, and word completion. This
> project takes the UDL route.

## Features

- **Syntax highlighting** for the `.usda` grammar:
  - Prim specifiers — `def`, `over`, `class`
  - Composition arcs & list editing — `references`, `payload`, `inherits`,
    `specializes`, `subLayers`, `variantSet`, `variants`, `add`/`append`/`prepend`/`delete`/`reorder`
  - Property qualifiers — `custom`, `uniform`, `varying`, `config`, `rel`, `connect`, `timeSamples`
  - Layer/prim/property metadata fields — `defaultPrim`, `kind`, `apiSchemas`, `customData`, …
  - Value types — `float3`, `color3f`, `matrix4d`, `token`, `asset`, `quatf`, … (incl. `[]` arrays)
  - Schema types — `Xform`, `Mesh`, `Material`, `Shader`, `Camera`, lights, skel, render,
    physics, volumes, … (~56 across the core modules)
  - Property **namespace prefixes** — `xformOp:`, `primvars:`, `inputs:`, `outputs:`,
    `material:`, `physics:`, … (the prefix before the `:` is colored)
  - Constants — `true`/`True`, `false`/`False`, `none`/`None`, `inf`, `nan`
  - Distinct colors for `"strings"`, `'strings'`, multi-line `"""doc strings"""` /
    `'''…'''`, `@asset references@` (incl. `@@@…@@@`), and `<prim/paths>`
  - `#` line comments, and numbers (incl. scientific notation like `-1.6e-19`)
- **Code folding** on `{ … }` blocks and `( … )` metadata blocks.
- **Comment toggling** with `Ctrl+Q` (uses `#`).
- **Autocompletion** of keywords, types, and schema names (`Ctrl+Space`).
- **Theme-agnostic** — backgrounds are transparent (inherit the active theme);
  works on light and dark themes alike.

## Install (automatic, Windows)

From this folder, in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If the autocompletion step reports a permissions error, re-run the same command
from an **Administrator** PowerShell (the `autoCompletion` folder usually lives
under `Program Files`). Restart Notepad++ afterwards.

## Install (manual)

1. **User Defined Language**
   Copy `OpenUSD.udl.xml` to:
   ```
   %AppData%\Notepad++\userDefineLangs\OpenUSD.udl.xml
   ```
   *(Alternatively: Notepad++ → `Language` → `User Defined Language` →
   `Define your language…` → `Import…` and select `OpenUSD.udl.xml`.)*

2. **Autocompletion** (optional)
   Copy `OpenUSD.autocomplete.xml` to your Notepad++ **install** directory as:
   ```
   <Notepad++ install dir>\autoCompletion\OpenUSD.xml
   ```
   The file name **must** be `OpenUSD.xml` so it matches the UDL name.

3. Restart Notepad++.

## Usage

Open any `.usda` file — it is recognized automatically. For other extensions,
pick **OpenUSD** from the bottom of the `Language` menu.

To enable as-you-type completion: `Settings` → `Preferences` → `Auto-Completion`
→ enable *Function and word completion* (or just press `Ctrl+Space`).

A test file lives at [`examples/sample.usda`](examples/sample.usda).

## Handling `.usd` files (ASCII and binary)

Only `.usda` is mapped automatically, because a `.usd` file may be binary
(crate). A UDL binds by extension and cannot inspect content, so it can't tell a
text `.usd` from a binary one. The optional PythonScript hook
[`scripts/OpenUSD_usd_autodetect.py`](scripts/OpenUSD_usd_autodetect.py) closes
that gap by reading the first 8 bytes of each opened `.usd`/`.usdc` file:

- **ASCII** content → applies the OpenUSD language (highlighting).
- **Binary** content (crate, starts with `PXR-USDC`) → left untouched by default,
  or — if the binary viewer is enabled — converted to a **read-only** ASCII view.

### Enabling it

1. Install **PythonScript** via `Plugins` → `Plugins Admin`.
2. Run the installer. For the binary viewer, add `-BinaryViewer`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1 -BinaryViewer
   ```
   This copies the hook, registers it in PythonScript's `startup.py`, and (with
   `-BinaryViewer`) runs `pip install usd-core` and records the Python to use.
3. **One-time:** `Plugins` → `PythonScript` → `Configuration…` → set
   *Initialisation* to **ATSTARTUP** so the hook loads on launch.
4. Restart Notepad++.

### About the binary viewer

Reading a binary crate as text requires converting it first. The hook does this
with [`usd-core`](https://pypi.org/project/usd-core/) — the **official OpenUSD
build published by Pixar** on PyPI (the `pxr` Python libraries). The conversion
is `Sdf.Layer.FindOrOpen(path).ExportToString()`, shown in a read-only tab.
Notes:

- The view is **read-only**; edits are not written back to the crate.
- Needs a Python **3.9–3.14** on `PATH` (that is what `usd-core` supports).
- `usd-core` is core-only: no `usdcat`/`usdview`, just the libraries the hook needs.

(Alternatively, just add `usd` to the `ext="…"` list in `OpenUSD.udl.xml` if you
only ever have ASCII `.usd` files and don't want the plugin — binary `.usd` would
then be colored as garbage.)

## Customizing colors

The palette is **theme-agnostic**: every style uses `colorStyle="0"` or `"1"` so
backgrounds are transparent and inherit whatever Notepad++ theme is active. The
foreground colors are mid-tone so they read on both light and dark themes. To
re-color, edit in Notepad++ via `Language` → `User Defined Language` →
`Define your language…` → pick **OpenUSD** (tick *Transparent* on a color box to
keep it inheriting the theme), or edit the `fgColor` hex values (`RRGGBB`) in
`OpenUSD.udl.xml` directly.

## Known limitations

A UDL uses a regex-free, token-based lexer, so a few things a full grammar would
catch are out of reach:

- Highlighting is keyword/lexical, not semantic — an unknown schema type isn't
  flagged, and identifiers aren't validated against actual USD schemas.
- The schema-type list covers the common core/usdGeom/usdShade/usdLux/usdSkel/
  usdRender/usdPhysics/usdVol set; add domain-specific types to `Keywords6` in the
  UDL, then run `build-autocomplete.ps1` to refresh completion.
- Only the property **namespace prefix** is colored (e.g. `xformOp` in
  `xformOp:translate`); the part after the `:` is left as default text.
- Only `.usda` is mapped, because a `.usd` file may be **binary** (crate) rather
  than ASCII — see [Handling `.usd` files](#handling-usd-files-ascii-and-binary)
  for content-aware handling (including read-only viewing of binary crates).
  `.usdz` is a zip archive and intentionally unmapped.

## File overview

| File | Purpose | Installs to |
|------|---------|-------------|
| `OpenUSD.udl.xml` | User Defined Language (highlighting, folding, comments) | `%AppData%\Notepad++\userDefineLangs\` |
| `OpenUSD.autocomplete.xml` | Word/keyword autocompletion (generated) | `<install dir>\autoCompletion\OpenUSD.xml` |
| `install.ps1` | Installer for both files (`-Symlink` for live edit) | — |
| `uninstall.ps1` | Removes the installed files/links | — |
| `build-autocomplete.ps1` | Regenerates the autocompletion file from the UDL | — |
| `scripts/OpenUSD_usd_autodetect.py` | Optional PythonScript hook: highlight ASCII `.usd`, view binary as read-only | `…\PythonScript\scripts\` |
| `examples/sample.usda` | Demo file for verifying the highlighter | — |

## License

MIT — see [`LICENSE`](LICENSE).
