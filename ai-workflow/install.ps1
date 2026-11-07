[CmdletBinding()]
param(
    [string]$CodexDirectory,
    [string]$UserSkillsDirectory
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($CodexDirectory)) {
    $CodexDirectory = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
}
if ([string]::IsNullOrWhiteSpace($UserSkillsDirectory)) {
    $UserSkillsDirectory = Join-Path $env:USERPROFILE '.agents\skills'
}

$taskSkillSource = Join-Path $PSScriptRoot 'skills\parallel-work-log'
$taskSkillTarget = Join-Path $UserSkillsDirectory 'parallel-work-log'
$taskAgentsTarget = Join-Path $CodexDirectory 'AGENTS.md'
$taskOverridePath = Join-Path $CodexDirectory 'AGENTS.override.md'
$taskManagedBlock = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'global-AGENTS.md') -Raw).Trim()
$taskInstalledSkillFile = [System.IO.Path]::GetFullPath((Join-Path $taskSkillTarget 'SKILL.md')).Replace('\', '/')
$taskManagedBlock = $taskManagedBlock.Replace('~/.agents/skills/parallel-work-log/SKILL.md', $taskInstalledSkillFile)
$taskBegin = '<!-- BEGIN parallel-work-log -->'
$taskEnd = '<!-- END parallel-work-log -->'
$taskRelativeFiles = @('SKILL.md', 'agents\openai.yaml')
$taskUtf8 = [System.Text.UTF8Encoding]::new($false)

# Preflight everything before modifying the user's installation.
foreach ($taskRelativeFile in $taskRelativeFiles) {
    $taskSourcePath = Join-Path $taskSkillSource $taskRelativeFile
    $taskTargetPath = Join-Path $taskSkillTarget $taskRelativeFile
    if (-not (Test-Path -LiteralPath $taskSourcePath -PathType Leaf)) {
        throw "Missing source: $taskSourcePath"
    }
    if (Test-Path -LiteralPath $taskTargetPath) {
        if ((Get-FileHash -LiteralPath $taskSourcePath).Hash -ne (Get-FileHash -LiteralPath $taskTargetPath).Hash) {
            throw "A different skill file already exists. Back it up and reconcile it before installing: $taskTargetPath"
        }
    }
}
if (Test-Path -LiteralPath $taskOverridePath -PathType Leaf) {
    if (-not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $taskOverridePath -Raw))) {
        throw "AGENTS.override.md takes priority. Reconcile its rules before installing: $taskOverridePath"
    }
}

$taskPreviousAgents = if (Test-Path -LiteralPath $taskAgentsTarget -PathType Leaf) {
    [System.IO.File]::ReadAllText($taskAgentsTarget)
} else { '' }
$taskBeginIndex = $taskPreviousAgents.IndexOf($taskBegin, [StringComparison]::Ordinal)
$taskEndIndex = $taskPreviousAgents.IndexOf($taskEnd, [StringComparison]::Ordinal)
if (($taskBeginIndex -ge 0) -or ($taskEndIndex -ge 0)) {
    if (($taskBeginIndex -lt 0) -or ($taskEndIndex -lt $taskBeginIndex)) {
        throw "Incomplete managed block in $taskAgentsTarget; reconcile it before installing."
    }
    $taskAfterEnd = $taskEndIndex + $taskEnd.Length
    if (($taskPreviousAgents.IndexOf($taskBegin, $taskBeginIndex + $taskBegin.Length, [StringComparison]::Ordinal) -ge 0) -or
        ($taskPreviousAgents.IndexOf($taskEnd, $taskAfterEnd, [StringComparison]::Ordinal) -ge 0)) {
        throw "Duplicate managed blocks in $taskAgentsTarget; reconcile them before installing."
    }
    $taskUpdatedAgents = $taskPreviousAgents.Substring(0, $taskBeginIndex) + $taskManagedBlock + $taskPreviousAgents.Substring($taskAfterEnd)
} else {
    $taskSeparator = if ($taskPreviousAgents.Length -eq 0) { '' } elseif ($taskPreviousAgents.EndsWith("`n`n")) { '' } elseif ($taskPreviousAgents.EndsWith("`n")) { "`n" } else { "`n`n" }
    $taskUpdatedAgents = $taskPreviousAgents + $taskSeparator + $taskManagedBlock + "`n"
}

foreach ($taskRelativeFile in $taskRelativeFiles) {
    $taskSourcePath = Join-Path $taskSkillSource $taskRelativeFile
    $taskTargetPath = Join-Path $taskSkillTarget $taskRelativeFile
    if (-not (Test-Path -LiteralPath $taskTargetPath)) {
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $taskTargetPath)) | Out-Null
        Copy-Item -LiteralPath $taskSourcePath -Destination $taskTargetPath
    }
}

if ($taskUpdatedAgents -cne $taskPreviousAgents) {
    [System.IO.Directory]::CreateDirectory($CodexDirectory) | Out-Null
    if (Test-Path -LiteralPath $taskAgentsTarget -PathType Leaf) {
        $taskBackupStamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ', [Globalization.CultureInfo]::InvariantCulture)
        Copy-Item -LiteralPath $taskAgentsTarget -Destination "$taskAgentsTarget.$taskBackupStamp.bak"
    }
    [System.IO.File]::WriteAllText($taskAgentsTarget, $taskUpdatedAgents, $taskUtf8)
}

Write-Output "Installed skill: $taskSkillTarget"
Write-Output "Installed instructions: $taskAgentsTarget"
