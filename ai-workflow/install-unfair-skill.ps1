[CmdletBinding()]
param([string]$SkillsDirectory)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SkillsDirectory)) {
    $taskCodexDirectory = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $SkillsDirectory = Join-Path $taskCodexDirectory 'skills'
}
$taskSource = Join-Path $PSScriptRoot 'skills\unfair-engine-mcp'
$taskTarget = Join-Path ([IO.Path]::GetFullPath($SkillsDirectory)) 'unfair-engine-mcp'
$taskFiles = @('SKILL.md', 'agents\openai.yaml')
foreach ($taskRelative in $taskFiles) {
    $taskInput = Join-Path $taskSource $taskRelative
    $taskOutput = Join-Path $taskTarget $taskRelative
    if (-not (Test-Path -LiteralPath $taskInput -PathType Leaf)) { throw "Missing skill source: $taskInput" }
    if ((Test-Path -LiteralPath $taskOutput) -and (Get-FileHash -LiteralPath $taskInput).Hash -ne (Get-FileHash -LiteralPath $taskOutput).Hash) {
        throw "A different skill already exists; preserve and reconcile it before updating: $taskOutput"
    }
}
foreach ($taskRelative in $taskFiles) {
    $taskInput = Join-Path $taskSource $taskRelative
    $taskOutput = Join-Path $taskTarget $taskRelative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $taskOutput)) | Out-Null
    if (-not (Test-Path -LiteralPath $taskOutput)) { Copy-Item -LiteralPath $taskInput -Destination $taskOutput }
    if ((Get-FileHash -LiteralPath $taskInput).Hash -ne (Get-FileHash -LiteralPath $taskOutput).Hash) { throw "Installed hash mismatch: $taskRelative" }
}
Write-Output "Installed Unfair skill: $taskTarget"
Write-Output 'Start a new Codex chat to discover $unfair-engine-mcp. Existing skills and MCP configuration were preserved.'
