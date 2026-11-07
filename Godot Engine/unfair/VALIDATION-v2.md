# Unfair workbench validation

## Verified in this revision

- Final native regression: **1434 cases passed, 0 failed, 3 skipped; 425416
  assertions passed**. Typed GDScript/lambda/native class/Theme and scene-save/load
  smoke also passed on this revision's executable.
- Windows x86_64 developer editor builds with MSVC/Windows SDK, AccessKit, Vulkan,
  Direct3D 12 and ANGLE enabled; no runtime engine modules were removed.
- Native Project Manager opens, New Project opens, and its Browse action opens
  the actual redesigned EditorFileDialog. The QA run cancels without creating a
  project or altering a user's project files.
- New Project and directory-picker heights are bounded after fixing initial
  autowrap minimum-size inflation.
- Editor command bar/workspace tabs and viewport render at 1600×980 and 1152×800.
- Folder confirmation emits the current directory correctly.
- Script tool detaches, an existing detached tool can be focused, and closing
  its window returns it to the workspace.
- DWM attribute 20 follows dark/light application themes on the main editor and
  folder dialog; detached Script and Project Manager dialogs inherit dark mode.
- Final Project Manager and workbench machine-readable results both report
  `pass: true`; the workbench run additionally verifies Light theme regeneration
  through the same settings notification used by Editor Settings, restores Unfair,
  and checks that workspace tabs are not clipped.
- Native generated SVG/PNG/ICO/ICNS and startup splash use the revised U symbol
  and bold wordmark; prompt/provenance and original asset backups are retained.

## Evidence locations

- `../../unfair-v2-build.log`: latest successful build.
- `../../unfair-v2-tests-final.log`: native regression result.
- `../../unfair-v2-smoke-final.log`: GDScript/scene save-load result.
- `../../unfair-v2-pm-qa.log`, `../../unfair-v2-editor-qa.log`: native UI QA logs.
- `smoke/qa-output/project-manager-qa-result.json`, `workbench-qa-result.json`.
- `smoke/qa-output/pm-titlebar-probes.json`, `editor-titlebar-probes.json`.
- `smoke/qa-output/unfair-v2-*.png`: actual engine-rendered views/dialogs.
- `build-manifest-v2.json`: final executable hash and test counts.

## Limits

This is a development build, not a signed optimized release or a promise of 100%
parity across every engine workflow. The native suite deliberately skips three
cases. Negative drawing tests emit diagnostics while their assertions succeed.
This host does not support DWM attributes 34–36 for exact caption RGB; dark/light
mode is verified here, while exact Windows 11 color behavior still needs a Windows
11 machine. The screen capture omits OS-drawn chrome; the DWM probe supplies its
state independently.

macOS/Linux/Android executables, all plugin/DPI/language combinations, screen-reader
operation and a full export-template matrix have not been release-tested in this
revision. Custom export templates are not included. Existing project icons and
layouts are retained; use the reset command to adopt the new workspace arrangement.
