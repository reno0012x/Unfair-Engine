[CmdletBinding()]
param([string]$InstallationDirectory=$PSScriptRoot,[string]$CodexCommand='codex')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$taskRoot=[IO.Path]::GetFullPath($InstallationDirectory).TrimEnd('\','/')
if ($taskRoot -eq [IO.Path]::GetPathRoot($taskRoot).TrimEnd('\','/')) { throw 'Refusing a drive root.' }
$taskReceiptPath=Join-Path $taskRoot 'installation.json'
$taskManifestPath=Join-Path $taskRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $taskReceiptPath -PathType Leaf) -or -not (Test-Path -LiteralPath $taskManifestPath -PathType Leaf)) { throw 'Managed installation receipt and manifest are required.' }
$taskReceipt=Get-Content -LiteralPath $taskReceiptPath -Raw | ConvertFrom-Json
if ($taskReceipt.name -ne 'unfair-mcp' -or $taskReceipt.directory -ine $taskRoot -or (Get-FileHash -LiteralPath $taskManifestPath -Algorithm SHA256).Hash -ine $taskReceipt.manifest_sha256) { throw 'Installation identity or manifest does not match.' }
$taskManifest=Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
if ($taskReceipt.client -eq 'Codex' -and $taskReceipt.client_registered) {
    $taskExisting=& $CodexCommand mcp list --json
    if ($LASTEXITCODE -ne 0) { throw 'Could not read Codex MCP registrations. Preserving installed files.' }
    $taskServers=$taskExisting | Out-String | ConvertFrom-Json
    $taskMatches=@($taskServers | Where-Object { $_.name -eq $taskReceipt.server_name })
    if ($taskMatches.Count -gt 0) {
        $taskCurrent=$taskMatches[0]
        if ($taskCurrent.transport.command -ne $taskReceipt.command -or $taskCurrent.transport.args[0] -ne $taskReceipt.entry) { throw 'MCP client entry was changed after installation. Preserving it and all installed files.' }
        & $CodexCommand mcp remove $taskReceipt.server_name
        if ($LASTEXITCODE -ne 0) { throw 'Could not remove the MCP registration; files preserved.' }
    }
}
# Remove only files whose bytes still match the release; preserve user changes.
$taskDirectories=@()
foreach ($taskFile in $taskManifest.files) {
    $taskRelative=[string]$taskFile.path
    if ([IO.Path]::IsPathRooted($taskRelative) -or $taskRelative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw 'Unsafe manifest entry.' }
    $taskPath=[IO.Path]::GetFullPath((Join-Path $taskRoot $taskRelative))
    if (-not $taskPath.StartsWith($taskRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'File escaped the installation directory.' }
    if (Test-Path -LiteralPath $taskPath -PathType Leaf) {
        $taskItem=Get-Item -LiteralPath $taskPath -Force
        if (($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash -ine $taskFile.sha256) { Write-Output "Preserved changed file: $taskRelative"; continue }
        Remove-Item -LiteralPath $taskPath -Force
    }
    $taskParent=Split-Path -Parent $taskPath
    while ($taskParent.Length -gt $taskRoot.Length) { $taskDirectories += $taskParent; $taskParent=Split-Path -Parent $taskParent }
}
foreach ($taskName in @('client-config.json','installation.json','manifest.json')) { Remove-Item -LiteralPath (Join-Path $taskRoot $taskName) -Force -ErrorAction SilentlyContinue }
foreach ($taskDirectory in ($taskDirectories | Sort-Object -Unique | Sort-Object Length -Descending)) {
    if ((Test-Path -LiteralPath $taskDirectory -PathType Container) -and @(Get-ChildItem -LiteralPath $taskDirectory -Force).Count -eq 0) { Remove-Item -LiteralPath $taskDirectory }
}
if (@(Get-ChildItem -LiteralPath $taskRoot -Force).Count -eq 0) { Remove-Item -LiteralPath $taskRoot }
Write-Output 'Unfair MCP removed. Unrelated files and changed files were preserved.'
