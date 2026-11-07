# Unfair validation record

## Build

Windows x86_64 developer editor, Godot 4.8 beta source, MSVC 14.5 / Windows SDK
10.0.26100.0, SCons 4.11.1. Developer build uses `optimize=none`, no debug symbols,
and native tests. It is an editable development build, not a signed installer or
an optimized release.

AccessKit, Direct3D 12 (Mesa NIR, PIX, Agility SDK), and ANGLE dependencies are
installed from the source tree's official installers. Build entry point:
`unfair/build-windows.ps1 -Python <python.exe> -Portable`.

## Evidence

- Initial complete Windows build: passed, 6m59s, `../unfair-build.log` relative to the source root.
- Final complete build with ANGLE: passed, 6m33s; fixture-only incremental rebuild passed, 22s. Logs: `../unfair-build-final.log`, `../unfair-rebuild-final.log`.
- Final full native suite: **1434 passed, 0 failed, 3 skipped; 425416 assertions passed**, `../unfair-full-tests-final.log`.
- Native Theme unit tests: 4 cases, 466 assertions passed, `../unfair-unit-tests.log`.
- GDScript smoke: typed arrays/lambda, native classes, scene pack/save/load and Theme resource passed, `../unfair-smoke.log`.
- Headless editor initialization and native theme QA: passed, `../unfair-editor-qa.log`.
- GUI editor: OpenGL Compatibility on NVIDIA RTX 3070 Ti; native theme QA and viewport capture passed, `../unfair-editor-visual.log`.
- Final editor startup, theme QA and viewport capture also passed on ANGLE/D3D11, Vulkan Forward+ and Direct3D 12 Forward+ on the RTX 3070 Ti. Logs: `../unfair-renderer-opengl3_angle.log`, `../unfair-renderer-vulkan.log`, `../unfair-renderer-d3d12.log`.
- Final GDScript smoke passed with the delivered executable, `../unfair-smoke-final.log`; delivery SHA-256 and exact options are in `build-manifest.json`.
- Actual editor image: `smoke/unfair-editor.png`; machine-readable theme result: `smoke/editor-qa-result.json`.
- Production vectors parse; white transparent symbol alpha, splash dimensions and multi-size Windows icon verified.
- macOS plist, Linux desktop and Android XML/config display-name changes parse; executable IDs, file associations and legal notices preserved.

The initial full native suite had 1433 cases pass and one fixture failure: the PCK
test assumed the old Godot artwork's byte size. The packer itself accepted all
files. Its test now compares archive size against all payloads written, including
the original PNG entry before its path is overridden, with a bounded allowance
for metadata/alignment; it does not pad artwork or change
packer behavior. The full suite subsequently passed. Negative drawing tests
emit expected draw-context diagnostics while the suite reports success. Vulkan
emitted a nonfatal loader warning about layer-manifest registry lookup; startup,
theme checks and rendered capture still succeeded.

## Practical limits

This validation does not prove every workflow or platform has identical behavior.
Other platforms' metadata/assets were prepared but their binaries were not built.
Export templates for this custom engine build are not packaged. Export across all
platforms, screen-reader operation, high-DPI combinations, custom plugins and
every renderer need their own release regression pass. Upstream MIT/third-party
credits and Godot compatibility names remain intact.

The `bin/_sc_` marker enables portable editor settings under `bin/editor_data/` for
this tested build. The GDScript smoke project uses the normal engine file formats.
