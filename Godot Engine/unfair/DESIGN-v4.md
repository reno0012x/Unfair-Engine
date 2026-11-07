# Unfair navigation and tool windows

- Project Manager navigation uses real button backgrounds instead of flat drawing. Library/Asset Store retain selected state; About and Settings remain active while their dialogs are open. Utility and project-row hover/selection surfaces remain distinct.
- The reference-derived Unfair symbol has its own40px editor SVG with tight artwork bounds. Header and Project Manager display a36px mark beside the bold wordmark. Theme conversion keeps it readable in dark and light themes.
- The byte-identical upstream Godot template project icon is displayed as Unfair in the library. Exact SHA256 matching is limited to small SVGs. Custom icons and project files are preserved.
- Compact16px Undo/Redo icons sit beside Content Browser and invoke the same editor history commands as the existing menu/shortcuts. Enabled states follow history signals. The folder icon is capped at16px.
- Project title aligns at the right of the application header. Workspace tabs retain centered positioning where space permits. At compact widths the asset button reads “Content” to keep all controls within the viewport.
- Windows menu uses tool icons and separators between workspace docks, editors, bottom tools and workspace actions. It includes Output, Debugger, Audio, Animation and Shader Editor.
- Open in Window on the bottom strip detaches the selected tool. Closing a detached window returns it to its dock; Return All Tool Windows handles multiple windows. Collapsed tools with uninitialized rectangles receive a valid default rectangle before monitor lookup.

All existing project formats, GDScript behavior and undo histories remain on their original code paths. Results and remaining limitations are recorded in VALIDATION-v4.md and the workspace WORK_STATUS.md.
