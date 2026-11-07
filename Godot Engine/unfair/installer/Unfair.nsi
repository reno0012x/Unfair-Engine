; -*- coding: utf-8 -*-
Unicode true
RequestExecutionLevel user
ManifestDPIAware true
!ifdef FAST_PACKAGE
SetCompressor zlib
!else
SetCompressor /SOLID lzma
SetCompressorDictSize 32
!endif
SetDatablockOptimize on
SetDateSave off
AllowSkipFiles off

!include MUI2.nsh
!include LogicLib.nsh
!include FileFunc.nsh
!include x64.nsh

!ifndef PACKAGE_CONFIG
!error "Build using build-installer.ps1 so the payload is explicitly whitelisted."
!endif
!include "${PACKAGE_CONFIG}"

!define APP_ID "Unfair.Editor"
!define APP_KEY "Software\Unfair\Editor"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"
Name "Unfair ${APP_VERSION}"
OutFile "${OUTPUT_EXE}"
InstallDir "$LOCALAPPDATA\Programs\Unfair"
InstallDirRegKey HKCU "${APP_KEY}" "InstallLocation"
BrandingText "Unfair | Godot Engine contributors"
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "${APP_NUMERIC_VERSION}"
VIAddVersionKey /LANG=1033 "ProductName" "Unfair"
VIAddVersionKey /LANG=1033 "CompanyName" "Unfair contributors"
VIAddVersionKey /LANG=1033 "FileDescription" "Unfair per-user installer"
VIAddVersionKey /LANG=1033 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Godot Engine and Unfair contributors; see included licenses"
!define MUI_ICON "${INSTALLER_ICON}"
!define MUI_UNICON "${INSTALLER_ICON}"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "Install Unfair for your Windows account. No administrator access is required.$\r$\n$\r$\nThe editor, DLLs, loading artwork, AI tools and Python runtime are installed as ordinary visible files. Your projects and editor settings are preserved when uninstalling."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PACKAGE_STAGE}\LICENSE.txt"
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_DIRECTORYPAGE_TEXT_TOP "Choose a dedicated program folder. Projects and editor settings are kept separately."
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TEXT "Unfair has been installed.$\r$\n$\r$\nOpen the installation folder to view the EXE, DLLs, assets, AI tools and Uninstall.exe."
!define MUI_FINISHPAGE_RUN "$INSTDIR\Unfair.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Unfair"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchUnfair
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Open installation folder"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION OpenInstallFolder
!insertmacro MUI_PAGE_FINISH
!define MUI_UNCONFIRMPAGE_TEXT_TOP "Remove the installed Unfair program files and shortcuts. Projects, unknown files and AppData settings will be preserved. Close Unfair before continuing."
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "English"

Var PathError
Var PreviousInstall
Var TestMode
Var DesktopInstalled
Var SetupMutex
Var RawCommandLine
Var ExplicitDirectory

; Used by both setup and uninstall. No recursive directory deletion is used.
!macro DefineValidateDirectory PREFIX
Function ${PREFIX}ValidateDirectory
    StrCpy $PathError ""
    ${If} $INSTDIR == ""
        StrCpy $PathError "Choose a nonempty absolute installation folder."
        Return
    ${EndIf}
    StrCpy $0 $INSTDIR 1 1
    StrCpy $1 $INSTDIR 1 2
    ${If} $0 != ":"
    ${OrIf} $1 != "\"
        StrCpy $PathError "Choose an absolute local drive path, for example C:\Users\name\AppData\Local\Programs\Unfair."
        Return
    ${EndIf}
    ; NSIS GetFullPathName empties the output when the parent folder does not
    ; exist. Use Win32 canonicalization so a fresh installation path is valid.
    System::Call 'kernel32::GetFullPathNameW(w "$INSTDIR", i ${NSIS_MAX_STRLEN}, w .r2, p 0) i .r3'
    ${If} $3 == 0
    ${OrIf} $3 >= ${NSIS_MAX_STRLEN}
        StrCpy $PathError "The installation folder is invalid or too long."
        Return
    ${EndIf}
    StrCpy $INSTDIR $2
    ${GetRoot} "$INSTDIR" $0
    ${If} $INSTDIR == "$0\"
    ${OrIf} $INSTDIR == "$0"
    ${OrIf} $INSTDIR == "$PROFILE"
    ${OrIf} $INSTDIR == "$LOCALAPPDATA"
    ${OrIf} $INSTDIR == "$APPDATA"
    ${OrIf} $INSTDIR == "$DESKTOP"
    ${OrIf} $INSTDIR == "$DOCUMENTS"
    ${OrIf} $INSTDIR == "$WINDIR"
    ${OrIf} $INSTDIR == "$SYSDIR"
    ${OrIf} $INSTDIR == "$PROGRAMFILES"
    ${OrIf} $INSTDIR == "$PROGRAMFILES64"
        StrCpy $PathError "Use a dedicated subfolder. A drive root, user home or Windows special folder cannot be the installation directory."
        Return
    ${EndIf}
