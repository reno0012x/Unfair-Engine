# Unfair Windows installer

`build-installer.ps1` creates `dist/install.exe`, a per-user NSIS installer with a
normal visible installation tree and `Uninstall.exe`. Setup does not require UAC,
install a service, alter file associations or modify PATH. The release is a beta
development editor; export templates are separate.

## Build

Use the verified NSIS 3.13 portable distribution described in `toolchain.json`.
The build script uses the workspace copy at `.build-tools/nsis/nsis-3.13`, or an
explicit `-MakeNsis` path. It never downloads or globally installs build tools.

After the final editor binary and AI companion have been delivered to `bin/`:

```powershell
& '.\unfair\installer\build-installer.ps1' `
  -PythonRuntimeDirectory '..\.build-tools\python-runtime-3.14.10'
```

Run from the engine root, or pass absolute paths. Optional inputs are
`-BinDirectory`, `-LoadingAsset`, `-AgilitySdkDirectory` and `-MakeNsis`.
`-IncludeD3D12DebugLayer` includes the separately licensed SDK debug DLL for
explicit GPU validation; normal renderer startup needs only `D3D12Core.dll`.
`-FastPackage` uses faster zlib compression for iterative installer QA and records
`zlib-qa` in the build manifest. Omit it for the final LZMA delivery package.

Python is copied only from the flat, isolated official embeddable distribution;
its license and stdlib are included. The builder rejects unexpected files,
subdirectories, links, extra Python search paths and incomplete runtimes. It
does not package arbitrary `runtime/` or `bin/` trees. An omitted runtime input
means an external compatible Python installation is required for MCP.

The explicit payload contains only the delivered EXEs, D3D12 runtime, the three
AI bridge files, the loading artwork, credits/notices and the optional verified
Python runtime. `obj`, libraries, exports, portable settings, `_sc_`, logs,
backups, test fixtures, connection tokens and source trees are excluded.

The script verifies each staged file's SHA-256, generates individual NSIS `File`
and uninstall `Delete` commands, and runs `makensis /WX` so warnings fail the
build. Compiler output is stored at `build/makensis.log`. The file manifest is
both installed and copied beside the installer; `dist/build-manifest.json`
records the source EXE hash, payload manifest hash and final installer hash.
Rebuild with identical inputs and NSIS version to compare output hashes.

## Install and remove

The default location is `%LOCALAPPDATA%\Programs\Unfair`. Start Menu shortcuts
are created for the current user. A desktop shortcut is an optional component.
The finish page checks **Open installation folder** and leaves **Launch Unfair**
unchecked. Silent installation (`/S`, uppercase) never opens the folder or app.

```powershell
Start-Process -FilePath '.\dist\install.exe' -ArgumentList '/S', '/D=C:\Path\Unfair' -Wait
```

NSIS requires `/D=` to be the final argument, with the installation path unquoted
inside the command line. Normal PowerShell quoting of the complete argument is
still required when constructing that string. Reject drive roots, home/special
folders and unmanaged installs. Upgrades reuse the stable `Unfair.Editor` AppID
and the registered location; uninstall first to move a registered installation.
An app using that installation must be closed before upgrade/uninstall; setup
does not terminate user processes.

Uninstall lists only paths owned by this package and removes directories only
when empty. Unknown files, projects, `.godot`, portable data and AppData settings
are preserved. No recursive directory removal is used. Registration is removed
only when its recorded installation location matches the installation being
removed.

## Scoped QA

The maintainer can install into a unique workspace test directory using
`/S /TESTMODE=1 /D=<absolute-test-directory>`. Test mode skips registry and all
shortcuts, records that fact in the installation marker, and makes uninstall
skip those locations too. It must not replace the user's real installation.

For a trustworthy uninstaller exit code, copy `Uninstall.exe` outside the test
directory and run that copy with `/S _?=<absolute-test-directory>` as the final
argument, then wait for the copied process. NSIS's ordinary uninstaller launches
a temporary copy, so waiting on its first process does not wait for removal.

Verify installation hashes against `installed-files.json`, no `_sc_` or
`editor_data`, normal visible files and optional bundled Python; place a sentinel
project file and an unknown nested file in the test install before uninstall.
After removal those sentinels must still exist while all package-owned files are
gone. Also check rejection of root/home/relative/empty paths, marker tampering,
upgrade-in-place, active app rejection, silent no-launch, final finish-page
checkboxes and registration/shortcut lifecycle in a dedicated normal test.

This repository ships an unsigned local build. No signing certificate or
SmartScreen reputation is implied by successfully compiling the installer.
