[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$ProcessId
)

$ErrorActionPreference = 'Stop'
Get-Process -Id $ProcessId -ErrorAction Stop | Out-Null

# Read native attributes only. The probe never changes focus or window state.
if (-not ('Unfair.NativeTitlebarProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace Unfair {
    public static class NativeTitlebarProbe {
        private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lparam);
        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lparam);
        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowTextW(IntPtr hwnd, StringBuilder text, int maximum);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassNameW(IntPtr hwnd, StringBuilder text, int maximum);
        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);
        [DllImport("dwmapi.dll")]
        public static extern int DwmGetWindowAttribute(IntPtr hwnd, uint attribute, out uint value, uint size);
        [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")]
        private static extern int GetDwmRectangle(IntPtr hwnd, uint attribute, out NativeRectangle value, uint size);
        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetTitleBarInfo(IntPtr hwnd, ref TitleBarInfo info);
        [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", SetLastError = true)]
        private static extern IntPtr SendTitleBarInfoMessage(IntPtr hwnd, uint message, UIntPtr wparam,
            ref TitleBarInfoEx info, uint flags, uint timeout, out UIntPtr result);

        [StructLayout(LayoutKind.Sequential)]
        public struct NativeRectangle {
            public int Left, Top, Right, Bottom;
            public int Width { get { return Right - Left; } }
            public int Height { get { return Bottom - Top; } }
            public bool HasArea { get { return Width > 0 && Height > 0; } }
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct TitleBarInfo {
            public uint Size;
            public NativeRectangle Bounds;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 6)]
            public uint[] States;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct TitleBarInfoEx {
            public uint Size;
            public NativeRectangle Bounds;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 6)]
            public uint[] States;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 6)]
            public NativeRectangle[] Rectangles;
        }
        public sealed class CaptionButtonDiagnostic {
            public string Name;
            public int Index;
            public string State;
            public bool Invisible, Unavailable, Offscreen, Pressed;
            public NativeRectangle? ScreenRectangle;
            public bool? VisibleRepresentation;
        }
        public sealed class TitlebarDiagnostic {
            public bool InfoAvailable;
            public int InfoWin32Error;
            public NativeRectangle? TitlebarScreenRectangle;
            public string TitlebarState;
            public bool? TitlebarInvisible, TitlebarUnavailable, TitlebarOffscreen;
            public bool ExtendedInfoAvailable;
            public int ExtendedInfoWin32Error;
            public string CaptionButtonBoundsHResult;
            public NativeRectangle? CaptionButtonWindowRectangle;
            public CaptionButtonDiagnostic[] Buttons;
        }

        public static uint GetStyle(IntPtr hwnd) {
            return unchecked((uint)GetWindowLong(hwnd, -16));
        }
        public static bool HasStyle(IntPtr hwnd, uint mask) {
            return (GetStyle(hwnd) & mask) == mask;
        }
        public static TitlebarDiagnostic ReadTitlebar(IntPtr hwnd) {
            var snapshot = new TitlebarDiagnostic();
            var info = new TitleBarInfo {
                Size = (uint)Marshal.SizeOf(typeof(TitleBarInfo)), States = new uint[6]
            };
            snapshot.InfoAvailable = GetTitleBarInfo(hwnd, ref info);
            snapshot.InfoWin32Error = snapshot.InfoAvailable ? 0 : Marshal.GetLastWin32Error();
            if (snapshot.InfoAvailable) {
                snapshot.TitlebarScreenRectangle = info.Bounds;
                snapshot.TitlebarState = "0x" + info.States[0].ToString("X8");
                snapshot.TitlebarInvisible = (info.States[0] & 0x8000) != 0;
                snapshot.TitlebarUnavailable = (info.States[0] & 1) != 0;
                snapshot.TitlebarOffscreen = (info.States[0] & 0x10000) != 0;
            }
            var extended = new TitleBarInfoEx {
                Size = (uint)Marshal.SizeOf(typeof(TitleBarInfoEx)), States = new uint[6],
                Rectangles = new NativeRectangle[6]
            };
            UIntPtr ignored;
            // WM_GETTITLEBARINFOEX is a read-only system message. Bound the call
            // so a hung target window cannot block the diagnostics indefinitely.
            snapshot.ExtendedInfoAvailable = SendTitleBarInfoMessage(hwnd, 0x033F, UIntPtr.Zero,
                ref extended, 0x0002, 500, out ignored) != IntPtr.Zero;
            snapshot.ExtendedInfoWin32Error = snapshot.ExtendedInfoAvailable ? 0 : Marshal.GetLastWin32Error();
            NativeRectangle captionBounds;
            int hr = GetDwmRectangle(hwnd, 5, out captionBounds, (uint)Marshal.SizeOf(typeof(NativeRectangle)));
            snapshot.CaptionButtonBoundsHResult = "0x" + unchecked((uint)hr).ToString("X8");
            if (hr == 0) snapshot.CaptionButtonWindowRectangle = captionBounds;

            var buttons = new List<CaptionButtonDiagnostic>();
            int[] indices = { 2, 3, 4, 5 };
            string[] names = { "Minimize", "MaximizeOrRestore", "Help", "Close" };
            if (snapshot.InfoAvailable || snapshot.ExtendedInfoAvailable) {
                for (int i = 0; i < indices.Length; i++) {
                    int index = indices[i];
                    uint state = snapshot.InfoAvailable ? info.States[index] : extended.States[index];
                    var button = new CaptionButtonDiagnostic {
                        Name = names[i], Index = index, State = "0x" + state.ToString("X8"),
                        Invisible = (state & 0x8000) != 0, Unavailable = (state & 1) != 0,
                        Offscreen = (state & 0x10000) != 0, Pressed = (state & 8) != 0
                    };
                    if (snapshot.ExtendedInfoAvailable) {
                        button.ScreenRectangle = extended.Rectangles[index];
                        button.VisibleRepresentation = IsWindowVisible(hwnd) && !button.Invisible &&
                            !button.Offscreen && extended.Rectangles[index].HasArea;
                    }
                    buttons.Add(button);
                }
            }
            snapshot.Buttons = buttons.ToArray();
            return snapshot;
        }

        public static IntPtr[] GetWindows(uint processId) {
            var windows = new List<IntPtr>();
            EnumWindows((hwnd, unused) => {
                uint owner;
                GetWindowThreadProcessId(hwnd, out owner);
                if (owner == processId) windows.Add(hwnd);
                return true;
            }, IntPtr.Zero);
            return windows.ToArray();
        }
        public static string GetTitle(IntPtr hwnd) {
            var text = new StringBuilder(2048);
            GetWindowTextW(hwnd, text, text.Capacity);
            return text.ToString();
        }
        public static string GetClassName(IntPtr hwnd) {
            var text = new StringBuilder(256);
            GetClassNameW(hwnd, text, text.Capacity);
            return text.ToString();
        }
        public static bool HasCaption(IntPtr hwnd) {
            return (GetWindowLong(hwnd, -16) & 0x00C00000) == 0x00C00000;
        }
    }
}
'@
}