FunctionEnd
!macroend
!insertmacro DefineValidateDirectory ""
!insertmacro DefineValidateDirectory "un."

!macro DefineCheckClosed PREFIX
Function ${PREFIX}CheckClosed
    IfFileExists "$INSTDIR\Unfair.exe" 0 finished
    System::Call 'kernel32::CreateFileW(w "$INSTDIR\Unfair.exe", i 0x80000000, i 0, p 0, i 3, i 0, p 0) p.r0'
    ${If} $0 == -1
        MessageBox MB_OK|MB_ICONSTOP "Close Unfair in this installation folder before continuing. No processes will be stopped automatically." /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    System::Call 'kernel32::CloseHandle(p r0)'
finished:
FunctionEnd
!macroend
!insertmacro DefineCheckClosed ""
!insertmacro DefineCheckClosed "un."

Function .onInit
    SetShellVarContext current
    SetRegView 64
    ; NSIS discards an invalid /D= before callbacks and falls back to InstallDir.
    ; Read the original command line so an explicit root/empty/relative target
    ; is rejected rather than unexpectedly installing to the default folder.
    System::Call 'kernel32::GetCommandLineW() w .r0'
    StrCpy $RawCommandLine $0
    StrCpy $ExplicitDirectory 0
    ClearErrors
    ${GetOptions} "$RawCommandLine" "/D=" $1
    ${IfNot} ${Errors}
        StrCpy $ExplicitDirectory 1
        StrCpy $INSTDIR $1
        Call ValidateDirectory
        ${If} $PathError != ""
            MessageBox MB_OK|MB_ICONSTOP "$PathError" /SD IDOK
            SetErrorLevel 2
            Quit
        ${EndIf}
    ${EndIf}
    ${IfNot} ${RunningX64}
        MessageBox MB_OK|MB_ICONSTOP "This Unfair package requires 64-bit Windows." /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    System::Call 'kernel32::CreateMutexW(p 0, i 0, w "Local\Unfair.Editor.Setup") p .r0 ?e'
    Pop $1
    StrCpy $SetupMutex $0
    ${If} $1 == 183
        MessageBox MB_OK|MB_ICONSTOP "Another Unfair installation or uninstallation is already running." /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    StrCpy $TestMode 0
    StrCpy $DesktopInstalled 0
    ${GetOptions} "$RawCommandLine" "/TESTMODE=" $1
    ${If} $1 == "1"
        ; Scoped QA: install files only, without touching Start Menu, desktop or registry.
        StrCpy $TestMode 1
        StrCpy $PreviousInstall ""
        ${If} $ExplicitDirectory == 0
            MessageBox MB_OK|MB_ICONSTOP "Test mode requires an explicit dedicated /D= folder." /SD IDOK
            SetErrorLevel 2
            Quit
        ${EndIf}
    ${Else}
        ReadRegStr $PreviousInstall HKCU "${APP_KEY}" "InstallLocation"
    ${EndIf}
FunctionEnd

