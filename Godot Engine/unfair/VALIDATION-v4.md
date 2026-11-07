# UNFAIR-004 validation

Delivered Windows x86_64 developer build, tests=yes, angle=yes, optimize=none.

Executable: `bin/Unfair.exe`.
SHA256: `EFE6C465D4CAE16D911C9479295C594D46DA20D60200499586F15BA0DA273563`.
The delivered file matches the compiled executable. Previous executable and console launcher are retained as `Unfair.before-navigation-v4.exe` and `Unfair.before-navigation-v4.console.exe`.

## Verified

- Final build passed: workspace `unfair-v4-build.log`.
- Final native suite:1434 passed,0 failed,3 skipped;425416 assertions passed. See `unfair-v4-tests-final.log`. Negative CanvasItem tests intentionally print drawing errors while their assertions pass.
- GDScript typed arrays/lambda/native classes/theme and scene pack/save/load passed: `unfair-v4-smoke-final.log`.
- Real Editor history transaction: committing an action enables toolbar Undo; Undo restores its previous value and enables Redo; Redo reapplies the value. Existing commands/history signals are used.
- Header: reference-derived36px mark, right-aligned project title,16px toolbar icon caps. Workspace tabs remain centered at1600px; all command controls fit1152px using the compact Content label.
- Windows menu: every actionable entry has an icon; separators divide docks, editors, bottom tools and workspace actions. Final menu capture uses Hierarchy and Terminal glyphs.
- Output, Debugger, Audio, Animation and Shader Editor each open in their own native window and redock on close. Selected-bottom-tool Open in Window and Return All were exercised.
- Existing Content Browser drawer/output exclusion, folder confirmation, native minimize/maximize/restore, minimized Script focus/return, transport run/pause/stop and dark/light theme regeneration passed again.
- Project Manager: Library stays selected; brand and Settings have real drawn interaction surfaces. About/Settings become active while their actual dialogs are open and clear on OK/close. Project-row hover/selected captures show distinct surfaces.
- The user's byte-identical Godot template icon is displayed as Unfair. The project icon file SHA256 remains `6C80384360A5B269D1054BFB27241258154E2CC8167C522016FDC1820E84E0F8`; no project files were rewritten. Custom icons follow the original loading path.
- Native caption diagnostics continue to confirm usable visible minimize/maximize/close and dark/light frame mode.

## Evidence

- Editor/PM logs: workspace `unfair-v4-editor-qa.log`, `unfair-v4-pm-qa.log`; final GUI logs contain no ERROR or SCRIPT ERROR entries.
- Native results: `unfair/smoke/qa-output/workbench-qa-result.json`, `project-manager-qa-result.json` both pass=true.
- Images: `unfair/smoke/qa-output/unfair-v4-*.png`, including workbench, compact, Windows menu, PM hover/selection, live transport and each detached bottom tool.
- Native frame probes: `editor-titlebar-probes.json`, `pm-titlebar-probes.json` in the same output directory.

## Limits

Tests cover the smoke workspace and the current Windows/OpenGL host. They do not establish compatibility with every plugin, translated layout, monitor/DPI arrangement, export pipeline or other operating system. Exact Windows11 caption RGB remains unverified. Viewport screenshots exclude native OS chrome; frame controls are checked using native state and rectangle diagnostics.

Stock-icon replacement intentionally recognizes one exact upstream SVG template hash; customized artwork and other template variants are preserved. The larger header logo is the clean scalable production vector derived from the existing generated/reference design.

Close older running Unfair versions before opening the delivered `bin/Unfair.exe`. Current project layouts are preserved; the Windows menu and toolbar improvements are immediately available.
