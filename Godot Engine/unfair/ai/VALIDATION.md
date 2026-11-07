# AI Assistance v1 validation

Revision UNFAIR-005. Delivered Windows x86_64 developer build, tests=yes, angle=yes, optimize=none.

SHA256 `bin/Unfair.exe`: `ED510ADEDAAF1817DA0165DCBBA94D548154FF7F499CBCD2AFF7481504E7CCEE`.
The delivered executable matches the compiled/tested binary. Companion and quick-start documents are installed beside it under `bin/unfair_ai/`. Previous executable/console retained as `Unfair.before-ai-v1.exe` and `Unfair.before-ai-v1.console.exe`.

## Results

- Final native build passed (`unfair-ai-build.log` in workspace root).
- Native core suite:1434 passed,0 failed,3 skipped;425416 assertions passed (`unfair-ai-tests-final.log`). Expected negative drawing tests print errors while assertions pass.
- Typed GDScript/lambda/native-class/theme and scene pack/save/load passed (`unfair-ai-smoke-final.log`).
- MCP companion:11 subprocess/fake-TCP tests passed (`unfair-ai-protocol-tests.log`). These cover lifecycle, UTF-8, bounds, malformed messages, configuration reload, authentication/redaction, disconnect without replay and EOF cleanup.
- Real native integration:23 cases passed, using the Python stdio companion connected to the running editor. All six tools, real scene/selection and bounded file reads worked. Invalid names/types/ranges, Boolean/fractional counts, traversal, hidden/private paths, wrong credentials and malformed native JSON were rejected. Queries succeeded again after errors. The child exited0 after stdin EOF and the session changed to Disconnected.
- Native UI QA passed: initial Offline state, opt-in Ready state, generated MCP configuration, actual connected client/model labels, activity/targets/line ranges, tool directory, compact control, stop/config revocation, detached window and dark/light appearance.
- Markdown export was tested with a fresh filename and checked for actual `files.read` and `res://smoke.gd:1-3` records. The exported log did not contain the authentication token. Unique filenames avoid mistaking an old file or an unanswered overwrite confirmation for success.
- Windows connection-file ACL was observed while enabled: protected DACL, only current user SID and SYSTEM, no inherited rules. Stopping removed the per-instance config. Creation is exclusive/atomic and credentials are never copied into the client config or activity records.
- Existing Editor workbench regression passed again: toolbar Undo/Redo history,1600/1152 layouts, Content Browser/output exclusion, five detached bottom tools, Script minimize/restore/redock, transport and native dark/light titlebar checks (`unfair-ai-workbench-regression.log`).

## Evidence

- `unfair/smoke/qa-output/ai-qa-result.json`, `ai-private-config-acl.json`, latest `native-*-result.json`.
- `unfair/smoke/qa-output/unfair-ai-*.png`: native viewport captures of Offline, Ready, Connected activity, tool directory, Disconnected and Light.
- `unfair/smoke/qa-output/unfair-ai-activity.md`: actual exported activity; Error rows in these fixtures are intentional rejection tests, not failed test cases.
- Final native UI log `unfair-ai-native-qa.log` contains no ERROR/SCRIPT ERROR entries.

## Findings fixed during integration

- Godot JSON numbers arrive as FLOAT: validate finite integral values/ranges before casts, while rejecting Boolean/string/fractional values.
- Redact secrets before truncating client metadata and log only catalog-recognized tool names.
- Preserve successful target scene/node and actual file line ranges in activity.
- Avoid restoring main-window focus for already-hidden wrappers or during normal editor exit; this prevents late focus callbacks reaching detached debugger sessions during teardown.
- Replace narrow C++ non-ASCII punctuation that the current MSVC source encoding rendered incorrectly.

## Limits and deferred work

Read-only tools do not execute code, change scenes or write project files. Enabling the bridge creates private editor connection metadata, and the user can explicitly export a Markdown log. Client/provider/model identity is self-reported. Unfair observes only calls through this bridge, not arbitrary external AI activity. Context limits reduce response volume; no token/cost saving percentage was measured.

The current file reader is limited to recognized UTF-8 text files no larger than64KiB, with at most200 returned lines. File name filtering cannot detect secrets stored under innocuous names. Windows canonical-path checking and reading use the same opened handle; equivalent non-Windows TOCTOU resistance, multi-user attacks, all clients/plugins/DPI arrangements and exports were not exhaustively tested. This remains a Windows developer build.

Rounded styling and colored controls are implemented; true rounded content/window clipping is deferred as the user requested. Generated blurred loading artwork and installer/uninstaller packaging with visible EXE/DLL/assets/tools are also deferred. No new loading image or installer was created in this task.
