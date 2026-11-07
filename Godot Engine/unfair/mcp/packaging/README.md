# Portable MCP package build

Use PowerShell 7 to run `../build-package.ps1` after the server build and root install/uninstall/doctor
scripts, `README-th.md` and `server/UPSTREAM.md` are ready. `-Preflight` checks these
inputs without staging or running npm. `-Offline` uses only the package-local
npm cache, when already populated.
`-PrepareDependencies` prepares that scoped cache and a dependency-only stage
without copying a server build that is still being finalized.

The builder stages `npm ci --omit=dev --ignore-scripts` using the workspace npm
CLI, empty scoped npm config files and a package-local cache. It does not run
lifecycle hooks, install npm globally, edit the server or consult a user's npm
configuration. Dev dependencies and test/fixture/private-config paths are not
shipped. Production dependency licenses stay beside those dependencies.

`runtime-lock.json` pins the reviewed host Windows x64 Node 24.22.1 executable
and its companion DLLs. This host binary does **not** support `node --license`;
its complete license and bundled third-party notices were fetched from the
exact official `nodejs/node` v24.22.1 tag and pinned separately. That text is
installed at `runtime/LICENSE.txt` beside `runtime/node.exe`.

Output is `../dist/unfair-mcp-1.0.0-windows-x64/` and its `.zip` plus a ZIP SHA-256
sidecar. `manifest.json` has `{name,version,files:[{path,sha256,size}]}` and records
every shipped file in ordinal path order, excluding itself. It contains no build
timestamp or absolute developer paths. ZIP entries use a fixed 1980 epoch.
`verify-package.ps1` verifies the tree and every archived entry against this
manifest, checks required tools and bundled Node, and checks entrypoint syntax.

The build retains unique staging directories for failed-build diagnosis. A
previous managed output is archived inside this packaging directory before
promotion; unknown output directories are never overwritten. Stages, caches,
build scripts and source test fixtures are not part of the distributable.

After packaging, run the main installer/doctor/MCP protocol tests against the
staged artifact to verify behavior. Integrity checks do not substitute for that
functional validation.
