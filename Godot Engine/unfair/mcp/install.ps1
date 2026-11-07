[CmdletBinding()]
param(
    [string]$UnfairPath,
    [string]$Destination = (Join-Path $env:LOCALAPPDATA 'Unfair\MCP'),
    [ValidateSet('Codex','Json','None')][string]$Client = 'Codex',
    [string]$ServerName = 'unfair-engine',
    [string]$CodexCommand = 'codex'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($ServerName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid MCP server name.' }
$taskPackage = [IO.Path]::GetFullPath($PSScriptRoot)
$taskManifestPath = Join-Path $taskPackage 'manifest.json'
if (-not (Test-Path -LiteralPath $taskManifestPath -PathType Leaf)) { throw 'Run install.ps1 from the extracted release package, not the source directory.' }
$taskManifest = Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
if ($taskManifest.name -ne 'unfair-mcp' -or $taskManifest.version -ne '1.0.0') { throw 'Unsupported package manifest.' }
$taskManifestHash = (Get-FileHash -LiteralPath $taskManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if (-not $UnfairPath) {
    foreach ($taskCandidate in @((Join-Path $taskPackage '..\..\..\..\bin\Unfair.exe'), (Join-Path $env:LOCALAPPDATA 'Programs\Unfair\Unfair.exe'))) {
        if (Test-Path -LiteralPath $taskCandidate -PathType Leaf) { $UnfairPath = $taskCandidate; break }
    }
}
if (-not $UnfairPath -or -not (Test-Path -LiteralPath $UnfairPath -PathType Leaf)) { throw 'Specify -UnfairPath with the path to Unfair.exe.' }
$UnfairPath = (Resolve-Path -LiteralPath $UnfairPath).Path
$taskEngineVersion = & $UnfairPath --version | Out-String
if ($LASTEXITCODE -ne 0 -or $taskEngineVersion -notmatch '^\s*4\.') { throw 'The specified engine is not a working Godot 4 compatible Unfair executable.' }
$taskBase = [IO.Path]::GetFullPath($Destination).TrimEnd('\','/')
if ($taskBase -eq [IO.Path]::GetPathRoot($taskBase).TrimEnd('\','/')) { throw 'The installation directory cannot be a drive root.' }
$taskInstall = Join-Path $taskBase ('1.0.0-' + $taskManifestHash.Substring(0,12))
if (Test-Path -LiteralPath $taskInstall) {
    $taskPriorReceipt = Join-Path $taskInstall 'installation.json'
    if (-not (Test-Path -LiteralPath $taskPriorReceipt -PathType Leaf)) { throw 'The destination exists and is not a managed Unfair MCP installation.' }
    $taskPrior = Get-Content -LiteralPath $taskPriorReceipt -Raw | ConvertFrom-Json
    if ($taskPrior.manifest_sha256 -ne $taskManifestHash) { throw 'Existing installation belongs to a different release.' }
}
foreach ($taskFile in $taskManifest.files) {
    $taskRelative = [string]$taskFile.path
    if ([IO.Path]::IsPathRooted($taskRelative) -or $taskRelative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw 'Unsafe package entry.' }
    $taskSource = Join-Path $taskPackage $taskRelative
    $taskItem = Get-Item -LiteralPath $taskSource -Force
    if ($taskItem.PSIsContainer -or ($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Expected regular package file: $taskRelative" }
    if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash -ine $taskFile.sha256) { throw "Package hash mismatch: $taskRelative" }
}
$taskNode = Join-Path $taskInstall 'runtime\node.exe'
$taskEntry = Join-Path $taskInstall 'build\index.js'
$taskPrevious = $null
if ($Client -eq 'Codex') {
    $null = Get-Command $CodexCommand -ErrorAction Stop
    $taskExisting = & $CodexCommand mcp list --json
    if ($LASTEXITCODE -ne 0) { throw 'Could not read Codex MCP registrations. Files and configuration were not changed.' }
    $taskServers = $taskExisting | Out-String | ConvertFrom-Json
    $taskPrevious = @($taskServers | Where-Object { $_.name -eq $ServerName })
    if ($taskPrevious.Count -gt 0) {
        $taskPrevious = $taskPrevious[0]
        if ($taskPrevious.transport.command -ne $taskNode -or $taskPrevious.transport.args[0] -ne $taskEntry) { throw "MCP entry '$ServerName' already exists. Choose a different -ServerName; existing settings were preserved." }
    }
}
[IO.Directory]::CreateDirectory($taskInstall) | Out-Null
foreach ($taskFile in $taskManifest.files) {
    $taskSource = Join-Path $taskPackage ([string]$taskFile.path)
    $taskTarget = Join-Path $taskInstall ([string]$taskFile.path)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $taskTarget)) | Out-Null
    Copy-Item -LiteralPath $taskSource -Destination $taskTarget -Force
    if ((Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash -ine $taskFile.sha256) { throw "Installed hash mismatch: $($taskFile.path)" }
}
Copy-Item -LiteralPath $taskManifestPath -Destination (Join-Path $taskInstall 'manifest.json') -Force
$taskConfig = [ordered]@{ mcpServers = @{} }
$taskConfig.mcpServers[$ServerName] = [ordered]@{ command = $taskNode; args = @($taskEntry); env = @{UNFAIR_PATH=$UnfairPath} }
$taskConfigPath = Join-Path $taskInstall 'client-config.json'
[IO.File]::WriteAllText($taskConfigPath, ($taskConfig | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$taskReceipt = [ordered]@{ name='unfair-mcp'; version='1.0.0'; manifest_sha256=$taskManifestHash; installed_at=[DateTimeOffset]::Now.ToString('o'); directory=$taskInstall; engine=$UnfairPath; client=$Client; server_name=$ServerName; command=$taskNode; entry=$taskEntry; client_registered=$false }
$taskReceiptPath = Join-Path $taskInstall 'installation.json'
function Save-Receipt { [IO.File]::WriteAllText($taskReceiptPath, ($taskReceipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false)) }
Save-Receipt
if ($Client -eq 'Codex') {
    & $CodexCommand mcp add $ServerName --env "UNFAIR_PATH=$UnfairPath" -- $taskNode $taskEntry
    if ($LASTEXITCODE -ne 0) { throw "Files installed, but Codex registration failed. Use $taskConfigPath to configure the client." }
    $taskReceipt.client_registered=$true
    Save-Receipt
}
Write-Output "Installed Unfair MCP: $taskInstall"
Write-Output "MCP configuration: $taskConfigPath"
if ($Client -eq 'Codex') { Write-Output 'Open a new Codex chat or restart the client to discover the new tools.' }
