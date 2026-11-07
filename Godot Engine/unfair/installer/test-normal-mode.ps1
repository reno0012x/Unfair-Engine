[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskEngineRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$taskWorkspaceRoot = Split-Path -Parent $taskEngineRoot
$taskCompiler = Join-Path $taskWorkspaceRoot '.build-tools\nsis\nsis-3.13\makensis.exe'
$taskBuild = Join-Path $PSScriptRoot 'build'
$taskTag = [Guid]::NewGuid().ToString('N')
$taskId = 'Unfair.Editor.InstallerQA.' + $taskTag
$taskAppKey = 'Software\Unfair\InstallerQA\' + $taskTag
$taskUninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + $taskId
$taskLabel = 'Unfair Installer QA ' + $taskTag
$taskInstallRoot = Join-Path $taskBuild ('normal-mode-qa-' + $taskTag)
$taskOutput = Join-Path $taskBuild ('normal-mode-setup-' + $taskTag + '.exe')
$taskSourceFile = Join-Path $PSScriptRoot 'Unfair.nsi'
$taskOriginalSourceHash = (Get-FileHash -LiteralPath $taskSourceFile).Hash
$taskOriginalConfig = Join-Path $taskBuild 'package-config.nsh'
$taskProgramRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$taskDesktopRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
$taskStartMenu = Join-Path $taskProgramRoot $taskLabel
$taskDesktopLink = Join-Path $taskDesktopRoot ($taskLabel + '.lnk')
$taskRegistry = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryView]::Registry64)
$taskUtf8 = [Text.UTF8Encoding]::new($false)
$taskChecks = [Collections.Generic.List[string]]::new()

