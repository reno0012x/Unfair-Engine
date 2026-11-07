[CmdletBinding()]
param(
    [string]$Installer,
    [string]$TestDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskWorkspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
if (-not $Installer) { $Installer = Join-Path $PSScriptRoot 'dist\install.exe' }
if (-not $TestDirectory) { $TestDirectory = Join-Path $taskWorkspaceRoot ('unfair-installer-test-' + [Guid]::NewGuid().ToString('N')) }
$taskTestRoot = [IO.Path]::GetFullPath($TestDirectory).TrimEnd('\')
if (-not $taskTestRoot.StartsWith($taskWorkspaceRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or $taskTestRoot -eq $taskWorkspaceRoot -or (Test-Path -LiteralPath $taskTestRoot)) {
    throw 'Installer QA requires a new, unique subdirectory inside the workspace.'
}
$taskInstallerFile = (Get-Item -LiteralPath $Installer -ErrorAction Stop).FullName
$taskManifestPath = Join-Path (Split-Path -Parent $taskInstallerFile) 'installed-files.json'
$taskManifest = Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
$taskEvidence = [ordered]@{ test_directory = $taskTestRoot; installer_sha256 = (Get-FileHash -LiteralPath $taskInstallerFile).Hash; checks = @() }
function Assert-QA([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "Installer QA failed: $Name" }
    $taskEvidence.checks += $Name
    Write-Output "PASS: $Name"
}
function Invoke-TestInstall {
    param([string]$Destination)
    # /D= must be the final argument. Its value is intentionally not quoted
    # inside the command line; NSIS consumes the remaining text as the path.
    $taskProcess = Start-Process -FilePath $taskInstallerFile -ArgumentList "/S /TESTMODE=1 /D=$Destination" -PassThru -Wait -WindowStyle Hidden
    Write-Host "Installer QA target: $Destination; process $($taskProcess.Id); exit code: $($taskProcess.ExitCode)"
    $taskProcess.ExitCode
}

$taskInitialUserProcesses = @(Get-Process -Name Unfair -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$taskCollisionRoot = Join-Path $PSScriptRoot ('build\collision-qa-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskCollisionRoot) | Out-Null
$taskCollisionSentinel = Join-Path $taskCollisionRoot 'existing-user-file.txt'
[IO.File]::WriteAllText($taskCollisionSentinel, 'Unmanaged folder must not be claimed or overwritten.')
Assert-QA ((Invoke-TestInstall -Destination $taskCollisionRoot) -eq 2) 'Nonempty unmanaged installation folder was rejected'
Assert-QA (([IO.File]::ReadAllText($taskCollisionSentinel) -eq 'Unmanaged folder must not be claimed or overwritten.') -and @(Get-ChildItem -LiteralPath $taskCollisionRoot -Force).Count -eq 1) 'Collision rejection preserved the existing file and wrote nothing else'
Assert-QA ((Invoke-TestInstall -Destination $taskTestRoot) -eq 0) 'Silent installation succeeded in isolated workspace folder'
foreach ($taskEntry in $taskManifest.files) {
    $taskTarget = Join-Path $taskTestRoot $taskEntry.path
    Assert-QA ((Test-Path -LiteralPath $taskTarget -PathType Leaf) -and (Get-FileHash -LiteralPath $taskTarget).Hash -ieq $taskEntry.sha256) ("Payload hash: " + $taskEntry.path)
    $taskAttrs = (Get-Item -LiteralPath $taskTarget).Attributes
    Assert-QA (-not [bool]($taskAttrs -band [IO.FileAttributes]::Hidden)) ("Visible file: " + $taskEntry.path)
}
Assert-QA (Test-Path -LiteralPath (Join-Path $taskTestRoot 'Uninstall.exe') -PathType Leaf) 'Uninstall.exe exists'
Assert-QA (-not (Test-Path -LiteralPath (Join-Path $taskTestRoot '_sc_')) -and -not (Test-Path -LiteralPath (Join-Path $taskTestRoot 'editor_data'))) 'No developer portable settings or marker were packaged'
Assert-QA ((Invoke-TestInstall -Destination $taskTestRoot) -eq 0) 'Upgrade in place succeeded'
$taskUserProcessesAfter = @(Get-Process -Name Unfair -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
Assert-QA (@($taskUserProcessesAfter | Where-Object { $_ -notin $taskInitialUserProcesses }).Count -eq 0) 'Silent setup did not launch Unfair'

$taskSentinelFolder = Join-Path $taskTestRoot 'my-project\nested'
[IO.Directory]::CreateDirectory($taskSentinelFolder) | Out-Null
$taskSentinel = Join-Path $taskSentinelFolder 'keep-me.txt'
[IO.File]::WriteAllText($taskSentinel, 'User project must survive uninstall.')
$taskUnknown = Join-Path $taskTestRoot 'unknown-user-file.txt'
[IO.File]::WriteAllText($taskUnknown, 'Unknown file must survive uninstall.')
$taskCopiedUninstaller = Join-Path $PSScriptRoot ('build\uninstaller-qa-' + [Guid]::NewGuid().ToString('N') + '.exe')
Copy-Item -LiteralPath (Join-Path $taskTestRoot 'Uninstall.exe') -Destination $taskCopiedUninstaller
$taskUninstallProcess = Start-Process -FilePath $taskCopiedUninstaller -ArgumentList "/S _?=$taskTestRoot" -PassThru -Wait -WindowStyle Hidden
Assert-QA ($taskUninstallProcess.ExitCode -eq 0) 'Uninstaller process reported success'
foreach ($taskEntry in $taskManifest.files) { Assert-QA (-not (Test-Path -LiteralPath (Join-Path $taskTestRoot $taskEntry.path))) ("Owned file removed: " + $taskEntry.path) }
Assert-QA (-not (Test-Path -LiteralPath (Join-Path $taskTestRoot 'Uninstall.exe')) -and -not (Test-Path -LiteralPath (Join-Path $taskTestRoot 'unfair-install.ini')) -and -not (Test-Path -LiteralPath (Join-Path $taskTestRoot 'installed-files.json'))) 'Uninstaller and installation metadata were removed'
Assert-QA ((Test-Path -LiteralPath $taskSentinel) -and (Test-Path -LiteralPath $taskUnknown)) 'Nested project and unknown file survived uninstall'

$taskReport = Join-Path $PSScriptRoot 'build\installer-qa.json'
[IO.File]::WriteAllText($taskReport, ($taskEvidence | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Write-Output "QA report: $taskReport"
Write-Output "Sentinel files intentionally retained at $taskTestRoot"
