# Unfair workbench redesign — UNFAIR-002

This revision changes native composition and navigation as well as theme colors.
The six user screenshots are the design brief. The previous palette-only design
is retained in the history of `../../WORK_STATUS.md` at workspace level.

## What changed

- **Window chrome:** Windows native titlebars now follow the application theme,
  including newly created dialogs and detached tools. Windows 11 supports exact
  caption/text/border colors; this Windows host supports dark/light caption mode.
  Native drag, Snap, resizing, close/minimize/maximize and High Contrast remain.
- **Project library:** left navigation rail, UNFAIR header, clear New/Open Project
  actions, separate search/sort row and a wrapping selection-action shelf instead
  of the tall disabled right toolbar.
- **New Project:** details/location and rendering cards, renderer help and
  capability checks, compact scrollable form, explicit Create Project action.
  Import, rename, duplicate, install, Git/None and original validations remain.
- **Directory picker:** editor-only opt-in redesign with labeled navigation,
  address row, view/filter/sort controls, Favorites/Recent guidance and a live
  confirmation path. Generic runtime FileDialog keeps its existing layout.
- **Workbench:** branded application menu row; dedicated command row with Content
  Browser, workspace tabs, labeled Play/Pause/Stop and Windows menu. The default
  layout puts Content Browser below the viewport and History with Inspector.
  Existing project layouts remain intact until the user chooses **Windows → Reset
  to Unfair Workspace**. Existing saved default layout preferences are not deleted.
- **Separate tools:** Windows menu exposes Content Browser, Scene Outliner,
  Inspector, Script and 3D windows. It focuses existing windows, uses practical
  default dimensions, respects multi-window and feature-profile restrictions, and
  uses the original dock/WindowWrapper lifecycle to return tools to the workspace.
- **3D preview:** neutral charcoal studio sky/ground/horizon, quieter grid and
  neutral default selection. RGB orientation axes and custom colors remain.
  Only temporary editor preview defaults change; scene materials, environments,
  lights and gameplay rendering are preserved.
- **Visual identity:** original consistent stroke navigation/transform/transport
  icons, high-contrast primary and selected-tab states, clear keyboard focus,
  larger default UI text, and a bold wordmark. User font overrides are preserved.
- **Logo:** reference image 5 was refined with built-in image_gen and reconstructed
  into clean vector geometry retaining its triangular notch and diagonal slash.
  Inter Bold outlines replace the old thin lettering. See `branding/PROMPT-v2.md`.
  New projects receive the Unfair default icon; existing user project icons are
  deliberately preserved.

## Implementation boundaries

GDScript, public engine APIs, project.godot/.godot formats and saved scenes retain
their existing names/behavior. All MIT/third-party credits remain. The native
directory picker presentation is enabled through EditorFileDialog only.

Unreal's independently dockable tool windows and explicit navigation informed the
workflow, using its [official layout documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/layout-customization?application_version=4.27).
No Unreal artwork, branding or source was copied.

## Reproduce validation

- Build: `unfair/build-windows.ps1 -Python <python.exe> -Portable`.
- Native UI QA: `unfair/verify-workbench.ps1 -Mode ProjectManager`, then `-Mode Editor`.
- Titlebar read-only probe: `unfair/verify_titlebar.ps1 -ProcessId <exact PID>`.
- Native regression: `bin/Unfair.console.exe --headless --test`.
- GDScript smoke: `bin/Unfair.console.exe --headless --path unfair/smoke --script smoke.gd`.

UI QA scripts exercise native controls inside the isolated smoke project, capture
the engine's real viewport output, and restore the application theme. They are
not mockups. Output is in `smoke/qa-output/`, excluded from asset imports.

Runtime evidence and remaining release checks are recorded in `VALIDATION-v2.md`.
