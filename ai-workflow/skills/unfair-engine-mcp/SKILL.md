---
name: unfair-engine-mcp
description: Use the installed Unfair MCP tools to inspect, launch, run, debug, or edit saved Unfair/Godot project scenes and resources. Applies to concrete engine-project work and MCP connection troubleshooting; does not replace Unity or Unreal workflows.
---

# Unfair Engine MCP

## Connect and select the project

- Discover tools from MCP server `unfair-engine` (often exposed as
  `mcp__unfair_engine__*`). Call `get_engine_diagnostics` when starting work or
  troubleshooting a connection. Use the reported executable/version rather than
  assuming a Godot executable on PATH. `get_godot_version` is the retained legacy
  tool name and also works with Unfair.
- Establish the actual project root: the directory containing `project.godot`.
  A parent folder is not necessarily the project. If uncertain, use `list_projects`
  on the user-selected directory with `recursive: true`, then choose the matching
  project. Use `get_project_info` to confirm its configured name and contents.
- Inputs use an absolute `projectPath`; resource paths use `res://` or a path
  relative to that project. Keep GDScript, .tscn/.tres, and project.godot naming.
- If tools are unavailable, inspect the existing client registration and package
  before reinstalling. Installed package `doctor.ps1` verifies hashes/runtime;
  `install.ps1` registers the MCP server. Do not overwrite unrelated client entries
  or ask for API tokens; this local stdio bridge does not require an LLM API key.

## Choose the smallest useful tool call

Use `search_tools` with a purpose/query for compact summaries. Request
`includeSchemas: true` only for relevant unfamiliar tools; do not repeatedly dump
the complete catalog or entire project when a targeted query is sufficient.

| Goal | Tools / decision |
| --- | --- |
| Inspect saved project metadata | `get_project_info`, `get_uid` |
| Open the actual editor | `launch_editor` |
| Observe runtime behavior | `run_project` → `get_debug_output` → `stop_project` when the task requires stopping the owned run |
| Create a saved scene | `create_scene` with an appropriate root node type |
| Extend a saved scene | `add_node` with the intended parent path/type/name/properties |
| Attach an imported sprite | `load_sprite` targeting an existing Sprite2D |
| Save in place or make a variant | `save_scene`, optional `newPath` |
| Build a GridMap MeshLibrary | `export_mesh_library` from a scene with actual meshes |
| Explicit UID maintenance | `update_project_uids`; bulk-resaves resources, so use for requested UID repair rather than routine editing |

Preserve node-property names and values; snake_case/camelCase operation aliases do
not justify renaming dictionary keys in `properties`. Treat tool errors and missing
resources as incomplete work. Narrow or correct a failing call using its evidence.

## Saved files and live editor context are different

These 16 tools operate through CLI/headless processes on saved project resources.
They do not inspect unsaved editor scenes, selection, or the live Undo history.
Before editing a file also open in the editor, check for unsaved changes and avoid
overwriting them. Save/reload at a suitable point; ask only if needed to resolve
an actual conflict with user work. Make a variant when that suits the request.

Native **AI Assistance** is a separate read-only live-editor bridge. Its Connect
and Copy MCP config actions are needed for clients using that bridge. Do not claim
that CLI MCP calls appear in its Activity table or that its client/model labels
prove identity. No LLM/chat model is embedded by installing this skill or MCP.

## Verify the requested result

- After scene/resource edits, inspect the resulting file/resource or run the
  relevant scene when warranted. Verify actual behavior, not just a successful
  tool response. Preserve existing root UIDs and references when editing resources.
- The fork maintains text .tscn/.tres external UIDs and imported texture UIDs.
  Uncompressed binary root UIDs can be preserved, but binary external UID refresh
  is unsupported; compressed binary UID edits reject. Use editor resave for that
  case rather than repeatedly retrying or claiming full compatibility.
- Debug capture is bounded to 128 KiB / 1500 lines per stream. Collect it promptly;
  an absent earlier line may have been evicted. Owned runtime processes are stopped
  on MCP EOF; launched GUI editors remain open for the user.
- Match checks to the task and report what was actually verified. Do not promise
  every plugin/platform/DPI or a running editor state from a headless test.
- Follow applicable project AGENTS.md/work-log guidance. Keep engine source changes
  separate from game-project edits unless the user requested both.
