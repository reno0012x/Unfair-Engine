# Unfair MCP 1.0.0 — Windows x64

MCP server สำหรับควบคุม Unfair ผ่าน AI client พัฒนาต่อจาก [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) ภายใต้ MIT license เก็บเครดิตและ commit ที่ใช้ไว้ใน UPSTREAM.md

แพ็กเกจมี Node runtime และ dependencies พร้อมใช้ ไม่ต้องติดตั้ง Node/npm/Python เพิ่ม ต้องมี Unfair ที่รองรับ Godot 4 อยู่แล้ว และ AI client ที่รองรับ MCP stdio

## ติดตั้ง

แตก ZIP ไปยังโฟลเดอร์ปกติ เปิด PowerShell ในโฟลเดอร์นั้น แล้วรัน:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -UnfairPath 'C:\Users\YourName\AppData\Local\Programs\Unfair\Unfair.exe'
```

ค่าเริ่มต้นติดตั้งเฉพาะผู้ใช้ที่ `%LOCALAPPDATA%\Unfair\MCP\1.0.0-<release hash>` และเพิ่ม server ชื่อ `unfair-engine` ใน Codex ผ่าน `codex mcp add` ต้องมีคำสั่ง `codex` ใน PATH หรือระบุ `-CodexCommand 'C:\path\codex.exe'` โปรแกรมไม่ทับ MCP entry ที่เป็นของคนละการติดตั้ง

ใช้กับ Cursor, Claude Desktop หรือ client อื่น:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Client Json -UnfairPath 'C:\path\Unfair.exe'
```

นำ `mcpServers` จาก `client-config.json` ที่เครื่องมือติดตั้งแจ้ง ไปเพิ่มในการตั้งค่า MCP ของ client โดยรวมกับ server เดิม จากนั้นเปิดแชตใหม่หรือเริ่ม client ใหม่ ไม่ต้องเปิด server เองค้างไว้

## เครื่องมือ

เก็บชื่อเครื่องมือ upstream ทั้ง 14 รายการ: `launch_editor`, `run_project`, `get_debug_output`, `stop_project`, `get_godot_version`, `list_projects`, `get_project_info`, `create_scene`, `add_node`, `load_sprite`, `export_mesh_library`, `save_scene`, `get_uid`, `update_project_uids` รองรับชื่อพารามิเตอร์ camelCase และ snake_case เช่น `projectPath` / `project_path`

เพิ่ม `get_engine_diagnostics` เพื่อตรวจ executable/version และ `search_tools` เพื่อค้นหาสารบัญเครื่องมือแบบย่อ (ระบุ `includeSchemas: true` เมื่อต้องการ schema เต็ม) ใช้ `UNFAIR_PATH` ระบุ executable; `GODOT_PATH` ใช้เป็น compatibility fallback

ตัวอย่างคำสั่งให้ AI: “ใช้ Unfair MCP ตรวจเวอร์ชัน แล้วอ่านข้อมูลโปรเจกต์ที่ C:\Games\MyProject” หรือ “สร้าง scenes/player.tscn ที่มี Node2D แล้วเพิ่ม Sprite2D ชื่อ Sprite”

คำสั่งจัดการ Scene ใช้ Unfair แบบ headless กับไฟล์ที่บันทึกบนดิสก์ จึงควรบันทึก Scene ใน Editor ก่อน แล้วโหลดไฟล์ใหม่หลังแก้ผ่าน MCP คำสั่งเหล่านี้ไม่ได้อยู่ในประวัติ Undo ของ Editor ส่วน native AI Assistance read-only bridge ใช้ดู Scene/selection ที่เปิดอยู่และมี connection/activity ของมันเอง กิจกรรมของ MCP ชุดนี้ยังไม่ได้ส่งเข้า native Activity panel

การแก้ Scene รักษา root UID เดิม และอัปเดต external UID ของไฟล์ข้อความ `.tscn/.tres` จาก metadata จริง รองรับ UID ของ imported textures และสร้าง sidecar ที่ขาดให้ scripts/shaders เมื่อสั่ง `update_project_uids` เท่านั้น Binary `.res/.scn` แบบไม่บีบอัดรักษา root UID ได้ แต่ไม่ refresh external UID ภายใน binary; compressed binary UID editing ถูกปฏิเสธโดยเก็บไฟล์เดิมไว้ ใช้ Editor resave สำหรับกรณีดังกล่าว ผลคำสั่งระบุขอบเขตนี้ไว้ด้วย

เครื่องมือบางรายการเขียน Scene/Resource หรือเปิด/รันโปรเจกต์ตามคำสั่งของ AI มี annotations ให้ client แยกคำสั่งอ่าน/เขียน/รัน ไม่มีการตั้ง auto-approve เพิ่มให้ client

## ตรวจ / ถอน / อัปเกรด

ในโฟลเดอร์ติดตั้งจริง:

```powershell
powershell -ExecutionPolicy Bypass -File .\doctor.ps1
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Doctor ตรวจ hash ทุกไฟล์, Node runtime และ engine version ส่วน Uninstall ลบเฉพาะไฟล์แพ็กเกจที่ยังตรง hash และ MCP entry ที่ยังชี้มาที่การติดตั้งนี้ เก็บไฟล์อื่นและไฟล์ที่ถูกแก้ไว้ ไม่ลบโปรเจกต์เกม

แพ็กเกจใหม่ใช้โฟลเดอร์ตาม release hash ต่างกัน ให้ถอน MCP รุ่นเดิมก่อนแล้วติดตั้งแพ็กเกจใหม่ หรือใช้ `-ServerName` อีกชื่อเพื่อทดสอบคู่กัน ไฟล์ EXE/DLL/build/dependencies/tools แสดงเป็นไฟล์และโฟลเดอร์ปกติ

## ขอบเขตการตรวจสอบ

แพ็กเกจนี้สำหรับ Windows x64 ใช้ stdio ภายในเครื่อง ไม่ใช่ remote MCP service และไม่ใช่ตัวโมเดล AI เอง รายละเอียดผลทดสอบจริงอยู่ใน VALIDATION.md ของ source workspace; ไม่อ้างว่าทดสอบครบทุกโปรเจกต์ ทุก plugin ทุก client หรือทุกระบบปฏิบัติการ
