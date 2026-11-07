[CmdletBinding()]
param(
    [string]$ServerDirectory = (Join-Path $PSScriptRoot 'server'),
    [string]$NodeDirectory,
    [string]$NpmCli,
    [switch]$Offline,
    [switch]$PrepareDependencies,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskPackageVersion = '1.0.0'
$taskPackageName = "unfair-mcp-$taskPackageVersion-windows-x64"
$taskMcpRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$taskWorkspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$taskPackaging = Join-Path $taskMcpRoot 'packaging'
$taskDist = Join-Path $taskMcpRoot 'dist'
if (-not $NodeDirectory) { $NodeDirectory = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin' }
if (-not $NpmCli) { $NpmCli = Join-Path $taskWorkspaceRoot '.build-tools\npm\package\bin\npm-cli.js' }
$taskNode = Join-Path $NodeDirectory 'node.exe'
$taskRuntimeLock = Get-Content -LiteralPath (Join-Path $taskPackaging 'runtime-lock.json') -Raw | ConvertFrom-Json
$taskUtf8 = [Text.UTF8Encoding]::new($false)

function Assert-PackageOwnedPath([string]$Path) {
    $taskCanonical = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if (-not $taskCanonical.StartsWith($taskMcpRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Path leaves the MCP workspace: $Path" }
    $taskCanonical
}

function Test-ExcludedPath([string]$RelativePath) {
    $taskNormalized = $RelativePath.Replace('\', '/')
    return $taskNormalized -match '(^|/)(\.git|\.github|\.gitlab|test|tests|__tests__|fixtures|__fixtures__|smoke|smokeproject)(/|$)' -or $taskNormalized -match '(^|/)(\.env(?:\..*)?|\.npmrc|\.DS_Store)$' -or $taskNormalized -match '\.(test|spec)\.[^/]+$'
}

function Copy-PackageFile([string]$Source, [string]$RelativePath) {
    if ([IO.Path]::IsPathRooted($RelativePath) -or ($RelativePath.Replace('\','/').Split('/') -contains '..')) { throw "Invalid package path: $RelativePath" }
    $taskFile = Get-Item -LiteralPath $Source -Force
    if ($taskFile.PSIsContainer -or ($taskFile.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Expected a regular package file: $Source" }
    $taskHashBefore = (Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash
    $taskDestination = Assert-PackageOwnedPath (Join-Path $taskPackageStage $RelativePath)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $taskDestination)) | Out-Null
    Copy-Item -LiteralPath $taskFile.FullName -Destination $taskDestination
    if ((Get-FileHash -LiteralPath $taskDestination -Algorithm SHA256).Hash -ne $taskHashBefore) { throw "Source changed while staging $RelativePath; rebuild after the input is stable." }
}

function Copy-PackageTree([string]$SourceRoot, [string]$DestinationRoot, [switch]$CompiledBuild) {
    $taskSourceRoot = (Get-Item -LiteralPath $SourceRoot).FullName.TrimEnd('\')
    $taskChildren = @(Get-ChildItem -LiteralPath $taskSourceRoot -Recurse -Force)
    foreach ($taskChild in $taskChildren) {
        if ($taskChild.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Package source contains a link: $($taskChild.FullName)" }
        if ($taskChild.PSIsContainer) { continue }
        $taskRelative = $taskChild.FullName.Substring($taskSourceRoot.Length + 1)
        if (Test-ExcludedPath $taskRelative) { continue }
        if ($CompiledBuild -and $taskChild.Extension -notin @('.js', '.mjs', '.cjs', '.json', '.gd', '.wasm', '.node')) { continue }
        Copy-PackageFile $taskChild.FullName (Join-Path $DestinationRoot $taskRelative)
    }
}

# Validate all inputs before allocating the stage. The server is built separately;
# packaging never edits its source, runs prepare hooks or copies its dev tree.
$taskNodeVersion = (& $taskNode --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $taskNodeVersion -ne ('v' + $taskRuntimeLock.version)) { throw "Expected Node $($taskRuntimeLock.version), got $taskNodeVersion" }
$taskNodeArchitecture = (& $taskNode -p 'process.platform + "/" + process.arch' | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $taskNodeArchitecture -ne 'win32/x64') { throw 'The packaged Node runtime must be Windows x64.' }
foreach ($taskRuntimeFile in $taskRuntimeLock.files) {
    $taskSource = Join-Path $NodeDirectory $taskRuntimeFile.name
    if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRuntimeFile.sha256) { throw "Node runtime differs from its reviewed lock: $($taskRuntimeFile.name)" }
}
$taskNodeLicense = Join-Path $taskPackaging $taskRuntimeLock.license.path
if ((Get-FileHash -LiteralPath $taskNodeLicense -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRuntimeLock.license.sha256) { throw 'Node license does not match the tagged official source recorded in runtime-lock.json.' }
$taskNpmVersion = (& $taskNode $NpmCli --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Workspace npm CLI is unavailable.' }
$taskServerPackage = Get-Content -LiteralPath (Join-Path $ServerDirectory 'package.json') -Raw | ConvertFrom-Json
$taskServerLock = Get-Content -LiteralPath (Join-Path $ServerDirectory 'package-lock.json') -Raw | ConvertFrom-Json -AsHashtable
if ($taskServerPackage.name -ne 'unfair-mcp' -or $taskServerPackage.version -ne $taskPackageVersion -or $taskServerLock.name -ne 'unfair-mcp' -or $taskServerLock.version -ne $taskPackageVersion) { throw 'Server package.json and lock must identify the final unfair-mcp 1.0.0 build.' }
if (-not (Test-Path -LiteralPath (Join-Path $ServerDirectory 'build\index.js') -PathType Leaf)) { throw 'Build server/build/index.js before packaging.' }
$taskRequiredRootFiles = @('install.ps1', 'uninstall.ps1', 'doctor.ps1', 'README-th.md')
foreach ($taskRequired in $taskRequiredRootFiles) { if (-not (Test-Path -LiteralPath (Join-Path $taskMcpRoot $taskRequired) -PathType Leaf)) { throw "Finish the package handoff file first: $taskRequired" } }
$taskUpstreamNotice = Join-Path $ServerDirectory 'UPSTREAM.md'
if (-not (Test-Path -LiteralPath $taskUpstreamNotice -PathType Leaf)) { throw 'Server UPSTREAM.md provenance notice is missing.' }
if (-not (Test-Path -LiteralPath (Join-Path $ServerDirectory 'LICENSE') -PathType Leaf)) { throw 'Server upstream MIT license is missing.' }
if ($Preflight) {
    Write-Output "Preflight passed: unfair-mcp $taskPackageVersion; $taskNodeVersion $taskNodeArchitecture; npm $taskNpmVersion; $($taskRuntimeLock.files.Count) pinned runtime files."
    return
}

$taskStageRoot = Assert-PackageOwnedPath (Join-Path $taskPackaging ('staging\' + [Guid]::NewGuid().ToString('N')))
$taskNpmStage = Join-Path $taskStageRoot 'dependencies'
$taskPackageStage = Join-Path $taskStageRoot $taskPackageName
foreach ($taskDirectory in @($taskStageRoot, $taskNpmStage, $taskPackageStage, $taskDist)) { [IO.Directory]::CreateDirectory($taskDirectory) | Out-Null }
Copy-Item -LiteralPath (Join-Path $ServerDirectory 'package.json') -Destination (Join-Path $taskNpmStage 'package.json')
Copy-Item -LiteralPath (Join-Path $ServerDirectory 'package-lock.json') -Destination (Join-Path $taskNpmStage 'package-lock.json')
$taskEmptyUserConfig = Join-Path $taskStageRoot 'npm-user.npmrc'
$taskEmptyGlobalConfig = Join-Path $taskStageRoot 'npm-global.npmrc'
[IO.File]::WriteAllText($taskEmptyUserConfig, '', $taskUtf8)
[IO.File]::WriteAllText($taskEmptyGlobalConfig, '', $taskUtf8)
$taskNpmCache = Join-Path $taskPackaging '.npm-cache'
$taskNpmArgs = @($NpmCli, 'ci', '--omit=dev', '--ignore-scripts', '--no-audit', '--no-fund', '--update-notifier=false', '--registry=https://registry.npmjs.org/', '--cache', $taskNpmCache, '--userconfig', $taskEmptyUserConfig, '--globalconfig', $taskEmptyGlobalConfig, '--loglevel=warn')
if ($Offline) { $taskNpmArgs += '--offline' }
Push-Location -LiteralPath $taskNpmStage
try {
    $taskNpmOutput = & $taskNode @taskNpmArgs 2>&1
    $taskNpmExit = $LASTEXITCODE
} finally { Pop-Location }
[IO.File]::WriteAllLines((Join-Path $taskStageRoot 'npm-ci.log'), @($taskNpmOutput | ForEach-Object { $_.ToString() }), $taskUtf8)
if ($taskNpmExit -ne 0) { $taskNpmOutput | Select-Object -Last 12; throw "Production npm ci failed (exit $taskNpmExit); stage retained at $taskStageRoot" }
foreach ($taskDevName in $taskServerPackage.devDependencies.PSObject.Properties.Name) {
    if (Test-Path -LiteralPath (Join-Path $taskNpmStage "node_modules\$taskDevName")) { throw "A development-only dependency survived --omit=dev: $taskDevName" }
}
if ($PrepareDependencies) {
    Write-Output "Production dependencies prepared with npm ci --omit=dev --ignore-scripts; scoped cache ready at $taskNpmCache"
    Write-Output "Dependency stage: $taskNpmStage"
    return
}

Copy-PackageTree (Join-Path $ServerDirectory 'build') 'build' -CompiledBuild
Copy-PackageTree (Join-Path $taskNpmStage 'node_modules') 'node_modules'
Copy-PackageFile (Join-Path $taskNpmStage 'package.json') 'package.json'
Copy-PackageFile (Join-Path $taskNpmStage 'package-lock.json') 'package-lock.json'
Copy-PackageFile (Join-Path $ServerDirectory 'LICENSE') 'LICENSE'
foreach ($taskRootFile in $taskRequiredRootFiles) { Copy-PackageFile (Join-Path $taskMcpRoot $taskRootFile) $taskRootFile }
Copy-PackageFile $taskUpstreamNotice 'UPSTREAM.md'
foreach ($taskOptionalDoc in @('README.md', 'CHANGELOG.md')) { if (Test-Path -LiteralPath (Join-Path $taskMcpRoot $taskOptionalDoc) -PathType Leaf) { Copy-PackageFile (Join-Path $taskMcpRoot $taskOptionalDoc) $taskOptionalDoc } }
foreach ($taskRuntimeFile in $taskRuntimeLock.files) { Copy-PackageFile (Join-Path $NodeDirectory $taskRuntimeFile.name) ('runtime\' + $taskRuntimeFile.name) }
# This host build rejects --license. Ship the complete license from its exact
# official Node tag, including bundled third-party notices, beside node.exe.
Copy-PackageFile $taskNodeLicense 'runtime\LICENSE.txt'

$taskShippedFiles = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
foreach ($taskFile in (Get-ChildItem -LiteralPath $taskPackageStage -Recurse -Force -File)) {
    $taskRelative = $taskFile.FullName.Substring($taskPackageStage.Length + 1).Replace('\', '/')
    if (Test-ExcludedPath $taskRelative) { throw "An excluded path reached the package: $taskRelative" }
    $taskShippedFiles.Add($taskRelative, $taskFile.FullName)
}
[string[]]$taskSortedPaths = @($taskShippedFiles.Keys)
[Array]::Sort($taskSortedPaths, [StringComparer]::Ordinal)
$taskManifestFiles = @(
    foreach ($taskRelative in $taskSortedPaths) {
        $taskFilePath = $taskShippedFiles[$taskRelative]
        [ordered]@{ path = $taskRelative; sha256 = (Get-FileHash -LiteralPath $taskFilePath -Algorithm SHA256).Hash.ToLowerInvariant(); size = (Get-Item -LiteralPath $taskFilePath).Length }
    }
)
$taskManifest = [ordered]@{
    name = 'unfair-mcp'; version = $taskPackageVersion; platform = 'windows'; arch = 'x64'; node_version = $taskRuntimeLock.version
    package_lock_sha256 = (Get-FileHash -LiteralPath (Join-Path $taskPackageStage 'package-lock.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    runtime_license_source = $taskRuntimeLock.license.source
    files = $taskManifestFiles
}
$taskManifestPath = Join-Path $taskPackageStage 'manifest.json'
[IO.File]::WriteAllText($taskManifestPath, ($taskManifest | ConvertTo-Json -Depth 6) + "`n", $taskUtf8)
$taskManifestHash = (Get-FileHash -LiteralPath $taskManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

# ZIP entries are sorted and use a fixed portable epoch. No host timestamps,
# source absolute paths, npm configs, source/tests or smoke projects are shipped.
$taskZipStage = Join-Path $taskStageRoot ($taskPackageName + '.zip')
Add-Type -AssemblyName System.IO.Compression
$taskZipStream = [IO.File]::Create($taskZipStage)
$taskZip = [IO.Compression.ZipArchive]::new($taskZipStream, [IO.Compression.ZipArchiveMode]::Create)
try {
    [string[]]$taskArchivePaths = @($taskSortedPaths) + @('manifest.json')
    [Array]::Sort($taskArchivePaths, [StringComparer]::Ordinal)
    foreach ($taskRelative in $taskArchivePaths) {
        $taskEntry = $taskZip.CreateEntry($taskPackageName + '/' + $taskRelative, [IO.Compression.CompressionLevel]::Optimal)
        $taskEntry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $taskEntry.ExternalAttributes = 0
        $taskInput = [IO.File]::OpenRead((Join-Path $taskPackageStage $taskRelative))
        $taskOutput = $taskEntry.Open()
        try { $taskInput.CopyTo($taskOutput) } finally { $taskOutput.Dispose(); $taskInput.Dispose() }
    }
} finally { $taskZip.Dispose(); $taskZipStream.Dispose() }

& (Join-Path $taskPackaging 'verify-package.ps1') -PackageDirectory $taskPackageStage -Zip $taskZipStage
$taskFinalDirectory = Assert-PackageOwnedPath (Join-Path $taskDist $taskPackageName)
$taskFinalZip = Assert-PackageOwnedPath (Join-Path $taskDist ($taskPackageName + '.zip'))
if (Test-Path -LiteralPath $taskFinalDirectory) {
    $taskOldManifestPath = Join-Path $taskFinalDirectory 'manifest.json'
    if (-not (Test-Path -LiteralPath $taskOldManifestPath -PathType Leaf) -or (Get-Content -LiteralPath $taskOldManifestPath -Raw | ConvertFrom-Json).name -ne 'unfair-mcp') { throw "Refusing to replace an unmanaged output directory: $taskFinalDirectory" }
    $taskArchiveDirectory = Assert-PackageOwnedPath (Join-Path $taskPackaging ('archives\' + [Guid]::NewGuid().ToString('N')))
    [IO.Directory]::CreateDirectory($taskArchiveDirectory) | Out-Null
    # Both absolute targets have been checked to remain inside this MCP workspace.
    Move-Item -LiteralPath $taskFinalDirectory -Destination (Join-Path $taskArchiveDirectory $taskPackageName)
    if (Test-Path -LiteralPath $taskFinalZip) { Move-Item -LiteralPath $taskFinalZip -Destination (Join-Path $taskArchiveDirectory ($taskPackageName + '.zip')) }
}
Move-Item -LiteralPath $taskPackageStage -Destination $taskFinalDirectory
Move-Item -LiteralPath $taskZipStage -Destination $taskFinalZip -Force
$taskZipHash = (Get-FileHash -LiteralPath $taskFinalZip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($taskFinalZip + '.sha256'), "$taskZipHash  $taskPackageName.zip`n", $taskUtf8)
$taskBuildRecord = [ordered]@{ name = 'unfair-mcp'; version = $taskPackageVersion; folder = 'dist/' + $taskPackageName; zip = 'dist/' + $taskPackageName + '.zip'; zip_sha256 = $taskZipHash; manifest_sha256 = $taskManifestHash; files = $taskManifestFiles.Count; node_version = $taskRuntimeLock.version; npm_version = $taskNpmVersion; dependencies = 'npm ci --omit=dev --ignore-scripts'; archive_verified = $true }
[IO.File]::WriteAllText((Join-Path $taskPackaging 'build-record.json'), ($taskBuildRecord | ConvertTo-Json -Depth 4) + "`n", $taskUtf8)
Write-Output "Package folder: $taskFinalDirectory"
Write-Output "Portable ZIP: $taskFinalZip"
Write-Output "SHA256: $taskZipHash"
