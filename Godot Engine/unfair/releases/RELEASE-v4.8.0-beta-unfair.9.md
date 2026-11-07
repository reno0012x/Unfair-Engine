# Unfair 4.8 Beta — Build 9 (Windows x64)

แพ็กเกจพร้อมติดตั้ง/แตก ZIP แล้วเปิดใช้ **ไม่ต้อง build source เอง**

| ไฟล์ | ใช้สำหรับ |
| --- | --- |
| `install.exe` | Unfair พร้อม installer/uninstaller และ Python runtime |
| `Unfair-4.8-beta-windows-x64-portable.zip` | แตกทั้งโฟลเดอร์แล้วเปิด `Unfair.exe` พร้อม DLL/assets/tools |
| `unfair-mcp-1.0.0-windows-x64.zip` | MCP 16 tools พร้อม Node runtime และ Install/Uninstall/Doctor |
| `README-Windows-th.md` | คู่มือเริ่มใช้ทั้งสามแพ็กเกจ |
| `SHA256SUMS.txt` | Hash สำหรับตรวจไฟล์ดาวน์โหลด |

- ธีม Unfair ดำ/ขาว, branding/loading artwork และเครดิต Godot
- AI Assist → Content Browser → Undo/Redo อยู่แถวเดียวกัน ขนาดปุ่มสอดคล้องกัน
- AI Assistance แบบโค้งมน มี connection/activity status และ advanced settings พับได้
- หน้าต่าง tools แยกได้ และรักษาการใช้ GDScript ตามเดิม

ภาพโปรแกรมจริงอยู่ใน [README ของโปรเจกต์](https://github.com/reno0012x/Unfair-Engine#readme)

แบบ installer ให้เปิด `install.exe`; แบบ portable ต้องแตก ZIP ทั้งโฟลเดอร์ก่อน
เปิด `Unfair.exe` ZIP “Source code” ที่ GitHub สร้างให้อัตโนมัติเป็นซอร์ส ไม่ใช่
แพ็กเกจโปรแกรมพร้อมใช้

**Private repository:** ผู้ดาวน์โหลดต้องมีสิทธิ์เข้าถึงและล็อกอิน GitHub
รุ่นนี้เป็น unsigned developer beta สำหรับ Windows x64; ขอบเขตการทดสอบและข้อจำกัด
อยู่ในคู่มือและเอกสาร validation ไม่ใช่การรับรองทุก plugin/GPU/OS
