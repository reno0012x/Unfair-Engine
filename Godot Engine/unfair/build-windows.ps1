[CmdletBinding()]
param(
    [string]$Python = 'python',
    [int]$Jobs = 8,
    [switch]$Portable
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskLocalTools = Join-Path (Split-Path -Parent $taskRoot) '.build-tools\python'
if (Test-Path -LiteralPath $taskLocalTools) {
    $env:PYTHONPATH = $taskLocalTools + [IO.Path]::PathSeparator + $env:PYTHONPATH
}
Push-Location -LiteralPath $taskRoot
try {
    & $Python -X utf8 -m SCons platform=windows target=editor arch=x86_64 dev_build=yes debug_symbols=no optimize=none tests=yes angle=yes "-j$Jobs"
    if ($LASTEXITCODE -ne 0) { throw "Unfair build failed: $LASTEXITCODE" }
    Copy-Item -LiteralPath (Join-Path $taskRoot 'bin\godot.windows.editor.dev.x86_64.exe') -Destination (Join-Path $taskRoot 'bin\Unfair.exe') -Force
    Copy-Item -LiteralPath (Join-Path $taskRoot 'bin\godot.windows.editor.dev.x86_64.console.exe') -Destination (Join-Path $taskRoot 'bin\Unfair.console.exe') -Force
    if ($Portable -and -not (Test-Path -LiteralPath (Join-Path $taskRoot 'bin\_sc_'))) {
        [IO.File]::WriteAllText((Join-Path $taskRoot 'bin\_sc_'), '')
    }
    Write-Output "Unfair editor: $(Join-Path $taskRoot 'bin\Unfair.exe')"
} finally {
    Pop-Location
}
