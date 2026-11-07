[CmdletBinding()]
param([string]$Executable)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = Join-Path $PSScriptRoot 'smoke\qa-output'
$taskLog = Join-Path (Split-Path -Parent $taskRoot) 'unfair-v8-ai-native-qa.log'
$taskExecutable = if ($Executable) { (Get-Item -LiteralPath $Executable).FullName } else { Join-Path $taskRoot 'bin\godot.windows.editor.dev.x86_64.exe' }
$taskReference = Join-Path $taskOutput 'ai-config-path.txt'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class UnfairRoundProbe {
    [StructLayout(LayoutKind.Sequential)] public struct R { public int Left,Top,Right,Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct P { public int X,Y; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr w,out R r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr w,out R r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr w,ref P p);
    [DllImport("user32.dll")] public static extern int GetWindowRgn(IntPtr w,IntPtr r);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int a,int b,int c,int d);
    [DllImport("gdi32.dll")] public static extern bool PtInRegion(IntPtr r,int x,int y);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr r);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr w,int a,out int v,int size);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr w,IntPtr dc,uint flags);
}
'@
Add-Type -AssemblyName System.Drawing
function Save-AINativeFrame([IntPtr]$Handle,[string]$Stage) {
    $taskRect=[UnfairRoundProbe+R]::new()
    if (-not [UnfairRoundProbe]::GetWindowRect($Handle,[ref]$taskRect)) { throw 'Native capture window disappeared.' }
    $taskBitmap=[Drawing.Bitmap]::new($taskRect.Right-$taskRect.Left,$taskRect.Bottom-$taskRect.Top)
    $taskGraphics=[Drawing.Graphics]::FromImage($taskBitmap)
    $taskDC=$taskGraphics.GetHdc()
    try { $taskCaptured=[UnfairRoundProbe]::PrintWindow($Handle,$taskDC,2) } finally { $taskGraphics.ReleaseHdc($taskDC) }
    try {
        if (-not $taskCaptured) { throw 'Native PrintWindow capture failed.' }
        $taskBitmap.Save((Join-Path $taskOutput "unfair-v8-ai-native-$Stage.png"),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskGraphics.Dispose(); $taskBitmap.Dispose() }
}
$taskProcess = Start-Process -FilePath $taskExecutable -ArgumentList @('--editor','--path','unfair/smoke','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--max-fps','60','--log-file',('"'+$taskLog.Replace('\','/')+'"'),'--','--unfair-ai-qa') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru
$taskAclProof = $null
$taskFrameProofs = @()
for ($taskPoll=0; $taskPoll -lt 160; $taskPoll++) {
    Start-Sleep -Milliseconds 500
    if ($taskProcess.HasExited) { break }
    $taskRegionReference = Join-Path $taskOutput 'ai-window-probe.json'
    if ((Test-Path -LiteralPath $taskRegionReference) -and (Get-Item -LiteralPath $taskRegionReference).LastWriteTime -ge $taskProcess.StartTime) {
        $taskWindowData = Get-Content -LiteralPath $taskRegionReference -Raw | ConvertFrom-Json
        $taskHandle = [IntPtr]([long]$taskWindowData.handle)
        $taskOuter = [UnfairRoundProbe+R]::new()
        $taskClient = [UnfairRoundProbe+R]::new()
        $taskOrigin = [UnfairRoundProbe+P]::new()
        $taskRegion = [UnfairRoundProbe]::CreateRectRgn(0,0,0,0)
        try {
            if ([UnfairRoundProbe]::GetWindowRect($taskHandle,[ref]$taskOuter) -and [UnfairRoundProbe]::GetClientRect($taskHandle,[ref]$taskClient) -and [UnfairRoundProbe]::ClientToScreen($taskHandle,[ref]$taskOrigin)) {
                $taskRegionType = [UnfairRoundProbe]::GetWindowRgn($taskHandle,$taskRegion)
                [int]$taskNCEnabled=0
                $taskNCHResult=[UnfairRoundProbe]::DwmGetWindowAttribute($taskHandle,1,[ref]$taskNCEnabled,4)
                $taskStage=[string]$taskWindowData.stage
                if ($taskStage -notin @($taskFrameProofs | ForEach-Object stage) -and $taskRegionType -eq 0 -and $taskNCHResult -eq 0 -and $taskNCEnabled -eq 1) {
                    $taskCaptions=@(& (Join-Path $PSScriptRoot 'verify_titlebar.ps1') -ProcessId $taskProcess.Id | ConvertFrom-Json)
                    $taskCaption=@($taskCaptions | Where-Object { $_.Handle -eq ('0x{0:X}' -f $taskHandle.ToInt64()) })[0]
                    if ($taskCaption.DarkMode.Value -ne ($taskStage -eq 'dark')) { throw "AI native caption theme mismatch: $taskStage" }
                    foreach ($taskButtonName in @('Minimize','MaximizeOrRestore','Close')) {
                        if (@($taskCaption.CaptionButtons.Buttons | Where-Object { $_.Name -eq $taskButtonName -and $_.VisibleRepresentation -and -not $_.Unavailable }).Count -ne 1) { throw "AI caption button unavailable: $taskButtonName" }
                    }
                    Save-AINativeFrame $taskHandle $taskStage
                    $taskFrameProofs += [pscustomobject]@{stage=$taskStage;region_type=$taskRegionType;dwm_nc_enabled=$taskNCEnabled;caption=$taskCaption}
                }
            }
        } finally { [UnfairRoundProbe]::DeleteObject($taskRegion) | Out-Null }
    }
    if (-not $taskAclProof -and (Test-Path -LiteralPath $taskReference)) {
        $taskPrivatePath = [IO.File]::ReadAllText($taskReference).Trim()
        if ($taskPrivatePath -and (Test-Path -LiteralPath $taskPrivatePath)) {
            $taskAcl = Get-Acl -LiteralPath $taskPrivatePath
            $taskSids = @($taskAcl.Access | ForEach-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } | Sort-Object -Unique)
            $taskUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            if (-not $taskAcl.AreAccessRulesProtected -or @($taskSids | Where-Object { $_ -ne $taskUserSid -and $_ -ne 'S-1-5-18' }).Count -ne 0) { throw 'AI connection file permissions are not restricted to its user and SYSTEM.' }
            $taskAclProof = [pscustomobject]@{protected=$taskAcl.AreAccessRulesProtected;allowed_sids=$taskSids;inherited_rules=@($taskAcl.Access | Where-Object IsInherited).Count}
        }
    }
}
if (-not $taskProcess.HasExited) {
    if ([String]::Equals($taskProcess.Path,$taskExecutable,[StringComparison]::OrdinalIgnoreCase)) { Stop-Process -Id $taskProcess.Id }
    throw 'AI QA exceeded80seconds; stopped its own test process.'
}
Get-Content -LiteralPath $taskLog -Tail 45
if ($taskProcess.ExitCode -ne 0) { throw "AI native QA failed: $($taskProcess.ExitCode)" }
$taskResult = Join-Path $taskOutput 'ai-qa-result.json'
if (-not (Test-Path -LiteralPath $taskResult) -or (Get-Item -LiteralPath $taskResult).LastWriteTime -lt $taskProcess.StartTime) { throw 'AI QA result missing or stale.' }
if (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet) { throw 'AI native QA logged an error.' }
$taskResultData = Get-Content -LiteralPath $taskResult -Raw | ConvertFrom-Json
if (-not $taskResultData.pass) { throw ($taskResultData.failures -join '; ') }
if (-not $taskAclProof) { throw 'Private connection ACL was not observed.' }
if ($taskFrameProofs.Count -ne 2) { throw 'Modern native frame was not verified in both dark and light themes.' }
$taskAclProof | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskOutput 'ai-private-config-acl.json') -Encoding utf8
$taskFrameProofs | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $taskOutput 'v8-ai-native-frames.json') -Encoding utf8
Write-Output 'AI toolbar/layout, native DWM caption dark/light, viewport GUI hit-testing, MCP and private ACL passed.'
