[CmdletBinding()]
param(
    [string]$BinDirectory,
    [string]$PythonRuntimeDirectory,
    [string]$LoadingAsset,
    [string]$AgilitySdkDirectory,
    [string]$MakeNsis,
    [switch]$IncludeD3D12DebugLayer,
    [switch]$FastPackage
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskEngineRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$taskWorkspace = Split-Path -Parent $taskEngineRoot
if (-not $BinDirectory) { $BinDirectory = Join-Path $taskEngineRoot 'bin' }
if (-not $LoadingAsset) { $LoadingAsset = Join-Path $taskEngineRoot 'unfair\loading\unfair-loading-background-v1.png' }
if (-not $AgilitySdkDirectory) { $AgilitySdkDirectory = Join-Path $env:LOCALAPPDATA 'Godot\build_deps\agility_sdk' }
if (-not $MakeNsis) { $MakeNsis = Join-Path $taskWorkspace '.build-tools\nsis\nsis-3.13\makensis.exe' }
if (-not (Test-Path -LiteralPath $MakeNsis -PathType Leaf)) { throw "NSIS 3.13 is required: $MakeNsis (see toolchain.json)." }
$taskCompilerVersion = (& $MakeNsis /VERSION | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $taskCompilerVersion -ne 'v3.13') { throw "Expected NSIS v3.13, got $taskCompilerVersion" }

function ConvertTo-NsisLiteral([string]$Value) {
    if ($Value.Contains("`r") -or $Value.Contains("`n")) { throw 'Newlines are not allowed in NSIS paths/metadata.' }
    $Value.Replace('$', '$$').Replace('"', '$\"')
}

$taskPayload = [System.Collections.Generic.List[object]]::new()
function Add-PayloadFile([string]$Source, [string]$Destination) {
    $taskSourceItem = Get-Item -LiteralPath $Source -ErrorAction Stop
    if ($taskSourceItem.PSIsContainer -or ($taskSourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Expected a regular source file: $Source" }
    if ($Destination -notmatch '^[A-Za-z0-9_./\\-]+$' -or $Destination.Contains('..') -or [IO.Path]::IsPathRooted($Destination)) { throw "Unsafe destination: $Destination" }
    $Destination = $Destination.Replace('/', '\')
    if ($taskPayload | Where-Object { $_.Destination -ieq $Destination }) { throw "Duplicate payload path: $Destination" }
    $taskPayload.Add([pscustomobject]@{ Source = $taskSourceItem.FullName; Destination = $Destination; Size = $taskSourceItem.Length; Sha256 = (Get-FileHash -LiteralPath $taskSourceItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant() })
}

Add-PayloadFile (Join-Path $BinDirectory 'Unfair.exe') 'Unfair.exe'
Add-PayloadFile (Join-Path $BinDirectory 'Unfair.console.exe') 'Unfair.console.exe'
Add-PayloadFile (Join-Path $BinDirectory 'D3D12Core.dll') 'D3D12Core.dll'
if ($IncludeD3D12DebugLayer) { Add-PayloadFile (Join-Path $BinDirectory 'd3d12SDKLayers.dll') 'd3d12SDKLayers.dll' }
foreach ($taskAiFile in @('unfair_mcp_bridge.py', 'README.md', 'QUICKSTART-th.md')) {
    Add-PayloadFile (Join-Path $BinDirectory "unfair_ai\$taskAiFile") "unfair_ai\$taskAiFile"
}
Add-PayloadFile $LoadingAsset 'assets\loading\unfair-loading-background.png'
foreach ($taskCredit in @('LICENSE.txt', 'COPYRIGHT.txt', 'AUTHORS.md')) { Add-PayloadFile (Join-Path $taskEngineRoot $taskCredit) $taskCredit }
Add-PayloadFile (Join-Path $PSScriptRoot 'INSTALLED-README-th.md') 'README-th.md'
foreach ($taskNotice in @(
    @('thirdparty\angle\LICENSE', 'licenses\ANGLE-LICENSE.txt'),
    @('thirdparty\accesskit\LICENSE-MIT', 'licenses\ACCESSKIT-LICENSE.txt'),
    @('thirdparty\directx_headers\LICENSE', 'licenses\DIRECTX-HEADERS-LICENSE.txt')
)) { Add-PayloadFile (Join-Path $taskEngineRoot $taskNotice[0]) $taskNotice[1] }
foreach ($taskNotice in @('LICENSE.txt', 'LICENSE-CODE.txt', 'distributable files.txt')) {
    $taskDestination = if ($taskNotice -eq 'distributable files.txt') { 'licenses\D3D12-DISTRIBUTABLE-FILES.txt' } else { 'licenses\D3D12-' + $taskNotice }
    Add-PayloadFile (Join-Path $AgilitySdkDirectory $taskNotice) $taskDestination
}

if ($PythonRuntimeDirectory) {
    # Only the flat official embeddable distribution is accepted. No scripts,
    # packages, caches, pip, private configs or arbitrary subdirectories.
    $taskRuntimeNames = @('python.exe','pythonw.exe','python3.dll','python.cat','LICENSE.txt','_asyncio.pyd','_bz2.pyd','_ctypes.pyd','_decimal.pyd','_elementtree.pyd','_hashlib.pyd','_lzma.pyd','_multiprocessing.pyd','_overlapped.pyd','_queue.pyd','_remote_debugging.pyd','_socket.pyd','_sqlite3.pyd','_ssl.pyd','_uuid.pyd','_wmi.pyd','_zoneinfo.pyd','_zstd.pyd','pyexpat.pyd','select.pyd','unicodedata.pyd','winsound.pyd','libcrypto-3.dll','libssl-3.dll','libffi-8.dll','libtommath.dll','sqlite3.dll','vcruntime140.dll','vcruntime140_1.dll')
    $taskRuntimeFiles = @(Get-ChildItem -LiteralPath $PythonRuntimeDirectory -Force)
    foreach ($taskRuntimeFile in $taskRuntimeFiles) {
        if ($taskRuntimeFile.PSIsContainer -or ($taskRuntimeFile.Attributes -band [IO.FileAttributes]::ReparsePoint) -or ($taskRuntimeFile.Name -notin $taskRuntimeNames -and $taskRuntimeFile.Name -notmatch '^python3[0-9]{1,2}\.(dll|zip|_pth)$')) { throw "Not an allowed embeddable Python file: $($taskRuntimeFile.FullName)" }
        Add-PayloadFile $taskRuntimeFile.FullName ('runtime\python\' + $taskRuntimeFile.Name)
    }
    foreach ($taskRequired in @('python.exe', 'python3.dll', 'LICENSE.txt')) {
        if ($taskRequired -notin $taskRuntimeFiles.Name) { throw "Python runtime is incomplete: missing $taskRequired" }
    }
    $taskPthFiles = @($taskRuntimeFiles | Where-Object { $_.Extension -eq '._pth' })
    if ($taskPthFiles.Count -ne 1) { throw 'Expected one isolated Python ._pth file.' }
    foreach ($taskLine in (Get-Content -LiteralPath $taskPthFiles[0].FullName)) {
        $taskPthLine = $taskLine.Trim()
        if ($taskPthLine -and -not $taskPthLine.StartsWith('#') -and $taskPthLine -ne '.' -and $taskPthLine -notmatch '^python3[0-9]{1,2}\.zip$') { throw 'Python ._pth must retain isolated official stdlib paths.' }
    }
}

$taskVersionText = Get-Content -LiteralPath (Join-Path $taskEngineRoot 'version.py') -Raw
$taskVersionParts = @{}
foreach ($taskPart in @('major', 'minor', 'patch')) {
    $taskMatch = [regex]::Match($taskVersionText, "(?m)^$taskPart = ([0-9]+)$")
    if (-not $taskMatch.Success) { throw "Missing version field: $taskPart" }
    $taskVersionParts[$taskPart] = $taskMatch.Groups[1].Value
}
$taskStatus = [regex]::Match($taskVersionText, '(?m)^status = "([a-z0-9.-]+)"$').Groups[1].Value
$taskBaseVersion = '{0}.{1}.{2}' -f $taskVersionParts.major, $taskVersionParts.minor, $taskVersionParts.patch
$taskVersion = if ($taskStatus -eq 'stable' -or -not $taskStatus) { $taskBaseVersion } else { "$taskBaseVersion-$taskStatus" }
$taskNumericVersion = "$taskBaseVersion.0"
$taskBuildRoot = Join-Path $PSScriptRoot 'build'
$taskStage = Join-Path $taskBuildRoot 'package'
$taskDist = Join-Path $PSScriptRoot 'dist'
foreach ($taskDirectory in @($taskBuildRoot, $taskStage, $taskDist)) { [IO.Directory]::CreateDirectory($taskDirectory) | Out-Null }
$taskUtf8 = [Text.UTF8Encoding]::new($false)

# Individual copies and individual NSIS File commands are intentional: never
# recursively package bin/, even when it contains portable settings or test files.
$taskOrderedPayload = @($taskPayload | Sort-Object Destination)
foreach ($taskItem in $taskOrderedPayload) {
    $taskTarget = Join-Path $taskStage $taskItem.Destination
    [IO.Directory]::CreateDirectory((Split-Path -Parent $taskTarget)) | Out-Null
    Copy-Item -LiteralPath $taskItem.Source -Destination $taskTarget -Force
    if ((Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskItem.Sha256) { throw "Payload changed while staging: $($taskItem.Destination)" }
}
$taskManifest = [ordered]@{
    product = 'Unfair'; app_id = 'Unfair.Editor'; version = $taskVersion; architecture = 'x86_64'; build_kind = 'development-beta'; bundled_python = [bool]$PythonRuntimeDirectory
    files = @($taskOrderedPayload | ForEach-Object { [ordered]@{ path = $_.Destination.Replace('\','/'); bytes = $_.Size; sha256 = $_.Sha256 } })
}
$taskManifestFile = Join-Path $taskStage 'installed-files.json'
[IO.File]::WriteAllText($taskManifestFile, ($taskManifest | ConvertTo-Json -Depth 5) + "`n", $taskUtf8)
$taskManifestEntry = [pscustomobject]@{ Source = $taskManifestFile; Destination = 'installed-files.json'; Size = (Get-Item -LiteralPath $taskManifestFile).Length; Sha256 = (Get-FileHash -LiteralPath $taskManifestFile).Hash.ToLowerInvariant() }
$taskFinalPayload = @($taskOrderedPayload) + @($taskManifestEntry)
$taskInstallLines = [Collections.Generic.List[string]]::new()
$taskUninstallLines = [Collections.Generic.List[string]]::new()
$taskDirectories = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$taskCounter = 0
foreach ($taskItem in $taskFinalPayload) {
    $taskRelative = ConvertTo-NsisLiteral $taskItem.Destination
    $taskRelativeParent = Split-Path -Parent $taskItem.Destination
    $taskOutPath = if ($taskRelativeParent) { '$INSTDIR\' + (ConvertTo-NsisLiteral $taskRelativeParent) } else { '$INSTDIR' }
    $taskInstallLines.Add('ClearErrors')
    $taskInstallLines.Add('SetOutPath "' + $taskOutPath + '"')
    $taskInstallLines.Add('File "' + (ConvertTo-NsisLiteral (Join-Path $taskStage $taskItem.Destination)) + '"')
    $taskInstallLines.Add('IfErrors install_failed')
    $taskLabel = "un_file_${taskCounter}_done"
    $taskUninstallLines.Add('IfFileExists "$INSTDIR\' + $taskRelative + '" 0 ' + $taskLabel)
    $taskUninstallLines.Add('ClearErrors')
    $taskUninstallLines.Add('Delete "$INSTDIR\' + $taskRelative + '"')
    $taskUninstallLines.Add('IfErrors uninstall_failed')
    $taskUninstallLines.Add($taskLabel + ':')
    while ($taskRelativeParent) { [void]$taskDirectories.Add($taskRelativeParent); $taskRelativeParent = Split-Path -Parent $taskRelativeParent }
    $taskCounter++
}
foreach ($taskDir in ($taskDirectories | Sort-Object { $_.Length } -Descending)) { $taskUninstallLines.Add('RMDir "$INSTDIR\' + (ConvertTo-NsisLiteral $taskDir) + '"') }
$taskInstallInclude = Join-Path $taskBuildRoot 'install-files.nsh'
$taskUninstallInclude = Join-Path $taskBuildRoot 'uninstall-files.nsh'
[IO.File]::WriteAllLines($taskInstallInclude, $taskInstallLines, $taskUtf8)
[IO.File]::WriteAllLines($taskUninstallInclude, $taskUninstallLines, $taskUtf8)
$taskOutputExe = Join-Path $taskDist 'install.exe'
$taskPendingExe = Join-Path $taskDist 'install.pending.exe'
$taskSizeKib = [int][Math]::Ceiling((($taskFinalPayload | Measure-Object -Property Size -Sum).Sum) / 1024)
$taskDefines = [ordered]@{
    APP_VERSION = $taskVersion; APP_NUMERIC_VERSION = $taskNumericVersion; PACKAGE_STAGE = $taskStage
    PAYLOAD_INSTALL = $taskInstallInclude; PAYLOAD_UNINSTALL = $taskUninstallInclude; OUTPUT_EXE = $taskPendingExe
    INSTALLER_ICON = Join-Path $taskEngineRoot 'platform\windows\godot.ico'
}
$taskConfigLines = @($taskDefines.GetEnumerator() | ForEach-Object { '!define ' + $_.Key + ' "' + (ConvertTo-NsisLiteral $_.Value) + '"' }) + @("!define PACKAGE_SIZE_KIB $taskSizeKib")
$taskConfig = Join-Path $taskBuildRoot 'package-config.nsh'
[IO.File]::WriteAllLines($taskConfig, $taskConfigLines, $taskUtf8)
$taskCompilerLog = Join-Path $taskBuildRoot 'makensis.log'
$taskCompilerArguments = @('/NOCD', '/INPUTCHARSET', 'UTF8', '/WX', '/V4', "/DPACKAGE_CONFIG=$taskConfig")
if ($FastPackage) { $taskCompilerArguments += '/DFAST_PACKAGE' }
$taskCompilerArguments += (Join-Path $PSScriptRoot 'Unfair.nsi')
$taskCompilerOutput = & $MakeNsis @taskCompilerArguments 2>&1
$taskCompilerExit = $LASTEXITCODE
[IO.File]::WriteAllLines($taskCompilerLog, @($taskCompilerOutput | ForEach-Object { $_.ToString() }), $taskUtf8)
if ($taskCompilerExit -ne 0) { $taskCompilerOutput | Select-Object -Last 18 | Write-Output; throw "NSIS compilation failed (exit $taskCompilerExit). See $taskCompilerLog" }
if (-not (Test-Path -LiteralPath $taskPendingExe -PathType Leaf)) { throw 'Compiler returned success without installer output.' }
Move-Item -LiteralPath $taskPendingExe -Destination $taskOutputExe -Force
$taskOutputHash = (Get-FileHash -LiteralPath $taskOutputExe -Algorithm SHA256).Hash.ToLowerInvariant()
$taskBuildRecord = [ordered]@{ product = 'Unfair'; version = $taskVersion; compiler = $taskCompilerVersion; compression = $(if ($FastPackage) { 'zlib-qa' } else { 'lzma-solid' }); package_files = $taskFinalPayload.Count; installed_kib = $taskSizeKib; installer_sha256 = $taskOutputHash; payload_manifest_sha256 = $taskManifestEntry.Sha256; exe_sha256 = ($taskOrderedPayload | Where-Object { $_.Destination -eq 'Unfair.exe' }).Sha256; bundled_python = [bool]$PythonRuntimeDirectory; debug_layer = [bool]$IncludeD3D12DebugLayer }
[IO.File]::WriteAllText((Join-Path $taskDist 'build-manifest.json'), ($taskBuildRecord | ConvertTo-Json -Depth 4) + "`n", $taskUtf8)
Copy-Item -LiteralPath $taskManifestFile -Destination (Join-Path $taskDist 'installed-files.json') -Force
Write-Output "Built $taskOutputExe"
Write-Output "Payload: $($taskFinalPayload.Count) explicit files, $taskSizeKib KiB; SHA256 $taskOutputHash"
Write-Output "Compiler log: $taskCompilerLog"
