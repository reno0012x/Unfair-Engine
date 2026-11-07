# Unfair AI Assistance: foundation and upgrade ideas

## Scope chosen for version1

Native status/tool-directory UI plus read-only MCP tools. The model runs in an external MCP client. Unfair exposes editor state and reports the requests it actually receives; it does not infer private reasoning, discover an arbitrary AI model on the computer or monitor unrelated shell/file operations.

The native bridge is opt-in and loopback-only, authenticated with a per-enable random token. A Python stdio companion implements the MCP lifecycle and tool messages. The editor stays on its main thread for scene access. Each read has schema checks and output/path bounds.

Initial tools: project.overview, scene.inspect, editor.selection, files.search, files.read and tools.search. A cached file index, node metadata, line ranges, result limits, revisions and schema-free catalog search reduce context volume. Actual token savings require measurement with the consuming client/tokenizer; bytes and call counts do not equal tokens or API cost.

The dedicated UI uses rounded surfaces and three colored controls: disconnect all, collapse activity and detach the panel. This appearance applies only to AI Assistance. Native OS caption controls retain their normal behavior. Activity records include client, tool, target node/file/lines, outcome and duration. Identity/model labels are explicitly client-reported. Markdown export records these observations without credentials.

## Suggested priorities after the read-only foundation

1. **Context packets:** collect the selected node, relevant properties, connected signals, attached script symbols and nearby diagnostics in one bounded response. Return resource IDs/revisions so unchanged material can be reused.
2. **Scene Diff and Undo transactions:** preview the nodes/properties/files a proposed operation changes. Apply structured editor operations as one undoable action, with stale-revision/conflict checks. Avoid arbitrary code execution as the default editing interface.
3. **Checkpoints:** link an AI task to a snapshot or source-control change, verification result and rollback point. Rollback must preserve unrelated user edits.
4. **Diagnostics and verification:** attach parser errors, runtime stack traces and scene-validation results to the relevant file/node. Mark a change verified only after a concrete check runs.
5. **Multiple-agent coordination:** show task ownership, read/write intent and conflicting edits. Connection identity alone is insufficient to coordinate writers; use leases/revisions once mutation tools exist.
6. **Dependency-aware asset browser:** show which scenes use an asset and what a rename/move will affect. Reuse Godot's resource UIDs and dependency metadata.
7. **Profiler comparison:** compare measured frame time, draw calls and memory for a fixed scene/run. Associate proposed optimizations with before/after measurements.
8. **Workspace presets and command search:** task-oriented layouts for level design, scripting, animation and debugging; surface existing commands through search and shortcuts.

## Existing Godot extension points checked

The source includes EditorInterface, EditorPlugin/EditorDock, EditorDebuggerPlugin, GDScript's language server and debug-adapter integration. These are useful building blocks; LSP/DAP are not MCP. No ready-made native AI session/activity MCP system was found in the inspected source paths. This is a scoped source inspection, not proof about every third-party Godot plugin.

Sources: [Godot EditorInterface](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html), [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html), [external-editor LSP/DAP](https://docs.godotengine.org/en/latest/tutorials/editor/external_editor.html), [MCP lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle), [stdio transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports), [MCP tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).
