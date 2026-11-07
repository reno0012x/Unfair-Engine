# UNFAIR-008 — AI Assist toolbar and window polish

Delivered Windows x64 developer executable: `bin/Unfair.exe`.
SHA256: `06d11cd72701dc78c3d638398612f9f577d5544294053bd38b87bd6e3427703c`.
It matches the compiled editor. Previous executable/console are retained as
`Unfair.before-ai-ui-v8.exe` and `Unfair.console.before-ai-ui-v8.exe`.

## Changes

- AI Assist now precedes Content Browser, Undo and Redo in the command toolbar,
  instead of occupying the project/title header. The icon is capped at 16px;
  active state follows the actual dock/window visibility and theme icons refresh.
- Desktop workspace tabs stay centered. At compact widths AI/Content use shorter
  labels and Windows uses its icon with a tooltip/accessibility name. All existing
  menu actions remain available; the command bar fits 1152px.
- AI Assistance has a balanced heading/status row, compact Connect/Copy actions,
  collapsible Connection settings, labeled client/activity sections with honest
  empty states, and one footer row for statistics and export. Long content scrolls.
- The AI window keeps an opaque normal Windows HWND. The previous custom HWND
  region and native transparency combination is removed; it produced a legacy
  looking frame on this host. An inset card retains real rounded child clipping.
- Native caption, resize, minimize/maximize/close, editor theme state and window
  recovery are preserved. Windows 11 receives a system corner preference hint;
  Windows 10 retains its normal native outer frame rather than forcing its shape.
- Bridge behavior, the six native read-only tools, external Unfair MCP package,
  GDScript behavior and existing project files were not redesigned in this task.

## Verification

- Final native AI QA passed: initial opening, 640x480, offscreen/oversized rectangle
  recovery, close/redock/reopen, toolbar order/active state, advanced settings,
  empty states, connect/copy/collapse/export/stop, and dark/light appearance.
- The final interaction harness sends viewport ScreenTouch press/release events
  through normal GUI hit-testing. It does not emit those action signals directly
  or move the user's OS pointer. An earlier integration run also passed mouse
  hover/press/release; the final harness avoids dependence on desktop foreground.
- A temporary magenta child polygon verified actual child clipping: its center
  rendered while its rounded-corner pixels were excluded. It was removed before
  UI captures. The opaque host intentionally has no transparent outer pixels.
- Native proofs in both themes observed no custom HWND region (GetWindowRgn=0),
  DWM non-client rendering enabled, visible/available minimize/maximize/close, and
  dark mode true/false as expected. PrintWindow captures include the native frame.
- Native MCP integration passed 23 cases, private Windows ACL checks and activity
  export/token exclusion. The final GUI log has no ERROR or SCRIPT ERROR entries.
- Workbench regression passed at 1600 and 1152px, including existing history
  Undo/Redo, centered tabs, tool detachment/redocking, transport and native
  dark/light folder captions. One existing window-hover warning was observed.
- Native core regression passed 1434 cases / 425416 assertions, 3 skips; typed
  GDScript and scene save/load smoke passed during integration. Negative drawing
  unit tests intentionally print errors while their assertions pass.

## Evidence and limits

The updated LZMA installer `unfair/installer/dist/install.exe` has SHA256
`eb762646454e79d0e3cb462af30ac633dd9454aa8ed66ce25e012160ff622534`.
Final installation/upgrade/uninstallation passed with all 55 payload file hashes
checked; nested project and unknown sentinel files survived uninstall. See
`unfair-v8-installer-build.log`, `unfair-v8-installer-qa.log`, and
`unfair/installer/build/installer-qa.json`.

The user's installed Codex Unfair MCP still initialized and exposed all 16 tools
against the updated engine; diagnostics passed without changing its configuration.
See `unfair/smoke/qa-output/v8-installed-mcp-diagnostics.json`.

Workspace logs: `unfair-v8-build.log`, `unfair-v8-ai-native-qa.log`,
`unfair-v8-ai-runner.log`, `unfair-v8-workbench-qa.log`, `unfair-v8-tests.log`,
`unfair-v8-smoke.log`. Captures/native frame data are under
`unfair/smoke/qa-output`: `unfair-v8-workspace-toolbar.png`,
`unfair-v8-ai-native-dark.png`, `unfair-v8-ai-native-light.png`,
`v8-ai-native-frames.json`, and the latest workbench compact capture.

These checks cover this Windows/OpenGL host and the smoke project. They do not
establish every monitor/DPI arrangement, plugin, translation or OS. Exact native
caption RGB is Windows-version dependent; dark/light state and controls are
verified. The existing native/external MCP bridges remain separate as documented
in the MCP guide. This remains an unsigned developer build.
