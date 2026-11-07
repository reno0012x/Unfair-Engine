[CmdletBinding()]
param([string]$InstallationDirectory=$PSScriptRoot,[string]$UnfairPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$taskRoot=[IO.Path]::GetFullPath($InstallationDirectory)
$taskManifestPath=Join-Path $taskRoot 'manifest.json'
$taskManifest=Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
$taskFailures=@()
foreach ($taskFile in $taskManifest.files) {
    $taskPath=Join-Path $taskRoot ([string]$taskFile.path)
    if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf) -or (Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash -ine $taskFile.sha256) { $taskFailures += "Missing or changed: $($taskFile.path)" }
}
$taskReceiptPath=Join-Path $taskRoot 'installation.json'
if (-not $UnfairPath -and (Test-Path -LiteralPath $taskReceiptPath)) { $UnfairPath=(Get-Content -LiteralPath $taskReceiptPath -Raw | ConvertFrom-Json).engine }
if (-not $UnfairPath -or -not (Test-Path -LiteralPath $UnfairPath -PathType Leaf)) { $taskFailures += 'Unfair executable missing; specify -UnfairPath.' }
$taskNode=Join-Path $taskRoot 'runtime\node.exe'
if (Test-Path -LiteralPath $taskNode) { & $taskNode --version; if ($LASTEXITCODE -ne 0) { $taskFailures += 'Node runtime failed.' } }
if ($taskFailures.Count) { throw ($taskFailures -join "`n") }
& $UnfairPath --version
if ($LASTEXITCODE -ne 0) { throw 'Engine version check failed.' }
Write-Output 'PASS: release file hashes, bundled Node runtime and engine executable.'