Function .onVerifyInstDir
    Call ValidateDirectory
    ${If} $PathError != ""
        Abort
    ${EndIf}
FunctionEnd

Function LaunchUnfair
    IfSilent done
    ExecShell "open" "$INSTDIR\Unfair.exe"
done:
FunctionEnd

Function OpenInstallFolder
    IfSilent done
    ExecShell "open" "$INSTDIR"
done:
FunctionEnd

Section "Unfair editor, assets and AI tools (required)" MainSection
    SectionIn RO
    Call ValidateDirectory
    ${If} $PathError != ""
        MessageBox MB_OK|MB_ICONSTOP "$PathError" /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    ${If} $PreviousInstall != ""
        GetFullPathName $0 "$PreviousInstall"
        ${If} $0 != $INSTDIR
            MessageBox MB_OK|MB_ICONSTOP "Unfair is already installed at $PreviousInstall. Upgrade in that folder, or uninstall it before choosing another location." /SD IDOK
            SetErrorLevel 2
            Quit
        ${EndIf}
    ${EndIf}
    IfFileExists "$INSTDIR\unfair-install.ini" existing_marker no_marker
existing_marker:
    ReadINIStr $0 "$INSTDIR\unfair-install.ini" "Unfair" "AppId"
    ${If} $0 != "${APP_ID}"
        MessageBox MB_OK|MB_ICONSTOP "The selected folder belongs to another installation. Choose a dedicated Unfair folder." /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    ReadINIStr $0 "$INSTDIR\unfair-install.ini" "Unfair" "TestMode"
    ${If} $0 != $TestMode
        MessageBox MB_OK|MB_ICONSTOP "Test-mode setup cannot replace a normal installation, and normal setup cannot replace a test installation. Choose a dedicated folder." /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    ReadINIStr $DesktopInstalled "$INSTDIR\unfair-install.ini" "Unfair" "DesktopShortcut"
    Goto checked_marker
no_marker:
    ; Do not claim or overwrite files in an unmanaged nonempty directory.
    IfFileExists "$INSTDIR\." 0 checked_marker
    ClearErrors
    FindFirst $0 $1 "$INSTDIR\*"
    IfErrors checked_marker
check_unmanaged_entry:
    ${If} $1 != "."
    ${AndIf} $1 != ".."
        FindClose $0
        Goto occupied
    ${EndIf}
    ClearErrors
    FindNext $0 $1
    IfErrors unmanaged_empty
    Goto check_unmanaged_entry
unmanaged_empty:
    FindClose $0
    Goto checked_marker
occupied:
    MessageBox MB_OK|MB_ICONSTOP "This folder is not empty and has no Unfair installation marker. Choose an empty dedicated folder so existing files cannot be overwritten." /SD IDOK
    SetErrorLevel 2
    Quit
checked_marker:
    Call CheckClosed
    ClearErrors
    SetOutPath "$INSTDIR"
    IfErrors install_failed
    !include "${PAYLOAD_INSTALL}"
    ClearErrors
    WriteUninstaller "$INSTDIR\Uninstall.exe"
    IfErrors install_failed
    WriteINIStr "$INSTDIR\unfair-install.ini" "Unfair" "AppId" "${APP_ID}"
    WriteINIStr "$INSTDIR\unfair-install.ini" "Unfair" "Version" "${APP_VERSION}"
    WriteINIStr "$INSTDIR\unfair-install.ini" "Unfair" "TestMode" "$TestMode"
    WriteINIStr "$INSTDIR\unfair-install.ini" "Unfair" "DesktopShortcut" "$DesktopInstalled"
    IfErrors install_failed
    ${If} $TestMode == 0
        CreateDirectory "$SMPROGRAMS\Unfair"
        CreateShortcut "$SMPROGRAMS\Unfair\Unfair.lnk" "$INSTDIR\Unfair.exe" "" "$INSTDIR\Unfair.exe"
        CreateShortcut "$SMPROGRAMS\Unfair\Installation folder.lnk" "$INSTDIR"
        CreateShortcut "$SMPROGRAMS\Unfair\Uninstall Unfair.lnk" "$INSTDIR\Uninstall.exe"
        WriteRegStr HKCU "${APP_KEY}" "InstallLocation" "$INSTDIR"
        WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Unfair"
        WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
        WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Unfair contributors"
        WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Unfair.exe,0"
        WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
        WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
        WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
        WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
        WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
        WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" ${PACKAGE_SIZE_KIB}
        IfErrors install_failed
    ${EndIf}
    SetErrorLevel 0
    Goto install_done
