# UNFAIR-009 — matching toolbar button height

`UnfairAIAssistButton` now uses `Control::SIZE_FILL` vertically, matching the
Content Browser button in their shared HBox. Their top/bottom edges and text
baseline align; widths continue to follow each label. Icons remain capped at 16px.

Delivered `bin/Unfair.exe` matches the compiled editor, SHA256
`f43eb7f01d345429a6c0801db0fb0e01d9574a27dd15957f5df8e79f1abb9f13`.
Previous executable and console launcher are retained as
`Unfair.before-toolbar-size-v9.exe` / `Unfair.console.before-toolbar-size-v9.exe`.

The production change is one layout flag in `editor/editor_node.cpp`. The existing
workbench verification was used for native visual/layout regression. Its logo
hover capture now uses Control mouse-enter/exit notifications instead of warping
the user's OS pointer, preventing accidental desktop clicks from opening About
over a later modal test. No new implementation-mirroring unit test was added.

Build log: workspace `unfair-v9-build.log`. Workbench log:
`unfair-v9-workbench-qa.log`; actual toolbar/compact captures under
`unfair/smoke/qa-output`. The GUI was inspected at desktop and compact widths.
This checks the current Windows/OpenGL host rather than every DPI or translation.

The final workbench run passed with no ERROR/SCRIPT ERROR entries after the
pointer-independent hover capture adjustment. Updated installer SHA256:
`ba65012e6798ec5ba7bd62e4a0d5750e5370de3a5634abe2f904fc4ffe6e7b26`.
Final install/upgrade/uninstall and all payload hashes passed; unknown files and
a nested project sentinel survived uninstall. Evidence: workspace
`unfair-v9-installer-build.log`, `unfair-v9-installer-qa.log`, and
`unfair/installer/build/installer-qa.json`.
