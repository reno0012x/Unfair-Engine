# Unfair 4.8 Beta — Build 9 สำหรับ Windows x64

ล็อกอิน GitHub ด้วยบัญชีที่มีสิทธิ์เข้ารีโป Private แล้วดาวน์โหลดจาก [หน้า Release](https://github.com/reno0012x/Unfair-Engine/releases/tag/v4.8.0-beta-unfair.9)

## แบบติดตั้ง — แนะนำ

1. ดาวน์โหลด `install.exe` แล้วเปิดตัวติดตั้ง
2. เลือกโฟลเดอร์ ค่าเริ่มต้นคือ `%LOCALAPPDATA%\Programs\Unfair` โปรแกรมติดตั้งเฉพาะผู้ใช้และมี Python มาในแพ็กเกจ
3. เปิด Unfair จาก Start Menu → Unfair หรือ `Unfair.exe` ในโฟลเดอร์ติดตั้ง
4. Create/Open Project ได้ตามปกติ และใช้ GDScript ตามเดิม

EXE, DLL, assets, tools และ licenses เป็นไฟล์/โฟลเดอร์ปกติ มีตัวเลือกเปิดโฟลเดอร์
เมื่อจบการติดตั้ง และมี `Uninstall.exe` สำหรับถอนโปรแกรม
หากมี Unfair รุ่นเดิมเปิดอยู่ ให้บันทึกงานและปิดก่อนอัปเกรด

## แบบ Portable

1. ดาวน์โหลด `Unfair-4.8-beta-windows-x64-portable.zip`
2. แตก ZIP **ทั้งโฟลเดอร์** ไปยังโฟลเดอร์ที่เขียนไฟล์ได้ เช่น `D:\Tools\Unfair`
3. เปิด `Unfair.exe` ในโฟลเดอร์ที่แตกแล้ว อย่าเปิดจากข้างใน ZIP

เก็บ DLL, `assets`, `runtime`, `unfair_ai` และ licenses ไว้ข้าง EXE ตามโครงสร้างเดิม
Portable มี `_sc_` เพื่อเก็บ editor settings/cache ใน `editor_data` ข้างโปรแกรม
ตอนใช้งาน จึงไม่ควรวางในโฟลเดอร์ read-only หรือ Program Files
Portable ไม่ต้องใช้ Uninstall.exe; เก็บโปรเจกต์เกมและ settings ที่ต้องการก่อนลบ
โฟลเดอร์โปรแกรมด้วยตนเอง

## เชื่อม Unfair MCP กับ Codex

Unfair MCP มี 16 เครื่องมือสำหรับตรวจเวอร์ชัน อ่านข้อมูลโปรเจกต์ เปิดหรือรันโปรเจกต์ และจัดการ Scene ที่บันทึกแล้ว แพ็กเกจมี Node และ dependencies พร้อมใช้งาน

1. ติดตั้ง Unfair แล้วดาวน์โหลด `unfair-mcp-1.0.0-windows-x64.zip` จาก Release
2. แตก ZIP ทั้งโฟลเดอร์ และเปิด PowerShell ในโฟลเดอร์ที่มี `install.ps1`
3. ใช้คำสั่งด้านล่างสำหรับตำแหน่งติดตั้ง Unfair เริ่มต้น หากเลือกโฟลเดอร์อื่นหรือใช้ Portable ให้ส่งพาธเต็มของ `Unfair.exe` ใน `-UnfairPath`

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -UnfairPath (Join-Path $env:LOCALAPPDATA 'Programs\Unfair\Unfair.exe')
codex mcp list
```

เมื่อเห็น `unfair-engine` ในรายการ ให้ปิดและเปิด Codex ใหม่ แล้วสั่ง “ใช้ Unfair MCP เรียก `get_engine_diagnostics` เพื่อตรวจเวอร์ชัน” Codex จะเปิด MCP server ให้เองเมื่อใช้เครื่องมือ

หาก PowerShell หา `codex` ไม่เจอ ให้เพิ่ม `-CodexCommand 'C:\path\to\codex.exe'` ในคำสั่งติดตั้ง โดยใส่พาธจริงของ Codex CLI หากต้องการตรวจแพ็กเกจและพาธ Unfair ให้รัน `doctor.ps1` จากโฟลเดอร์ MCP ที่ตัวติดตั้งแจ้งไว้

สำหรับ AI client อื่นที่รองรับ MCP stdio ให้เพิ่ม `-Client Json` ในคำสั่งติดตั้ง นำรายการจาก `client-config.json` ที่ตัวติดตั้งแจ้งไปเพิ่มในค่า `mcpServers` ของ client แล้วเปิด client ใหม่

คำสั่งแก้ Scene ทำงานกับไฟล์ที่บันทึกบนดิสก์และอยู่นอกประวัติ Undo ของ Editor ให้บันทึก Scene ก่อนสั่งแก้ และโหลดไฟล์ใหม่ใน Editor หลังคำสั่งเสร็จ ดูรายชื่อเครื่องมือและข้อจำกัด UID ใน `README-th.md` ภายใน MCP ZIP

## เชื่อม AI Assistance เพื่ออ่านข้อมูลจาก Editor

1. เปิดโปรเจกต์ใน Unfair แล้วกด **AI Assist → Connect**
2. กด **Copy MCP config** แล้วเพิ่ม command และ args ที่คัดลอกไว้ในการตั้งค่า MCP ของ client หาก client ใช้ TOML ให้ใช้ค่า command และ args เดียวกันในรูปแบบ TOML
3. หลัง client เชื่อมสำเร็จ หน้าต่าง AI Assistance จะแสดง **Connected** และรายการเครื่องมือที่เรียกผ่านการเชื่อมต่อนี้

AI Assistance อ่าน Scene และ Node ที่กำลังเลือกใน Editor ได้ การเชื่อมต่อ `unfair-engine` ผ่าน ZIP ใช้ชุดเครื่องมือแยกและยังไม่ส่งประวัติไปที่หน้าต่าง AI Assistance

ถ้าใช้ Codex CLI ให้รันคำสั่งด้านล่างทันทีหลัง **Copy MCP config** คำสั่งจะอ่านค่าจากคลิปบอร์ดและลงทะเบียนแยกในชื่อ `unfair-live`

```powershell
$unfairLive = (Get-Clipboard -Raw | ConvertFrom-Json).mcpServers.unfair
$unfairLiveArgs = @($unfairLive.args)
codex mcp add unfair-live -- $unfairLive.command @unfairLiveArgs
```

เปิด Codex ใหม่และเปิดโปรเจกต์ใน Unfair ค้างไว้ระหว่างใช้งาน เมื่อเปิดการเชื่อมต่อใหม่ใน Editor แล้วพาธไฟล์เชื่อมต่อเปลี่ยน ให้กด **Copy MCP config** อีกครั้ง ใช้ `codex mcp remove unfair-live` แล้วลงทะเบียนใหม่ด้วยคำสั่งด้านบน เก็บค่าเชื่อมต่อไว้ในเครื่องของคุณ

## ถอนโปรแกรม

- แบบ installer: ใช้ Start Menu → Unfair → Uninstall หรือ `Uninstall.exe`
- MCP: ใช้ `uninstall.ps1` จากโฟลเดอร์ MCP ที่ติดตั้งจริง; `doctor.ps1` ใช้ตรวจไฟล์
- เก็บโปรเจกต์เกมไว้นอกโฟลเดอร์โปรแกรมเสมอ ไม่ต้องถอน/ลบโปรเจกต์เพื่ออัปเกรด

## ตรวจไฟล์

มี `SHA256SUMS.txt` ใน Release สำหรับเปรียบเทียบ:

```powershell
Get-FileHash .\install.exe -Algorithm SHA256
```

รุ่นนี้เป็น developer beta ที่ยังไม่ได้ code-sign ตรวจสอบบน Windows x64/OpenGL
ไม่รับรองทุก plugin, GPU/driver, DPI, export target หรือ OS

## เครดิต

Unfair พัฒนาต่อจาก Godot Engine ภายใต้ MIT; แพ็กเกจเก็บ LICENSE.txt,
COPYRIGHT.txt, AUTHORS.md และ notices ที่เกี่ยวข้องไว้ครบ
Unfair MCP พัฒนาจาก Coding-Solo/godot-mcp ภายใต้ MIT; มี LICENSE และ UPSTREAM.md
รวมถึง license ของ Node และ dependencies ในแพ็กเกจ
