[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory,
    [string]$Zip
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = (Get-Item -LiteralPath $PackageDirectory).FullName.TrimEnd('\')
$taskManifestFile = Join-Path $taskRoot 'manifest.json'
$taskManifest = Get-Content -LiteralPath $taskManifestFile -Raw | ConvertFrom-Json
if ($taskManifest.name -ne 'unfair-mcp' -or $taskManifest.version -ne '1.0.0' -or $taskManifest.arch -ne 'x64' -or $taskManifest.platform -ne 'windows') { throw 'Unexpected package identity.' }
$taskExpected = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$taskPreviousPath = $null
foreach ($taskItem in $taskManifest.files) {
    if ($taskItem.path -eq 'manifest.json' -or $taskItem.path.Contains('\') -or [IO.Path]::IsPathRooted($taskItem.path) -or ($taskItem.path.Split('/') -contains '..') -or $taskItem.sha256 -cnotmatch '^[0-9a-f]{64}$') { throw "Invalid manifest entry: $($taskItem.path)" }
    if ($taskPreviousPath -and [StringComparer]::Ordinal.Compare($taskPreviousPath, $taskItem.path) -ge 0) { throw 'Manifest paths must be unique and ordinally sorted.' }
    $taskPreviousPath = $taskItem.path
    $taskFile = Join-Path $taskRoot $taskItem.path
    $taskFileItem = Get-Item -LiteralPath $taskFile -Force
    if ($taskFileItem.PSIsContainer -or ($taskFileItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $taskFileItem.Length -ne $taskItem.size -or (Get-FileHash -LiteralPath $taskFile).Hash.ToLowerInvariant() -ne $taskItem.sha256) { throw "Package hash/size mismatch: $($taskItem.path)" }
    $taskExpected.Add($taskItem.path, $taskItem)
}
foreach ($taskRequired in @('build/index.js','package.json','package-lock.json','LICENSE','UPSTREAM.md','install.ps1','uninstall.ps1','doctor.ps1','README-th.md','runtime/node.exe','runtime/LICENSE.txt')) { if (-not $taskExpected.ContainsKey($taskRequired)) { throw "Required package file missing: $taskRequired" } }
$taskActualFiles = @(Get-ChildItem -LiteralPath $taskRoot -File -Recurse -Force)
if ($taskActualFiles.Count -ne $taskExpected.Count + 1) { throw 'Unlisted files are present in the package.' }
foreach ($taskFile in $taskActualFiles) {
    $taskRelative = $taskFile.FullName.Substring($taskRoot.Length + 1).Replace('\','/')
    if ($taskRelative -ne 'manifest.json' -and -not $taskExpected.ContainsKey($taskRelative)) { throw "Unlisted package file: $taskRelative" }
    if ($taskRelative -match '(^|/)(\.git|\.github|test|tests|__tests__|fixtures|smokeproject)(/|$)' -or $taskRelative -match '(^|/)(\.env(?:\..*)?|\.npmrc)$') { throw "Excluded material in package: $taskRelative" }
}
if (Test-Path -LiteralPath (Join-Path $taskRoot 'node_modules\typescript')) { throw 'Development TypeScript compiler was packaged.' }
if (Test-Path -LiteralPath (Join-Path $taskRoot 'node_modules\@types\node')) { throw 'Development Node typings were packaged.' }
$taskNodeVersion = (& (Join-Path $taskRoot 'runtime\node.exe') --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $taskNodeVersion -ne 'v24.22.1') { throw 'Bundled Node runtime failed its version check.' }
& (Join-Path $taskRoot 'runtime\node.exe') --check (Join-Path $taskRoot 'build\index.js')
if ($LASTEXITCODE -ne 0) { throw 'Packaged MCP entrypoint failed syntax validation.' }
if ($Zip) {
    Add-Type -AssemblyName System.IO.Compression
    $taskArchiveStream = [IO.File]::OpenRead((Get-Item -LiteralPath $Zip).FullName)
    $taskArchive = [IO.Compression.ZipArchive]::new($taskArchiveStream, [IO.Compression.ZipArchiveMode]::Read)
    $taskArchivePrefix = [IO.Path]::GetFileName($taskRoot) + '/'
    try {
        if ($taskArchive.Entries.Count -ne $taskActualFiles.Count) { throw 'ZIP file count differs from the package tree.' }
        $taskSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($taskEntry in $taskArchive.Entries) {
            if (-not $taskEntry.FullName.StartsWith($taskArchivePrefix, [StringComparison]::Ordinal)) { throw 'ZIP contains an unexpected root path.' }
            $taskRelative = $taskEntry.FullName.Substring($taskArchivePrefix.Length)
            if (-not $taskSeen.Add($taskRelative)) { throw 'ZIP contains duplicate paths.' }
            if ($taskRelative -eq 'manifest.json') { $taskExpectedHash = (Get-FileHash -LiteralPath $taskManifestFile).Hash.ToLowerInvariant() }
            elseif ($taskExpected.ContainsKey($taskRelative)) { $taskExpectedHash = $taskExpected[$taskRelative].sha256 }
            else { throw "Unlisted ZIP file: $taskRelative" }
            $taskInput = $taskEntry.Open()
            $taskHasher = [Security.Cryptography.SHA256]::Create()
            try { $taskHash = [Convert]::ToHexString($taskHasher.ComputeHash($taskInput)).ToLowerInvariant() } finally { $taskHasher.Dispose(); $taskInput.Dispose() }
            if ($taskHash -ne $taskExpectedHash) { throw "ZIP content differs from manifest: $taskRelative" }
        }
    } finally { $taskArchive.Dispose(); $taskArchiveStream.Dispose() }
}
Write-Output "Verified package: $($taskExpected.Count) files, complete sorted manifest, Node $taskNodeVersion, no dev/tests/private config; ZIP verified=$([bool]$Zip)"
