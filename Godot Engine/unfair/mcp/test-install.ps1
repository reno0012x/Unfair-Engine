[CmdletBinding()]
param([string]$PackageDirectory=(Join-Path $PSScriptRoot 'dist\unfair-mcp-1.0.0-windows-x64'),[string]$UnfairPath=(Join-Path $PSScriptRoot '..\..\bin\Unfair.exe'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$taskRoot=[IO.Path]::GetFullPath($PSScriptRoot)
$taskOutput=Join-Path $taskRoot 'qa-output'
$taskRun=Join-Path $taskOutput ('install-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskRun) | Out-Null
$taskClientHome=Join-Path $taskRun 'codex-home'
[IO.Directory]::CreateDirectory($taskClientHome) | Out-Null
$taskPreviousHome=$env:CODEX_HOME
$env:CODEX_HOME=$taskClientHome
$taskChecks=[Collections.Generic.List[string]]::new()
function Assert-InstallQA([bool]$Condition,[string]$Name) { if (-not $Condition) { throw "Installer test failed: $Name" }; $taskChecks.Add($Name); Write-Output "PASS: $Name" }
try {
    $taskDestination=Join-Path $taskRun 'installation'
    & (Join-Path $PackageDirectory 'install.ps1') -UnfairPath $UnfairPath -Destination $taskDestination -ServerName unfair-qa -Client Codex
    $taskInstall=(Get-ChildItem -LiteralPath $taskDestination -Directory | Select-Object -First 1).FullName
    $taskReceipt=Get-Content -LiteralPath (Join-Path $taskInstall 'installation.json') -Raw | ConvertFrom-Json
    Assert-InstallQA ($taskReceipt.client_registered) 'Registered into isolated Codex client config'
    $taskEntry=(& codex mcp get unfair-qa --json | Out-String | ConvertFrom-Json)
    Assert-InstallQA ($taskEntry.transport.command -eq (Join-Path $taskInstall 'runtime\node.exe')) 'Codex points to installed bundled Node'
    & (Join-Path $taskInstall 'doctor.ps1')
    Assert-InstallQA $true 'Doctor verified every installed hash and both executables'
    & (Join-Path $PackageDirectory 'install.ps1') -UnfairPath $UnfairPath -Destination $taskDestination -ServerName unfair-qa -Client Codex
    Assert-InstallQA $true 'Repeat installation with identical managed release succeeds'
    $taskSentinel=Join-Path $taskInstall 'my-project\project.godot'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $taskSentinel)) | Out-Null
    [IO.File]::WriteAllText($taskSentinel,'keep my project')
    $taskModified=Join-Path $taskInstall 'README-th.md'
    [IO.File]::AppendAllText($taskModified,"`nUser change to preserve.")
    $taskUninstallerCopy=Join-Path $taskRun 'uninstall.ps1'
    Copy-Item -LiteralPath (Join-Path $taskInstall 'uninstall.ps1') -Destination $taskUninstallerCopy
    & $taskUninstallerCopy -InstallationDirectory $taskInstall
    Assert-InstallQA ((Test-Path -LiteralPath $taskSentinel) -and (Test-Path -LiteralPath $taskModified)) 'Uninstall preserves nested project and user-modified file'
    Assert-InstallQA (-not (Test-Path -LiteralPath (Join-Path $taskInstall 'runtime\node.exe')) -and -not (Test-Path -LiteralPath (Join-Path $taskInstall 'build\index.js')) -and -not (Test-Path -LiteralPath (Join-Path $taskInstall 'manifest.json'))) 'Uninstall removes owned runtime, server and metadata'
    $taskServers=& codex mcp list --json | Out-String | ConvertFrom-Json
    Assert-InstallQA (@($taskServers | Where-Object name -eq unfair-qa).Count -eq 0) 'Uninstall removes only matching client registration'
    $taskBadRelease=Join-Path $taskRun 'unmanaged'
    $taskManifestHash=(Get-FileHash (Join-Path $PackageDirectory 'manifest.json')).Hash.ToLowerInvariant()
    $taskCollision=Join-Path $taskBadRelease ('1.0.0-'+$taskManifestHash.Substring(0,12))
    [IO.Directory]::CreateDirectory($taskCollision) | Out-Null
    [IO.File]::WriteAllText((Join-Path $taskCollision 'keep.txt'),'keep')
    $taskRejected=$false
    try { & (Join-Path $PackageDirectory 'install.ps1') -UnfairPath $UnfairPath -Destination $taskBadRelease -Client None } catch { $taskRejected=$true }
    Assert-InstallQA ($taskRejected -and @(Get-ChildItem -LiteralPath $taskCollision).Count -eq 1) 'Unmanaged target collision rejects without overwriting'
    $taskCleanDest=Join-Path $taskRun 'clean'
    & (Join-Path $PackageDirectory 'install.ps1') -UnfairPath $UnfairPath -Destination $taskCleanDest -Client Json
    $taskClean=(Get-ChildItem -LiteralPath $taskCleanDest -Directory | Select-Object -First 1).FullName
    Copy-Item -LiteralPath (Join-Path $taskClean 'uninstall.ps1') -Destination $taskUninstallerCopy -Force
    & $taskUninstallerCopy -InstallationDirectory $taskClean
    Assert-InstallQA (-not (Test-Path -LiteralPath $taskClean)) 'Pristine uninstall removes all owned nested directories'
    $taskResult=[ordered]@{pass=$true;checks=@($taskChecks);fixture=$taskRun;package_manifest_sha256=$taskManifestHash}
} finally {
    $env:CODEX_HOME=$taskPreviousHome
}
[IO.File]::WriteAllText((Join-Path $taskOutput 'install-qa.json'),($taskResult|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
