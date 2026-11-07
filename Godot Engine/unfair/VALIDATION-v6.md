# UNFAIR-006 validation

Windows x86_64 developer build: tests=yes, angle=yes, optimize=none, debug_symbols=no.

Delivered `bin/Unfair.exe` SHA256: `4cfa0382be31960db26cce579a7d5957871417406c20aebcc6ac9734d9fd3d49`. It matches the compiled executable. Previous EXE and console launcher remain as `Unfair.before-loading-v6.exe` and `Unfair.console.before-loading-v6.exe`.

## Verified changes

- AI Assistance has real CanvasItem child alpha clipping and a Windows native rounded region. Native probes exclude the outer/client corner and include the center. Caption, resize and window controls remain native.
- Initial opening, 640x480, an oversized/offscreen saved rectangle, close/redock/reopen all remain inside the monitor work area, including native decorations. Header actions and footer remain visible; the body scrolls.
- Mouse hover and press/release hit-testing activated Enable, Copy configuration, Compact, Export and Disconnect. The QA injects native-window coordinates after establishing the actual native pointer hover, instead of emitting Button.pressed directly.
- Real AI MCP integration passed 23 cases, private protected Windows DACL checks, connection/EOF/disconnect, token-free export, dark/light UI and rounded alpha pixels. Protocol unit tests passed 11 cases using the bundled Python.
- Loading uses the generated monochrome blurred atrium artwork. Actual editor startup steps 0..4/5, filesystem scanning, texture reimport and the existing cancellable class scan were observed. No fabricated progress tasks or artificial loading delays were added.
- Installed artwork and the compiled fallback both match the reference image's decoded pixel SHA256. Both produced 10 nonblank native captures; first startup cards fit their viewport at 668x342 / 668x352. Credits include “Built on Godot Engine.”
- Core suite passed 1434 cases / 425416 assertions, with 3 skips. GDScript/scene save-load smoke passed. Existing workspace, tool windows, transport and dark/light native caption regression passed.

## Installer

`unfair/installer/dist/install.exe` is a per-user NSIS 3.13 LZMA package with 55 explicitly listed files. EXEs, DLL, artwork, AI companion and the official isolated Python runtime remain ordinary visible files. No source tree, test projects, backups, portable editor settings or session credentials are packaged.

- Final install/upgrade/uninstall passed with every installed file hash checked. Uninstall removed owned payload and retained nested projects and unknown files.
- Fresh path validation, drive/home/relative path rejection and an existing unmanaged nonempty directory were tested without overwriting sentinel files.
- A GUID-isolated normal-mode installation tested HKCU metadata and all four shortcut targets; its uninstaller removed them. Production Unfair registry/shortcut snapshots and release source remained unchanged.
- The final installer was installed again without a portable marker. That installed Unfair passed the complete AI UI/native MCP test using its bundled Python, then the test installation was removed.

Installer SHA256: `cc22f744dee19853cd2fbae4f8d27a9a8e43e7142a28d33a1bd7a0fd41c7e761`.

## Evidence and limits

Workspace logs: `unfair-v6-build.log`, `unfair-v6-tests-final.log`, `unfair-v6-smoke-final.log`, `unfair-v6-workbench-qa.log`, `unfair-v6-ai-native-qa.log`, `unfair-v6-installed-ai-qa.log`, `unfair-v6-installer-final-qa.log`. Loading JSON/captures and native region/ACL evidence are under `unfair/smoke/qa-output`; installer lifecycle reports are under `unfair/installer/build`.

The final loading tests logged an existing window-hover warning during popup transitions, without runtime/script errors or failed assertions. Cancellation was exercised through the existing button signal/handler during a real task; it was not an OS pointer click test. Native suite negative drawing cases intentionally log drawing errors.

This is an unsigned developer build. Checks cover this Windows/OpenGL host and smoke project, not every plugin, display scale, monitor arrangement, export target or operating system. The installer finish-page folder checkbox exists in source; silent tests do not interact with that page. Windows native corner policy may vary by OS, with the explicit region providing the tested host behavior.