install_failed:
    MessageBox MB_OK|MB_ICONSTOP "Unfair could not be installed completely. Check free space, permissions and that the app is closed, then run setup again." /SD IDOK
    SetErrorLevel 2
    Quit
install_done:
SectionEnd

Section /o "Desktop shortcut" DesktopSection
    ${If} $TestMode == 0
        ClearErrors
        CreateShortcut "$DESKTOP\Unfair.lnk" "$INSTDIR\Unfair.exe" "" "$INSTDIR\Unfair.exe"
        ${If} ${Errors}
            SetErrorLevel 2
            Abort "Could not create the desktop shortcut."
        ${EndIf}
        WriteINIStr "$INSTDIR\unfair-install.ini" "Unfair" "DesktopShortcut" 1
    ${EndIf}
SectionEnd

Function un.onInit
    SetShellVarContext current
    SetRegView 64
    System::Call 'kernel32::CreateMutexW(p 0, i 0, w "Local\Unfair.Editor.Setup") p .r0 ?e'
    Pop $1
    StrCpy $SetupMutex $0
    ${If} $1 == 183
        SetErrorLevel 2
        Quit
    ${EndIf}
    Call un.ValidateDirectory
    ${If} $PathError != ""
        MessageBox MB_OK|MB_ICONSTOP "$PathError" /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    ReadINIStr $0 "$INSTDIR\unfair-install.ini" "Unfair" "AppId"
    ${If} $0 != "${APP_ID}"
        MessageBox MB_OK|MB_ICONSTOP "The Unfair installation marker is missing or invalid. No files will be removed." /SD IDOK
        SetErrorLevel 2
        Quit
    ${EndIf}
    ReadINIStr $TestMode "$INSTDIR\unfair-install.ini" "Unfair" "TestMode"
    ReadINIStr $DesktopInstalled "$INSTDIR\unfair-install.ini" "Unfair" "DesktopShortcut"
    Call un.CheckClosed
FunctionEnd

Section "Uninstall"
    ; Exact owned paths from the package manifest; never RMDir /r, wildcards or AppData.
    !include "${PAYLOAD_UNINSTALL}"
    ${If} $TestMode != 1
        Delete "$SMPROGRAMS\Unfair\Unfair.lnk"
        Delete "$SMPROGRAMS\Unfair\Installation folder.lnk"
        Delete "$SMPROGRAMS\Unfair\Uninstall Unfair.lnk"
        RMDir "$SMPROGRAMS\Unfair"
        ${If} $DesktopInstalled == 1
            Delete "$DESKTOP\Unfair.lnk"
        ${EndIf}
        ReadRegStr $0 HKCU "${APP_KEY}" "InstallLocation"
        ${If} $0 == $INSTDIR
            DeleteRegKey HKCU "${UNINSTALL_KEY}"
            DeleteRegValue HKCU "${APP_KEY}" "InstallLocation"
            DeleteRegKey /ifempty HKCU "${APP_KEY}"
        ${EndIf}
    ${EndIf}
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$INSTDIR\unfair-install.ini"
    SetOutPath "$TEMP"
    RMDir "$INSTDIR"
    SetErrorLevel 0
    Goto uninstall_done
uninstall_failed:
    MessageBox MB_OK|MB_ICONSTOP "Some Unfair program files could not be removed. Close programs using them and retry. Projects and settings have not been deleted." /SD IDOK
    SetErrorLevel 2
    Quit
uninstall_done:
SectionEnd