function Read-TitlebarAttribute {
    param([IntPtr]$WindowHandle, [uint32]$Attribute, [switch]$Color)

    [uint32]$taskValue = 0
    [int]$taskResult = [Unfair.NativeTitlebarProbe]::DwmGetWindowAttribute($WindowHandle, $Attribute, [ref]$taskValue, 4)
    $taskDecoded = $null
    if ($taskResult -eq 0) {
        if (-not $Color) {
            $taskDecoded = $taskValue -ne 0
        } elseif ($taskValue -eq [uint32]::MaxValue) {
            $taskDecoded = 'System default'
        } elseif ($taskValue -eq ([uint32]::MaxValue - 1)) {
            $taskDecoded = 'None'
        } else {
            $taskDecoded = '#{0:X2}{1:X2}{2:X2}' -f ($taskValue -band 255), (($taskValue -shr 8) -band 255), (($taskValue -shr 16) -band 255)
        }
    }
    [pscustomobject]@{
        HResult = '0x' + [Convert]::ToString($taskResult, 16).PadLeft(8, '0').ToUpperInvariant()
        Raw = if ($taskResult -eq 0) { '0x{0:X8}' -f $taskValue } else { $null }
        Value = $taskDecoded
    }
}

$taskForeground = [Unfair.NativeTitlebarProbe]::GetForegroundWindow()
$taskWindows = @(
    foreach ($taskWindow in [Unfair.NativeTitlebarProbe]::GetWindows([uint32]$ProcessId)) {
        [pscustomobject]@{
            ProcessId = $ProcessId
            Handle = '0x{0:X}' -f $taskWindow.ToInt64()
            Title = [Unfair.NativeTitlebarProbe]::GetTitle($taskWindow)
            Class = [Unfair.NativeTitlebarProbe]::GetClassName($taskWindow)
            Visible = [Unfair.NativeTitlebarProbe]::IsWindowVisible($taskWindow)
            Active = $taskWindow -eq $taskForeground
            Style = '0x{0:X8}' -f [Unfair.NativeTitlebarProbe]::GetStyle($taskWindow)
            HasCaption = [Unfair.NativeTitlebarProbe]::HasCaption($taskWindow)
            SystemMenu = [Unfair.NativeTitlebarProbe]::HasStyle($taskWindow, 0x00080000)
            MinimizeBox = [Unfair.NativeTitlebarProbe]::HasStyle($taskWindow, 0x00020000)
            MaximizeBox = [Unfair.NativeTitlebarProbe]::HasStyle($taskWindow, 0x00010000)
            ResizableFrame = [Unfair.NativeTitlebarProbe]::HasStyle($taskWindow, 0x00040000)
            CaptionButtons = [Unfair.NativeTitlebarProbe]::ReadTitlebar($taskWindow)
            DarkMode = Read-TitlebarAttribute -WindowHandle $taskWindow -Attribute 20
            LegacyDarkMode = Read-TitlebarAttribute -WindowHandle $taskWindow -Attribute 19
            Caption = Read-TitlebarAttribute -WindowHandle $taskWindow -Attribute 35 -Color
            Text = Read-TitlebarAttribute -WindowHandle $taskWindow -Attribute 36 -Color
            Border = Read-TitlebarAttribute -WindowHandle $taskWindow -Attribute 34 -Color
        }
    }
)
ConvertTo-Json -InputObject $taskWindows -Depth 8
