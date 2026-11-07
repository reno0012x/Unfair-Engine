[CmdletBinding()]
param(
    [ValidateSet('Editor','ProjectManager')]
    [string]$Mode = 'Editor'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = Join-Path $PSScriptRoot 'smoke\qa-output'
[IO.Directory]::CreateDirectory($taskOutput) | Out-Null
$taskStem = if ($Mode -eq 'Editor') { 'editor' } else { 'pm' }
$taskLog = Join-Path (Split-Path -Parent $taskRoot) "unfair-v4-$taskStem-qa.log"
$taskExecutable = Join-Path $taskRoot 'bin\godot.windows.editor.dev.x86_64.exe'
$taskArguments = if ($Mode -eq 'Editor') {
    @('--editor','--path','unfair/smoke')
} else {
    @('--project-manager','--script','unfair/smoke/project_manager_qa.gd')
}
$taskArguments += @('--rendering-method','gl_compatibility','--rendering-driver','opengl3','--max-fps','60','--log-file',('"'+$taskLog.Replace('\','/')+'"'))
if ($Mode -eq 'Editor') { $taskArguments += @('--','--unfair-v4-qa') }
$taskProcess = Start-Process -FilePath $taskExecutable -ArgumentList $taskArguments -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru
$taskProbes = @()
for ($taskPoll=0; $taskPoll -lt 60; $taskPoll++) {
    Start-Sleep -Milliseconds 1000
    if ($taskProcess.HasExited) { break }
    $taskProbe = & (Join-Path $PSScriptRoot 'verify_titlebar.ps1') -ProcessId $taskProcess.Id | ConvertFrom-Json
    $taskProbes += [pscustomobject]@{time=[DateTimeOffset]::Now.ToString('o'); windows=@($taskProbe | Where-Object { $_.HasCaption })}
}
$taskProbes | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath (Join-Path $taskOutput "$taskStem-titlebar-probes.json") -Encoding utf8
if (-not $taskProcess.HasExited) {
    if ([String]::Equals($taskProcess.Path, $taskExecutable, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Process -Id $taskProcess.Id
    }
    throw "QA exceeded 60 seconds; stopped its own test process $($taskProcess.Id)."
}
Get-Content -LiteralPath $taskLog -Tail 40
$taskResult = Join-Path $taskOutput $(if ($Mode -eq 'Editor') {'workbench-qa-result.json'} else {'project-manager-qa-result.json'})
if ($taskProcess.ExitCode -ne 0) { throw "QA process failed: $($taskProcess.ExitCode)" }
if (-not (Test-Path -LiteralPath $taskResult)) { throw 'QA result was not generated.' }
if ((Get-Item -LiteralPath $taskResult).LastWriteTime -lt $taskProcess.StartTime) { throw 'QA result is stale.' }
if (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR:' -Quiet) { throw 'QA script reported a runtime or parse error.' }
$taskResultData = Get-Content -LiteralPath $taskResult -Raw | ConvertFrom-Json
if (-not $taskResultData.pass) { throw ($taskResultData.failures -join '; ') }
$taskMainWindows = @($taskProbes | ForEach-Object { $_.windows } | Where-Object { $_.Visible -and $_.MinimizeBox -and $_.MaximizeBox -and $_.SystemMenu })
if ($taskMainWindows.Count -eq 0) { throw 'No native main-window caption was observed.' }
foreach ($taskCaptionName in @('Minimize','MaximizeOrRestore','Close')) {
    $taskVisibleButton = @($taskMainWindows | ForEach-Object { $_.CaptionButtons.Buttons } | Where-Object { $_.Name -eq $taskCaptionName -and $_.VisibleRepresentation -eq $true -and -not $_.Unavailable })
    if ($taskVisibleButton.Count -eq 0) { throw "Native $taskCaptionName caption button has no visible usable representation." }
}
if ($taskMainWindows[0].DarkMode.Value -ne $true) { throw 'First observed Unfair startup caption was not dark.' }
Write-Output 'Native minimize/maximize/close buttons are visible and available; first observed startup caption is dark.'
if ($Mode -eq 'Editor') {
    $taskFolderStates = @($taskProbes | ForEach-Object { $_.windows } | Where-Object { $_.Title -eq 'Choose Project Folder' } | ForEach-Object { $_.DarkMode.Value } | Sort-Object -Unique)
    if ($taskFolderStates.Count -ne 2) { throw 'Native folder titlebar did not expose both dark and light states.' }
    Write-Output 'Native titlebar followed dark and light application themes.'
}
Write-Output "$Mode native UI QA passed."
