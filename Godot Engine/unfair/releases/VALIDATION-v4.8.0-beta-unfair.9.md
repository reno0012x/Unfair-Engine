# Ready-to-run release verification

Release tag: `v4.8.0-beta-unfair.9` in private repository
`reno0012x/Unfair-Engine`.

## Artifacts

| Asset | Bytes | SHA256 |
| --- | ---: | --- |
| install.exe | 71505351 | ba65012e6798ec5ba7bd62e4a0d5750e5370de3a5634abe2f904fc4ffe6e7b26 |
| Unfair-4.8-beta-windows-x64-portable.zip | 91591572 | 00ee2d0367fa3b9263e52b2125aea67353aeba82ce016db0eadbc2ea0cabf086 |
| unfair-mcp-1.0.0-windows-x64.zip | 38464566 | e411e8d27b023e963a1a75e6d30b1eba78e7989bb27282d988fe2b0b24583dc6 |

The release also includes `README-Windows-th.md` and `SHA256SUMS.txt`.
Installer and portable contain the delivered editor SHA256
`f43eb7f01d345429a6c0801db0fb0e01d9574a27dd15957f5df8e79f1abb9f13`.

## Verified from GitHub downloads

- GitHub's uploaded asset digests matched local release files. All five assets
  were downloaded back into a new isolated directory and their SHA256 matched.
- The portable ZIP contains 58 verified entries: engine executable/console, DLL,
  artwork, native MCP companion, isolated Python, licenses, public manifests,
  portable quick-start and `_sc_`. No private config, developer cache, backups or
  pre-existing editor_data is included. A deterministic rebuild gave the same ZIP.
- Portable and MCP ZIPs were extracted from the actual GitHub downloads. Their
  bundled Python and Node ran the native MCP compatibility suite against the
  downloaded Unfair.exe: all 14 upstream and 2 added tools passed. Checks included
  scene/node/sprite/MeshLibrary operations, actual script UID/reference handling,
  editor/project launch, bounded output and EOF cleanup.
- Portable editor_data was created inside the extracted folder during testing,
  confirming the self-contained portable layout was active.
- The downloaded install.exe passed installation/upgrade/file-hash/visibility
  checks and uninstall. A nested project and unknown file survived uninstall.
  Its first parallel run observed the separate MCP test's same-name process;
  the completed installer verification therefore ran sequentially after MCP QA.

## Previews and use

Root README contains actual editor, Project Manager, AI Assistance and loading
captures in `docs/images/`, plus versioned download links and installation steps.
Images show development/test projects rather than a fabricated mockup.

The green GitHub Code → Download ZIP remains the source archive. Users who want
to run the application should select `install.exe` or the portable ZIP from the
release. A GitHub account with access is required because the repo stays private.

This is an unsigned Windows x64 developer beta. It is not a claim of validation
for every GPU, plugin, DPI, export target or OS. The CLI MCP and live read-only AI
Assistance bridge remain separate as described in their guides.

Local raw test artifacts are deliberately not committed: `.build-tools/release-r9/`
contains fresh-download logs and the native result JSON; installer lifecycle
evidence is under `unfair/installer/build/installer-qa.json`.
