# Unfair workbench: viewport space and clear interaction

## Workspace

- Workspace tabs sit at the window center when space permits; side controls remain anchored. At compact widths the center group moves only enough to prevent overlap.
- Content Browser is a toggle drawer, accessible with Ctrl+Space and its toolbar button. The default/reset workspace starts collapsed. Its native dock close button is enabled.
- Opening an unpinned bottom tool hides the horizontal Content Browser. Opening Content Browser hides an unpinned bottom tool. A pinned bottom tool and custom vertical/floating asset layouts retain their normal behavior.
- Windows opens or focuses existing detached tools. Return All Tool Windows uses the native close/redock lifecycle. Closing a tool window preserves its content.

## Interaction

- Brand buttons open About and have distinct hover, pressed and keyboard focus states.
- Play is green, Pause amber and Stop red. Disabled controls remain subdued; active/hover surfaces and focus borders are separate.
- Root creation uses icon/title/description cards while preserving existing node creation, favorites, clipboard and feature-profile behavior.

## Native chrome and provenance

- Editor and Project Manager seed native Windows theme color before creating the first window. Gameplay boot colors remain project controlled.
- Native minimize/maximize/restore/close, resizing and system menu are retained. High Contrast defers to Windows.
- Detached windows restore from minimized state, clamp to the selected display and safely return their controls to the owner.
- Editor loading artwork credits “Forked from Godot Engine”. Upstream legal notices, identifiers, formats and GDScript remain intact.

Verification results are recorded separately in VALIDATION-v3.md and the workspace WORK_STATUS.md.
