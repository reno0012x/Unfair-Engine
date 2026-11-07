# Unfair MCP 1.0.0 validation — UNFAIR-007

Adapted from Coding-Solo/godot-mcp commit `1209744fad78f3998f98c7394fd0f6ef50da5281`, with the upstream MIT copyright/permission notice retained. This is a local fork and distributable; no public repository, npm registry or marketplace publication was performed.

## Delivered and installed

- Windows x64 ZIP: `dist/unfair-mcp-1.0.0-windows-x64.zip` (38,464,566 bytes).
- ZIP SHA256: `e411e8d27b023e963a1a75e6d30b1eba78e7989bb27282d988fe2b0b24583dc6`.
- Manifest SHA256: `8f5a1d9aaa7b84cc56c645a99ec2b5a7747bd80952ecfd9e4a55323e5e9364c8`.
- 606 explicitly hashed visible files, including Node 24.22.1 x64, its runtime DLLs and exact official Node license; production dependencies installed with `npm ci --omit=dev --ignore-scripts`. Development dependencies, test fixtures, private configs and source `.git` directories are excluded.
- Installed for the user at `C:\Users\LEONIDASxII\AppData\Local\Unfair\MCP\1.0.0-8f5a1d9aaa7b`.
- Registered Codex stdio server `unfair-engine`, using its installed `runtime/node.exe`, `build/index.js` and `UNFAIR_PATH=A:\Game Engine\Godot Engine Remake\Godot Engine\bin\Unfair.exe`.
- Backed up the user's original Codex configuration beside the original file before registration. Existing settings and `node_repl` remain semantically equivalent. Codex CLI omitted the previous default empty `args=[]` array while serializing; no other semantic changes were found.
- The actual installed server passed initialize, tools/list (16 tools), engine diagnostics, stdin EOF and Doctor verification of every installed file hash and both executables. Codex discovers the registration in a new chat/client session; this existing chat's tool inventory is not evidence of hot reload.

## Native compatibility checks

The final distributable was tested using its own bundled Node and production dependencies against delivered Unfair.exe, in a newly created project with spaces and Thai characters in its directory name. All 14 upstream tools and both added tools passed real execution:

- `launch_editor`: started the real editor; a test-owned plugin closed the fixture editor.
- `run_project`, `get_debug_output`, `stop_project`: captured actual running project output and stopped only the process owned by this MCP instance.
- `get_godot_version`: returned the actual Unfair engine version, retaining the upstream tool name for compatibility.
- `list_projects`, `get_project_info`: found the native fixture and read its configured project name.
- `create_scene`, `add_node`, `load_sprite`, `save_scene`: persisted native scene/node/texture references and a scene variant. Both camelCase and snake_case arguments were exercised.
- `export_mesh_library`: produced a real MeshLibrary from a BoxMesh scene.
- `get_uid`: resolved an imported texture's UID from its import metadata.
- `update_project_uids`: saved at least five native resources, created a deliberately missing script sidecar, retained the original scene root UID and refreshed the scene's external script UID.
- `get_engine_diagnostics`: verified the actual executable/runtime.
- `search_tools`: returned compact summaries by default and full schemas only when requested.

Negative tests rejected traversal, absolute and user:// output escapes, unknown tools and invalid native classes, without modifying the existing scene. A noisy project emitted over 128 KiB; each stream stayed within 1500 lines / 128 KiB. EOF shut down the MCP server and the exact QA-owned running process.

The tests assert actual file contents and UID identity across separate headless processes. They exposed and fixed upstream false-success paths, the absolute project path incorrectly prefixed with res://, texture UID lookup limited to sidecars, and headless ResourceSaver removing resource identity without the editor filesystem's UID callback.

## Installer tools

`install.ps1`, `uninstall.ps1`, and `doctor.ps1` were tested with an isolated workspace Codex home. Checks passed for actual registration, bundled runtime paths, all installed hashes, repeat installation of the identical release, unmanaged directory rejection, matching registration removal and complete pristine uninstall. A nested user project and a modified README survived uninstall. No global Node/npm installation is required.

Installation is per user and content-versioned. The tool refuses to replace an unrelated MCP registration; it does not set auto-approve policies. A JSON config is provided for other stdio MCP clients, but their graphical setup workflows were not tested.

## Limits

- Verified on this Windows x64 host with Unfair 4.8, not every Godot version, project, plugin, language, export target or OS.
- Dependency versions remain pinned to upstream, including MCP SDK 0.6.0; this fork does not claim an SDK migration. Its negotiated protocol was tested through actual stdio.
- Scene operations use saved resources via headless engine processes, outside the running editor's Undo history. They can execute trusted project classes when instantiated. Path preflight is not a sandbox for project scripts.
- The separate native AI Assistance bridge supplies live read-only editor context. This CLI MCP's calls are not forwarded into its Activity table.
- Text `.tscn/.tres` root/external UIDs are maintained. Uncompressed binary `.res/.scn` root UIDs can be read and preserved, but binary external UID refresh is not implemented. Compressed binary UID edits reject before modifying that resource. Use editor resave for those cases; `update_project_uids` reports its binary limitation explicitly.
- The package is not code-signed. No public hosting/publishing account was used.

## Evidence

- `qa-output/package-native-mcp.json` and its log: actual final-package native tests.
- `qa-output/install-qa.json` / log: isolated installation, repeat install and uninstall.
- `qa-output/user-install-verification.json`, `user-install.log`, `user-doctor.log`: actual user installation and verification, without tokens or copied private configuration.
- `packaging/build-record.json`: production packaging record; complete hash manifest is inside the ZIP.
- Source/provenance: `server/UPSTREAM.md`, `server/LICENSE`; Thai usage: `README-th.md`.
