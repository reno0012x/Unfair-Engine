[CmdletBinding()]
param(
    [ValidateSet('Both', 'Installed', 'Embedded')]
    [string]$Mode = 'Both',
    [ValidateRange(15, 180)]
    [int]$TimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskProject = Join-Path $PSScriptRoot 'smoke'
$taskOutput = Join-Path $taskProject 'qa-output'
$taskFixture = Join-Path $taskProject 'loading-fixture'
$taskExecutable = Join-Path $taskRoot 'bin\godot.windows.editor.dev.x86_64.exe'
$taskBackground = Join-Path $taskRoot 'editor\themes\unfair_loading_background.png'
$taskCases = if ($Mode -eq 'Both') { @('installed', 'embedded') } else { @($Mode.ToLowerInvariant()) }
foreach ($taskDirectory in @($taskOutput, $taskFixture)) { [IO.Directory]::CreateDirectory($taskDirectory) | Out-Null }
[IO.File]::WriteAllText((Join-Path $taskOutput '.gdignore'), '')
if (-not (Test-Path -LiteralPath $taskBackground -PathType Leaf)) { throw 'Generated loading reference PNG is missing.' }

foreach ($taskCase in $taskCases) {
    # These are real editor texture-import inputs, not fabricated progress tasks.
    for ($taskIndex = 0; $taskIndex -lt 4; $taskIndex++) {
        Copy-Item -LiteralPath $taskBackground -Destination (Join-Path $taskFixture "$taskCase-$taskIndex.png") -Force
    }
    $taskRunExecutable = $taskExecutable
    $taskWorkingDirectory = $taskRoot
    if ($taskCase -eq 'embedded') {
        # A separate portable copy has no external artwork. This exercises the
        # compiled fallback without renaming the installed application's assets.
        $taskFallbackDirectory = Join-Path $taskOutput 'loading-embedded-runtime'
        [IO.Directory]::CreateDirectory($taskFallbackDirectory) | Out-Null
        [IO.File]::WriteAllText((Join-Path $taskFallbackDirectory '_sc_'), '')
        $taskRunExecutable = Join-Path $taskFallbackDirectory 'Unfair-loading-fallback.exe'
        Copy-Item -LiteralPath $taskExecutable -Destination $taskRunExecutable -Force
        $taskWorkingDirectory = $taskFallbackDirectory
        if (Test-Path -LiteralPath (Join-Path $taskFallbackDirectory 'assets\loading\unfair-loading-background.png')) {
            throw 'Fallback test directory unexpectedly contains external loading artwork.'
        }
    } elseif (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $taskExecutable) 'assets\loading\unfair-loading-background.png'))) {
        throw 'Installed loading artwork is missing; installed case cannot prove its loading path.'
    }
    $taskLog = Join-Path (Split-Path -Parent $taskRoot) "unfair-v6-loading-$taskCase-qa.log"
    $taskArguments = @('--editor', '--path', ('"' + $taskProject.Replace('\', '/') + '"'),
        '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--max-fps', '60',
        '--log-file', ('"' + $taskLog.Replace('\', '/') + '"'), '--', '--unfair-loading-qa',
        ('"--unfair-loading-source=' + $taskBackground.Replace('\', '/') + '"'))
    if ($taskCase -eq 'embedded') { $taskArguments += '--unfair-loading-fallback' }
    $taskProcess = Start-Process -FilePath $taskRunExecutable -ArgumentList $taskArguments -WorkingDirectory $taskWorkingDirectory -WindowStyle Hidden -PassThru
    $taskDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $taskProcess.HasExited -and [DateTime]::UtcNow -lt $taskDeadline) {
        Start-Sleep -Milliseconds 250
        $taskProcess.Refresh()
    }
    if (-not $taskProcess.HasExited) {
        if ([String]::Equals($taskProcess.Path, $taskRunExecutable, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-Process -Id $taskProcess.Id
        }
        throw "Loading $taskCase QA exceeded $TimeoutSeconds seconds; stopped its own process."
    }
    $taskProcess.WaitForExit()
    if (Test-Path -LiteralPath $taskLog) { Get-Content -LiteralPath $taskLog -Tail 12 }
    $taskResult = Join-Path $taskOutput "loading-$taskCase-qa-result.json"
    if (-not (Test-Path -LiteralPath $taskResult) -or (Get-Item -LiteralPath $taskResult).LastWriteTime -lt $taskProcess.StartTime) {
        throw "Loading $taskCase QA result is missing or stale."
    }
    $taskResultData = Get-Content -LiteralPath $taskResult -Raw | ConvertFrom-Json
    if (-not $taskResultData.pass) { throw ($taskResultData.failures -join '; ') }
    if ($taskProcess.ExitCode -ne 0) { throw "Loading $taskCase process failed: $($taskProcess.ExitCode)" }
    if (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR:|ERROR:|CrashHandlerException' -Quiet) {
        throw "Loading $taskCase native QA logged an error."
    }
    Write-Output "Loading $taskCase passed: actual startup/import/scan, generated background pixels, native Cancel and task completion."
}
