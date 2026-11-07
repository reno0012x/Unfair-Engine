# Unfair native editor design

Unfair is a visual fork of Godot 4.8 beta. The native editor and project manager
share a new default Unfair preset; the existing dock layout, commands, shortcuts,
GDScript language, file formats and runtime systems remain in place.

## Reference research

- [Unreal Editor interface](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-editor-interface): clear separation between main toolbar, viewport tools, outliner, details and content. Adopt restrained surface hierarchy and a viewport-first layout while retaining Godot's docking model.
- [Unity Editor interface](https://docs.unity.com/en-us/engine/6000.5/manual/unity-editor): consistent hierarchy, inspector and project windows with customizable layouts. Adopt consistent input, selection and focus treatment across the native shared controls.
- [Stride Game Studio](https://doc.stride3d.net/4.3/en/manual/game-studio/index.html): asset view, property grid and contextual preview. Adopt a quiet workbench around user content and legible asset rows.

These references inform the design direction; no third-party logos or UI assets are copied.

## Visual system

- Near-black canvas and neutral raised panels; default base RGB 0.082, white accent RGB 0.94.
- Thin neutral borders, white focus outlines, restrained corner radii, stronger hover surfaces and a clear pressed state.
- White-on-charcoal text with muted secondary labels and readable placeholders.
- Grayscale application chrome; retain error/warning indicators, axis and gizmo colors because those carry editing information.
- Preserve native theme scale, layout preferences, keyboard focus and all alternative themes.
- Native progress panel entrance: 120ms ease-out from 82% opacity, immediate interaction, native indeterminate progress where step count is unknown. Disable cosmetic animation with `interface/editor/appearance/reduce_motion`.

## Brand assets

`branding/unfair-ai-concept.png` is the built-in image_gen result. The production
symbol is an original clean geometric reconstruction of its asymmetric U concept.
The wordmark uses original geometric strokes rather than an embedded font.

Regenerate production assets with `python unfair/generate_brand_assets.py`
(Pillow required). Original replaced assets are preserved once under
`original-assets/`. Stable Godot asset keys and filenames are retained where build
scripts or saved projects depend on them; their artwork is Unfair.

The source copyright, MIT license, third-party credits and upstream links remain.
The visible application name is Unfair. Internal `short_name = "godot"` preserves
configuration/data locations and compatibility identifiers.

## Acceptance gates

Source changes alone do not establish 100% behavioral parity. Before a release:

- Compile the Windows editor with existing rendering and accessibility drivers.
- Run unit tests and a headless GDScript smoke project.
- Open the project manager, create/import/open a project and verify branding/splash.
- Check 2D/3D/script workspaces, docking, inspector, search, menus, dialogs, settings,
  keyboard navigation, hover/pressed/disabled/focus states and reduced motion.
- Save and reopen existing projects and exercise debugger, play, import and export.
- Check alternate DPI scales and other supported platforms separately.

See the workspace `WORK_STATUS.md` and build logs for the gates actually completed.