function Get-RegistryValues([string]$Path) {
    $taskKey = $taskRegistry.OpenSubKey($Path, $false)
    if (-not $taskKey) { return $null }
    try {
        $taskValues = [ordered]@{}
        foreach ($taskName in ($taskKey.GetValueNames() | Sort-Object)) {
            $taskValues[$taskName] = [ordered]@{ kind = $taskKey.GetValueKind($taskName).ToString(); value = $taskKey.GetValue($taskName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
        }
        return $taskValues
    } finally { $taskKey.Dispose() }
}

function Get-ProductionSnapshot {
    $taskSnapshot = [ordered]@{ app_key = Get-RegistryValues 'Software\Unfair\Editor'; uninstall_key = Get-RegistryValues 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Unfair.Editor'; shortcuts = @() }
    foreach ($taskRelative in @('Unfair\Unfair.lnk', 'Unfair\Installation folder.lnk', 'Unfair\Uninstall Unfair.lnk')) {
        $taskPath = Join-Path $taskProgramRoot $taskRelative
        $taskSnapshot.shortcuts += [ordered]@{ relative_path = $taskRelative; exists = (Test-Path -LiteralPath $taskPath); sha256 = $(if (Test-Path -LiteralPath $taskPath -PathType Leaf) { (Get-FileHash -LiteralPath $taskPath).Hash } else { $null }) }
    }
    $taskPath = Join-Path $taskDesktopRoot 'Unfair.lnk'
    $taskSnapshot.shortcuts += [ordered]@{ relative_path = 'Desktop/Unfair.lnk'; exists = (Test-Path -LiteralPath $taskPath); sha256 = $(if (Test-Path -LiteralPath $taskPath -PathType Leaf) { (Get-FileHash -LiteralPath $taskPath).Hash } else { $null }) }
    $taskJson = $taskSnapshot | ConvertTo-Json -Depth 8 -Compress
    $taskHasher = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($taskHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($taskJson))) } finally { $taskHasher.Dispose() }
}

function Assert-NormalQA([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "Normal-mode installer QA failed: $Name" }
    $taskChecks.Add($Name)
    Write-Output "PASS: $Name"
}

if ((Test-Path -LiteralPath $taskInstallRoot) -or (Test-Path -LiteralPath $taskStartMenu) -or (Test-Path -LiteralPath $taskDesktopLink) -or $taskRegistry.OpenSubKey($taskAppKey) -or $taskRegistry.OpenSubKey($taskUninstallKey)) { throw 'QA identity unexpectedly exists; refusing to reuse it.' }
$taskBeforeSnapshot = Get-ProductionSnapshot
$taskSource = [IO.File]::ReadAllText($taskSourceFile)
$taskReplacements = [ordered]@{
    '!define APP_ID "Unfair.Editor"' = ('!define APP_ID "' + $taskId + '"')
    '!define APP_KEY "Software\Unfair\Editor"' = ('!define APP_KEY "' + $taskAppKey + '"')
    'Local\Unfair.Editor.Setup' = ('Local\' + $taskId + '.Setup')
    '$SMPROGRAMS\Unfair' = ('$SMPROGRAMS\' + $taskLabel)
    '$DESKTOP\Unfair.lnk' = ('$DESKTOP\' + $taskLabel + '.lnk')
    '"DisplayName" "Unfair"' = ('"DisplayName" "' + $taskLabel + '"')
    'Section /o "Desktop shortcut" DesktopSection' = 'Section "Desktop shortcut" DesktopSection'
}
foreach ($taskReplacement in $taskReplacements.GetEnumerator()) {
    if (-not $taskSource.Contains($taskReplacement.Key)) { throw "QA substitution is no longer valid: $($taskReplacement.Key)" }
    $taskSource = $taskSource.Replace($taskReplacement.Key, $taskReplacement.Value)
}
$taskQaConfigFile = Join-Path $taskBuild ('normal-mode-config-' + $taskTag + '.nsh')
$taskConfig = [IO.File]::ReadAllText($taskOriginalConfig)
$taskConfig = [regex]::Replace($taskConfig, '(?m)^!define OUTPUT_EXE .*$', '!define OUTPUT_EXE "' + $taskOutput + '"')
[IO.File]::WriteAllText($taskQaConfigFile, $taskConfig, $taskUtf8)
$taskQaSource = Join-Path $taskBuild ('normal-mode-source-' + $taskTag + '.nsi')
[IO.File]::WriteAllText($taskQaSource, $taskSource, $taskUtf8)
$taskCompilerOutput = & $taskCompiler /NOCD /INPUTCHARSET UTF8 /WX /V3 /DFAST_PACKAGE "/DPACKAGE_CONFIG=$taskQaConfigFile" $taskQaSource 2>&1
$taskCompilerExit = $LASTEXITCODE
[IO.File]::WriteAllLines((Join-Path $taskBuild ('normal-mode-compiler-' + $taskTag + '.log')), @($taskCompilerOutput | ForEach-Object { $_.ToString() }), $taskUtf8)
if ($taskCompilerExit -ne 0) { $taskCompilerOutput | Select-Object -Last 12; throw "QA compiler failed: $taskCompilerExit" }

$taskRecord = [ordered]@{ identity = $taskId; install_directory = $taskInstallRoot; app_key = 'HKCU64\' + $taskAppKey; uninstall_key = 'HKCU64\' + $taskUninstallKey; start_menu = $taskStartMenu; desktop_shortcut = $taskDesktopLink; production_snapshot_before = $taskBeforeSnapshot; installer_sha256 = (Get-FileHash -LiteralPath $taskOutput).Hash; release_source_sha256_before = $taskOriginalSourceHash; checks = @() }
$taskFailure = $null
try {
    $taskInstallProcess = Start-Process -FilePath $taskOutput -ArgumentList "/S /D=$taskInstallRoot" -PassThru -Wait -WindowStyle Hidden
    $taskRecord.install_exit_code = $taskInstallProcess.ExitCode
    Assert-NormalQA ($taskInstallProcess.ExitCode -eq 0) 'GUID-isolated normal-mode setup succeeded'
    $taskMetadata = Get-RegistryValues $taskUninstallKey
    $taskRecord.installed_metadata = $taskMetadata
    Assert-NormalQA ($null -ne $taskMetadata) 'Add/Remove Programs key exists only under the QA AppID'
    Assert-NormalQA ($taskMetadata.DisplayName.value -eq $taskLabel) 'DisplayName identifies the unique QA product'
    Assert-NormalQA ($taskMetadata.DisplayVersion.value -eq '4.8.0-beta') 'DisplayVersion matches packaged editor version'
    Assert-NormalQA ($taskMetadata.InstallLocation.value -eq $taskInstallRoot) 'InstallLocation points to the workspace test install'
    Assert-NormalQA ($taskMetadata.UninstallString.value -eq ('"' + (Join-Path $taskInstallRoot 'Uninstall.exe') + '"')) 'UninstallString quotes its executable path correctly'
    Assert-NormalQA ($taskMetadata.QuietUninstallString.value -eq ('"' + (Join-Path $taskInstallRoot 'Uninstall.exe') + '" /S')) 'QuietUninstallString has quoted path and uppercase /S'
    Assert-NormalQA ($taskMetadata.NoModify.value -eq 1 -and $taskMetadata.NoRepair.value -eq 1 -and $taskMetadata.EstimatedSize.value -gt 0) 'ARP size and maintenance metadata are valid'
    $taskShell = New-Object -ComObject WScript.Shell
    $taskLinks = @()
    foreach ($taskLink in @(
        @{ Path = (Join-Path $taskStartMenu 'Unfair.lnk'); Target = (Join-Path $taskInstallRoot 'Unfair.exe') },
        @{ Path = (Join-Path $taskStartMenu 'Installation folder.lnk'); Target = $taskInstallRoot },
        @{ Path = (Join-Path $taskStartMenu 'Uninstall Unfair.lnk'); Target = (Join-Path $taskInstallRoot 'Uninstall.exe') },
        @{ Path = $taskDesktopLink; Target = (Join-Path $taskInstallRoot 'Unfair.exe') }
    )) {
        Assert-NormalQA (Test-Path -LiteralPath $taskLink.Path -PathType Leaf) ('Shortcut exists: ' + [IO.Path]::GetFileName($taskLink.Path))
        $taskShortcut = $taskShell.CreateShortcut($taskLink.Path)
        Assert-NormalQA ($taskShortcut.TargetPath.TrimEnd('\') -ieq $taskLink.Target.TrimEnd('\')) ('Shortcut target matches: ' + [IO.Path]::GetFileName($taskLink.Path))
        $taskLinks += [ordered]@{ path = $taskLink.Path; target = $taskShortcut.TargetPath; arguments = $taskShortcut.Arguments; working_directory = $taskShortcut.WorkingDirectory }
    }
    $taskRecord.installed_shortcuts = $taskLinks
    Assert-NormalQA ((Get-ProductionSnapshot) -eq $taskBeforeSnapshot) 'Production Unfair registry values and shortcut hashes were unchanged after QA install'
} catch {
    $taskFailure = $_
    $taskRecord.failure = $_.Exception.Message
} finally {
    $taskInstalledUninstaller = Join-Path $taskInstallRoot 'Uninstall.exe'
    if (Test-Path -LiteralPath $taskInstalledUninstaller -PathType Leaf) {
        $taskUninstallCopy = Join-Path $taskBuild ('normal-mode-uninstall-' + $taskTag + '.exe')
        Copy-Item -LiteralPath $taskInstalledUninstaller -Destination $taskUninstallCopy
        $taskUninstallProcess = Start-Process -FilePath $taskUninstallCopy -ArgumentList "/S _?=$taskInstallRoot" -PassThru -Wait -WindowStyle Hidden
        $taskRecord.uninstall_exit_code = $taskUninstallProcess.ExitCode
    }
    $taskRecord.cleanup = [ordered]@{
        install_directory_removed = -not (Test-Path -LiteralPath $taskInstallRoot)
        app_key_removed = $null -eq (Get-RegistryValues $taskAppKey)
        uninstall_key_removed = $null -eq (Get-RegistryValues $taskUninstallKey)
        start_menu_removed = -not (Test-Path -LiteralPath $taskStartMenu)
        desktop_shortcut_removed = -not (Test-Path -LiteralPath $taskDesktopLink)
    }
    $taskRecord.production_snapshot_after = Get-ProductionSnapshot
    $taskRecord.production_unchanged = $taskRecord.production_snapshot_after -eq $taskBeforeSnapshot
    $taskRecord.release_source_sha256_after = (Get-FileHash -LiteralPath $taskSourceFile).Hash
    $taskRecord.release_source_unchanged = $taskRecord.release_source_sha256_after -eq $taskOriginalSourceHash
    $taskRecord.checks = @($taskChecks)
    $taskReport = Join-Path $taskBuild 'normal-mode-qa.json'
    [IO.File]::WriteAllText($taskReport, ($taskRecord | ConvertTo-Json -Depth 10), $taskUtf8)
    $taskRegistry.Dispose()
}
if ($taskFailure) { throw $taskFailure }
foreach ($taskEntry in $taskRecord.cleanup.GetEnumerator()) { if (-not $taskEntry.Value) { throw "QA cleanup incomplete: $($taskEntry.Key); see $taskReport" } }
if (-not $taskRecord.production_unchanged -or -not $taskRecord.release_source_unchanged) { throw "Production/source snapshot changed; see $taskReport" }
Write-Output 'PASS: QA uninstaller removed its files, registry keys and all four shortcuts'
Write-Output 'PASS: Production Unfair entries and release source were untouched'
Write-Output "Normal-mode QA report: $taskReport"
