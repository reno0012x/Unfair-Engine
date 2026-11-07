# Unfair 4.8 Beta — Build 9 สำหรับ Windows x64

ดาวน์โหลดจาก https://github.com/reno0012x/Unfair-Engine/releases/tag/v4.8.0-beta-unfair.9
ต้องล็อกอิน GitHub ด้วยบัญชีที่มีสิทธิ์ในรีโป Private นี้

## แบบติดตั้ง — แนะนำ

1. ดาวน์โหลด `install.exe` แล้วเปิดตัวติดตั้ง
2. เลือกโฟลเดอร์ โปรแกรมติดตั้งเฉพาะผู้ใช้ ไม่ต้องติดตั้ง Python เพิ่ม
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

## AI Assistance และ Unfair MCP

AI Assistance ภายใน Editor เป็นหน้าสถานะและ live read-only bridge:
เปิด AI Assist → Connect → Copy MCP config แล้วเพิ่ม config ใน AI client
มันไม่ใช่โมเดล AI/chat provider ที่ฝังในโปรแกรม

แพ็กเกจ `unfair-mcp-1.0.0-windows-x64.zip` เป็น MCP tools อีกชุดสำหรับ AI client
มี 14 tools เดิมจาก godot-mcp และ 2 tools เพิ่ม พร้อม Node runtime ในแพ็กเกจ
แตก ZIP แล้วเปิด PowerShell ในโฟลเดอร์นั้น:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -UnfairPath 'D:\Tools\Unfair\Unfair.exe'
```

ค่าเริ่มต้นลงทะเบียนใน Codex ต้องมีคำสั่ง `codex` หรือระบุ `-CodexCommand`
ถ้าใช้ client อื่น เพิ่ม `-Client Json` แล้วนำ `client-config.json` ไปเพิ่มใน client
เปิดแชตใหม่หรือเริ่ม AI client ใหม่หลังติดตั้ง

MCP ชุด CLI แก้ไฟล์ที่บันทึกแล้วนอก Undo ของ Editor และกิจกรรมของมันยังแยกจาก
Activity ของ native AI Assistance ดู README-th.md ใน MCP ZIP สำหรับรายละเอียด
และข้อจำกัด UID ของ binary resources

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
