# Unfair สำหรับ Windows

เปิด `Unfair.exe` เพื่อเริ่มใช้งาน หรือใช้ shortcut ใน Start Menu

ไฟล์ในโฟลเดอร์นี้เป็นไฟล์โปรแกรมปกติที่เปิดดูได้:

- `Unfair.exe` — ตัว Editor และ Project Manager
- `Unfair.console.exe` — launcher สำหรับดู console/log
- `D3D12Core.dll` — Direct3D 12 runtime ที่ใช้กับโปรแกรม
- `assets/loading/` — ภาพพื้นหลังหน้า loading
- `unfair_ai/` — เครื่องมือ MCP แบบอ่านอย่างเดียว พร้อมคู่มือไทยและอังกฤษ
- `runtime/python/` — Python แบบแยกเฉพาะโปรแกรม ถ้ารวมในแพ็กนี้
- `licenses/`, `LICENSE.txt`, `COPYRIGHT.txt`, `AUTHORS.md` — ลิขสิทธิ์และเครดิตต้นทาง
- `installed-files.json` — รายการไฟล์และ SHA-256 ของแพ็ก
- `Uninstall.exe` — ถอนการติดตั้ง หรือถอนผ่าน Windows Installed apps

AI Hub ใน Editor จะเลือก Python ที่รวมไว้ให้โดยอัตโนมัติสำหรับการตั้งค่าใหม่
การต่อกับ MCP client ต้องเปิดโปรเจกต์และ Enable connection ตามคู่มือ
`unfair_ai/QUICKSTART-th.md` ไม่มี AI model หรือ API key รวมมาในแพ็ก

ข้อมูล Editor/settings เก็บใน AppData ตามพฤติกรรมปกติ ส่วนข้อมูลนำเข้าและ
connection config อยู่ในโฟลเดอร์ `.godot` ของแต่ละโปรเจกต์
ตัวติดตั้งไม่รวม `_sc_` หรือ `editor_data` จากเครื่องผู้พัฒนา

การถอนติดตั้งลบเฉพาะไฟล์โปรแกรมที่แพ็กนี้ติดตั้ง และ shortcut/registration
ที่เป็นของ Unfair ไม่ลบโปรเจกต์ ไฟล์อื่นที่คุณสร้าง หรือ settings ใน AppData
ควรเก็บโปรเจกต์แยกจากโฟลเดอร์โปรแกรมเพื่อให้อัปเดตได้สะดวก

ตัวติดตั้งนี้เป็น development/beta build; export templates ไม่ได้รวมอยู่ในแพ็ก
