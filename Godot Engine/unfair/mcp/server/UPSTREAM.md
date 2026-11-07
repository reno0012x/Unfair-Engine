# Unfair MCP provenance

- Upstream: https://github.com/Coding-Solo/godot-mcp
- Pinned source commit: `1209744fad78f3998f98c7394fd0f6ef50da5281`
- Fork name/version: `unfair-mcp` / `1.0.0`
- License: MIT; the upstream copyright and permission notice remain in `LICENSE`.
- Dependency versions remain those of the pinned upstream lockfile. No MCP SDK
  migration is implied by this fork's version number.

The fourteen upstream tool names and their input schemas remain available,
including the legacy `get_godot_version` name and snake_case/camelCase aliases.
Added tools are `get_engine_diagnostics` and `search_tools`. Catalog descriptors
include read/write/process annotations.

Fork changes include Unfair-first executable discovery, bounded subprocess
execution and output capture, root-relative resource path validation, ESM file
reading, reliable nonzero operation failures, EOF cleanup of owned run processes,
and preservation of opaque node-property keys. Launched GUI editors are user-owned
and are not terminated by `stop_project` or MCP shutdown.

Executable precedence is `UNFAIR_PATH`, a bundled Unfair executable, an explicitly
configured path, `GODOT_PATH`, then platform detection. An invalid explicit
`UNFAIR_PATH` fails rather than selecting an unrelated engine. An optional
`UNFAIR_PROJECT_ROOT` restricts tools to one project. Resource inputs accept
`res://` or project-relative paths and reject traversal, absolute escapes and
linked existing ancestors. Validation is a preflight check; project resources and
scripts run by Godot remain executable project content, not a filesystem sandbox.

`UNFAIR_HEADLESS=1` adds `--headless` only to `run_project`, for automated tests.
`UNFAIR_GODOT_DEBUG=true` explicitly enables upstream verbose GDScript diagnostics;
leave it unset for normal use because upstream debug logs may contain operation
parameters and environment paths. Server diagnostics use stderr; stdout is MCP.

This server operates through CLI/headless subprocesses and saved resources. It
does not claim to inspect the running editor's unsaved scene, current selection,
or native AI sessions. Use the separate authenticated Unfair native AI bridge for
live read-only editor context. Editing tools here can change saved project files;
their annotations do not authorize unrelated actions.
