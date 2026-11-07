# UNFAIR-003 validation

Build: Windows x86_64 developer, tests enabled, ANGLE enabled, optimize=none.
Delivered executable: `bin/Unfair.exe`, SHA256 `AA0BBAA4A6C59D8271F0932BF52303AE7B6AA511C71D2A388BC6A8B2AF125958`.

## Results

- Build passed (`unfair-v3-build.log` in workspace root).
- Native regression: 1434 passed, 0 failed, 3 skipped; 425416 assertions passed (`unfair-v3-tests-final.log`). Expected negative drawing tests print CanvasItem errors without failing assertions.
- GDScript typed collections/lambda/native classes/theme and scene pack/save/load passed (`unfair-v3-smoke-final.log`).
- Native Editor QA passed: centered tabs at1600px, complete compact1152px layout, initially collapsed Content Browser, open/close toggle, Output mutually excludes the horizontal drawer, brand styles, folder confirmation, native maximize/minimize/restore, Script detach, restore from minimized and Return All Tool Windows.
- Live scene transport QA passed: start, enabled Pause/Stop, paused state, Stop ends the test process. Running/paused captures show green Play, amber Pause and red Stop.
- Native Project Manager/New Project/folder QA passed. The custom SceneTree harness explicitly maximizes/restores its root to consume the hidden helper startup hint; screenshots alone did not reveal the previously hidden test root. Final native probes confirm the root is visible.
- Native caption diagnostics confirm usable and visible Minimize, Maximize/Restore and Close representations on Editor and Project Manager; main-window and detached flags retain system menu and resizable frame.
- First observed startup caption reports dark mode. Folder and Editor switch dark/light with the application. Delivered `Unfair.exe` was opened normally and independently probed (`delivered-pm-titlebar.json`).
- Editor splash includes “Forked from Godot Engine”; inspected generated800x600 artwork.
- Independent source review found and fixed the bottom-panel self-close case, profile-disabled toggle state and Classic root-card fallback. Distinct root glyphs verified in final dark/light native captures.

## Evidence and limits

Native captures and JSON results: `unfair/smoke/qa-output/unfair-v3-*`, `workbench-qa-result.json`, `project-manager-qa-result.json`, `editor-titlebar-probes.json`, `pm-titlebar-probes.json`.

Viewport captures exclude the Windows nonclient frame. Computer Use native capture timed out twice, so caption glyph pixels were not visually inspected through that helper. Windows API state, button screen rectangles and DWM caption bounds were checked instead. The first observation is not a frame-by-frame recording of the entire launch. This Windows host does not support exact caption RGB attributes34–36; Windows11 exact RGB and other operating systems remain unverified.

Current checks do not cover every plugin, translated layout, screen-reader workflow, multi-monitor DPI arrangement or export pipeline. Existing project icons, files and custom dock layouts are preserved. Use Windows → Reset to Unfair Workspace to adopt the new default drawer layout in an existing project. Ctrl+Space toggles Content Browser; pinned bottom tools retain their pin behavior.

Previous executable retained at `bin/Unfair.before-polish-v3.exe`. Close older versions and open `bin/Unfair.exe` for this revision.
