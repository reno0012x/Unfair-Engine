[CmdletBinding()]
param(
    [string]$SourceManifest = (Join-Path $PSScriptRoot '..\installer\dist\installed-files.json'),
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '..\installer\build\package'),
    [string]$ExpectedEngineSha256 = 'f43eb7f01d345429a6c0801db0fb0e01d9574a27dd15957f5df8e79f1abb9f13'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskOutputDirectory = Join-Path $PSScriptRoot 'dist'
$taskArchiveRoot = 'Unfair-4.8-beta-windows-x64-portable'
$taskSourceRoot = (Get-Item -LiteralPath $SourceDirectory).FullName.TrimEnd('\')
$taskSourceManifestItem = Get-Item -LiteralPath $SourceManifest
$taskManifest = Get-Content -LiteralPath $taskSourceManifestItem.FullName -Raw | ConvertFrom-Json
if ($taskManifest.product -ne 'Unfair' -or $taskManifest.version -ne '4.8.0-beta' -or $taskManifest.architecture -ne 'x86_64' -or -not $taskManifest.bundled_python) { throw 'Expected the reviewed Windows x86_64 Unfair 4.8.0-beta package with bundled Python.' }
$taskSourceManifestHash = (Get-FileHash -LiteralPath $taskSourceManifestItem.FullName).Hash.ToLowerInvariant()
$taskStagedManifest = Join-Path $taskSourceRoot 'installed-files.json'
if ((Get-FileHash -LiteralPath $taskStagedManifest).Hash.ToLowerInvariant() -ne $taskSourceManifestHash) { throw 'Installer stage and distribution manifests differ; rebuild the installer stage first.' }
$taskEntries = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$taskAllowedRoot = @('Unfair.exe','Unfair.console.exe','D3D12Core.dll','LICENSE.txt','COPYRIGHT.txt','AUTHORS.md','README-th.md')

foreach ($taskFile in $taskManifest.files) {
    $taskPath = [string]$taskFile.path
    if ($taskPath -notmatch '^[A-Za-z0-9_./-]+$' -or [IO.Path]::IsPathRooted($taskPath) -or ($taskPath.Split('/') -contains '..') -or $taskFile.sha256 -cnotmatch '^[0-9a-f]{64}$') { throw "Unsafe manifest path or hash: $taskPath" }
    $taskAllowed = $taskPath -cin $taskAllowedRoot -or $taskPath -ceq 'assets/loading/unfair-loading-background.png' -or $taskPath -cin @('unfair_ai/unfair_mcp_bridge.py','unfair_ai/README.md','unfair_ai/QUICKSTART-th.md') -or $taskPath -cmatch '^licenses/[A-Za-z0-9_.-]+\.txt$' -or $taskPath -cmatch '^runtime/python/[A-Za-z0-9_.-]+\.(exe|dll|pyd|zip|_pth|cat|txt)$'
    if (-not $taskAllowed) { throw "Manifest entry is outside the portable whitelist: $taskPath" }
    $taskFilePath = Join-Path $taskSourceRoot $taskPath
    $taskItem = Get-Item -LiteralPath $taskFilePath -Force
    if ($taskItem.PSIsContainer -or ($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $taskItem.Length -ne $taskFile.bytes -or (Get-FileHash -LiteralPath $taskItem.FullName).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw "Source payload hash/size mismatch: $taskPath" }
    $taskEntries.Add($taskPath, [pscustomobject]@{ Path = $taskPath; Source = $taskItem.FullName; Bytes = $null; Size = $taskItem.Length; Sha256 = $taskFile.sha256 })
}
if (-not $taskEntries.ContainsKey('Unfair.exe') -or $taskEntries['Unfair.exe'].Sha256 -ne $ExpectedEngineSha256.ToLowerInvariant()) { throw 'The payload is not the expected final editor binary.' }
foreach ($taskRequired in @('Unfair.console.exe','D3D12Core.dll','LICENSE.txt','COPYRIGHT.txt','AUTHORS.md','runtime/python/python.exe','runtime/python/LICENSE.txt','unfair_ai/unfair_mcp_bridge.py','assets/loading/unfair-loading-background.png')) { if (-not $taskEntries.ContainsKey($taskRequired)) { throw "Missing required portable payload: $taskRequired" } }
$taskEntries.Add('installed-files.json', [pscustomobject]@{ Path = 'installed-files.json'; Source = $taskSourceManifestItem.FullName; Bytes = $null; Size = $taskSourceManifestItem.Length; Sha256 = $taskSourceManifestHash })

$taskUtf8 = [Text.UTF8Encoding]::new($false)
function Add-PortableText([string]$Path, [string]$Text) {
    $taskBytes = $taskUtf8.GetBytes($Text.Replace("`r`n", "`n"))
    $taskHasher = [Security.Cryptography.SHA256]::Create()
    try { $taskHash = [Convert]::ToHexString($taskHasher.ComputeHash($taskBytes)).ToLowerInvariant() } finally { $taskHasher.Dispose() }
    $taskEntries.Add($Path, [pscustomobject]@{ Path = $Path; Source = $null; Bytes = $taskBytes; Size = $taskBytes.Length; Sha256 = $taskHash })
}
$taskReadme = @'
# Unfair 4.8 beta — Windows x64 แบบ Portable

1. แตก ZIP ทั้งโฟลเดอร์ไปยังตำแหน่งที่บัญชีผู้ใช้เขียนไฟล์ได้
2. เปิด Unfair.exe จากโฟลเดอร์นั้น หรือ Unfair.console.exe เมื่อต้องการดู console
3. เก็บ EXE, DLLs, assets, runtime และ unfair_ai ไว้ด้วยกัน ไม่ต้องติดตั้งระบบ

ไฟล์ _sc_ ทำให้ Editor เก็บ settings และข้อมูลผู้ใช้ใน editor_data/ ข้างโปรแกรม
แทน AppData โฟลเดอร์ editor_data จะถูกสร้างเมื่อเริ่มใช้งาน แพ็กนี้ไม่มี settings,
connection tokens, โปรเจกต์ หรือข้อมูลส่วนตัวจากเครื่องผู้พัฒนารวมมาด้วย
อย่าแตกทับโฟลเดอร์ใช้งานเดิมโดยไม่สำรอง editor_data และโปรเจกต์ของคุณก่อน

Python ที่ runtime/python/ ใช้กับ AI Bridge ได้โดยไม่ต้องติดตั้ง Python แยก
อ่าน unfair_ai/QUICKSTART-th.md สำหรับการเปิด connection และตั้งค่า MCP client
แพ็กนี้ไม่มี AI model หรือ API key; เครื่องมือและ runtime เป็นไฟล์ปกติที่เปิดดูได้

ไฟล์ assets/loading/unfair-loading-background.png เป็นภาพหน้า loading
LICENSE.txt, COPYRIGHT.txt, AUTHORS.md, licenses/ และ runtime/python/LICENSE.txt
เก็บเครดิต Godot Engine, Unfair และองค์ประกอบที่นำมาใช้ตามต้นฉบับ

installed-files.json คือรายการ payload จาก installer ที่ใช้สร้างแพ็กนี้
portable-manifest.json เพิ่มรายการไฟล์ portable และ SHA-256 โดยไม่รวมตัวมันเอง
README-th.md เป็นคู่มือร่วมจากชุด installer; สำหรับ portable ให้ใช้คู่มือนี้ก่อน
ไม่มี Uninstall.exe หรือการลงทะเบียน Windows: เมื่อต้องการเลิกใช้ ให้สำรอง
editor_data และโปรเจกต์แล้วลบโฟลเดอร์โปรแกรมเอง

รุ่นนี้เป็น development/beta build สำหรับ Windows x64 ไม่รวม export templates
ผลตรวจ source/installer เดิมไม่ใช่คำรับรองว่าได้ทดสอบทุก plugin, DPI และ export
'@
Add-PortableText 'README-portable-th.md' ($taskReadme + "`n")
Add-PortableText '_sc_' ''
[string[]]$taskSortedPaths = @($taskEntries.Keys)
[Array]::Sort($taskSortedPaths, [StringComparer]::Ordinal)
$taskPortableManifest = [ordered]@{
    product = 'Unfair'; version = '4.8.0-beta'; platform = 'windows'; architecture = 'x86_64'; edition = 'portable-development-beta'
    engine_sha256 = $ExpectedEngineSha256.ToLowerInvariant(); source_manifest_sha256 = $taskSourceManifestHash; portable_settings = 'editor_data'; files = @(
        foreach ($taskPath in $taskSortedPaths) { $taskEntry = $taskEntries[$taskPath]; [ordered]@{ path = $taskPath; bytes = $taskEntry.Size; sha256 = $taskEntry.Sha256 } }
    )
}
Add-PortableText 'portable-manifest.json' (($taskPortableManifest | ConvertTo-Json -Depth 6) + "`n")
[string[]]$taskSortedPaths = @($taskEntries.Keys)
[Array]::Sort($taskSortedPaths, [StringComparer]::Ordinal)
[IO.Directory]::CreateDirectory($taskOutputDirectory) | Out-Null
$taskZipPath = Join-Path $taskOutputDirectory ($taskArchiveRoot + '.zip')
$taskPendingZip = Join-Path $taskOutputDirectory ($taskArchiveRoot + '.pending.zip')
Add-Type -AssemblyName System.IO.Compression
$taskOutputStream = [IO.File]::Create($taskPendingZip)
$taskArchive = [IO.Compression.ZipArchive]::new($taskOutputStream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($taskPath in $taskSortedPaths) {
        $taskPayload = $taskEntries[$taskPath]
        $taskZipEntry = $taskArchive.CreateEntry($taskArchiveRoot + '/' + $taskPath, [IO.Compression.CompressionLevel]::Optimal)
        $taskZipEntry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $taskZipEntry.ExternalAttributes = 0
        $taskEntryStream = $taskZipEntry.Open()
        try {
            if ($null -ne $taskPayload.Source) {
                $taskInputStream = [IO.File]::OpenRead($taskPayload.Source)
                try { $taskInputStream.CopyTo($taskEntryStream) } finally { $taskInputStream.Dispose() }
            } elseif ($taskPayload.Size -gt 0) { $taskEntryStream.Write($taskPayload.Bytes, 0, $taskPayload.Bytes.Length) }
        } finally { $taskEntryStream.Dispose() }
    }
} finally { $taskArchive.Dispose(); $taskOutputStream.Dispose() }

# Verify actual compressed entries, including the generated marker and Thai guide.
$taskZipInput = [IO.File]::OpenRead($taskPendingZip)
$taskReadArchive = [IO.Compression.ZipArchive]::new($taskZipInput, [IO.Compression.ZipArchiveMode]::Read)
try {
    if ($taskReadArchive.Entries.Count -ne $taskEntries.Count) { throw 'Portable ZIP file count differs from the explicit manifest.' }
    $taskSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($taskZipEntry in $taskReadArchive.Entries) {
        if (-not $taskZipEntry.FullName.StartsWith($taskArchiveRoot + '/', [StringComparison]::Ordinal)) { throw 'Unexpected ZIP root.' }
        $taskPath = $taskZipEntry.FullName.Substring($taskArchiveRoot.Length + 1)
        if (-not $taskSeen.Add($taskPath) -or -not $taskEntries.ContainsKey($taskPath)) { throw "Duplicate or unlisted ZIP entry: $taskPath" }
        $taskPayload = $taskEntries[$taskPath]
        if ($taskZipEntry.Length -ne $taskPayload.Size) { throw "ZIP size differs: $taskPath" }
        $taskInputStream = $taskZipEntry.Open()
        $taskHasher = [Security.Cryptography.SHA256]::Create()
        try { $taskHash = [Convert]::ToHexString($taskHasher.ComputeHash($taskInputStream)).ToLowerInvariant() } finally { $taskHasher.Dispose(); $taskInputStream.Dispose() }
        if ($taskHash -ne $taskPayload.Sha256) { throw "ZIP content hash differs: $taskPath" }
    }
} finally { $taskReadArchive.Dispose(); $taskZipInput.Dispose() }
Move-Item -LiteralPath $taskPendingZip -Destination $taskZipPath -Force
$taskZipHash = (Get-FileHash -LiteralPath $taskZipPath).Hash.ToLowerInvariant()
$taskBuildRecord = [ordered]@{
    product = 'Unfair'; version = '4.8.0-beta'; artifact = [IO.Path]::GetFileName($taskZipPath); sha256 = $taskZipHash
    bytes = (Get-Item -LiteralPath $taskZipPath).Length; files = $taskEntries.Count; payload_files = $taskManifest.files.Count
    source_manifest_sha256 = $taskSourceManifestHash; portable_manifest_sha256 = $taskEntries['portable-manifest.json'].Sha256
    engine_sha256 = $taskEntries['Unfair.exe'].Sha256; archive_root = $taskArchiveRoot; archive_hashes_verified = $true
    generated_files = @('_sc_', 'README-portable-th.md', 'portable-manifest.json'); portable_settings = 'editor_data'
}
[IO.File]::WriteAllText((Join-Path $taskOutputDirectory 'portable-build-record.json'), ($taskBuildRecord | ConvertTo-Json -Depth 5) + "`n", $taskUtf8)
Write-Output "Portable ZIP: $taskZipPath"
Write-Output "Verified $($taskEntries.Count) entries; editor SHA256 $($taskEntries['Unfair.exe'].Sha256)"
Write-Output "SHA256: $taskZipHash"
