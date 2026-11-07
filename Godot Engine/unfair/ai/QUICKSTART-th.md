# ใช้ AI Assistance รุ่นแรก

AI Assistance เป็นหน้าสถานะและสารบัญเครื่องมือ ตัวโมเดล AI ทำงานใน MCP client ภายนอก ส่วน Unfair ให้ข้อมูลโปรเจกต์แบบอ่านอย่างเดียว

## เริ่มเชื่อมต่อ

1. เปิดโปรเจกต์ใน Unfair รุ่นใหม่ แล้วกด **AI Assist** บน header หรือ **Windows → AI Assistance**
2. กด **Enable connection** สถานะจะเป็น Ready จนกว่าจะมี client เชื่อมต่อจริง
3. ช่อง Python ใส่ `python` หรือ path ของ Python 3.10 ขึ้นไปที่ติดตั้งไว้ ตัว companion ไม่ต้องใช้ pip packages
4. กด **Copy MCP config** แล้วนำไปตั้งค่า MCP client ที่ใช้ ข้อมูลที่คัดลอกเป็นรูปแบบ `mcpServers` JSON; client บางตัวใช้รูปแบบ config ต่างกัน ให้ใช้ command และ args เดียวกันตามรูปแบบของ client นั้น
5. เมื่อ client ทำ MCP handshake สำเร็จ จะเห็นชื่อและสถานะ Connected ในตาราง จากนั้น AI เรียกใช้เครื่องมือได้

ไฟล์ companion อยู่ที่ `bin/unfair_ai/unfair_mcp_bridge.py` ต้องเก็บคู่กับโปรแกรม Config ที่ editor สร้างจะอยู่ใน `.godot/editor/unfair_ai/` ของโปรเจกต์ มีชื่อแยกตาม editor instance และลบเมื่อกดหยุดหรือออกจากโปรแกรมตามปกติ อย่านำเนื้อหาไฟล์ที่มี credential ไปโพสต์ในแชต

## เครื่องมือที่มี

| Tool | ข้อมูลที่ได้ |
| --- | --- |
| `project.overview` | ชื่อโปรเจกต์ เวอร์ชัน engine และ Scene ที่เปิด |
| `scene.inspect` | Node/path/type ของ Scene ที่กำลังแก้ พร้อมจำกัดจำนวน |
| `editor.selection` | Node ที่เลือกอยู่ใน Editor |
| `files.search` | ค้นจาก file index ของ Editor พร้อมจำกัดผลลัพธ์ |
| `files.read` | อ่านไฟล์ข้อความในโปรเจกต์เป็นช่วงบรรทัด สูงสุด 200 บรรทัดต่อคำขอ ไฟล์ไม่เกิน 64 KiB |
| `tools.search` | ค้นเครื่องมือตามชื่อ/หน้าที่ โดยเลือกไม่ส่ง schema ที่ยังไม่ต้องใช้ได้ |

ตัวอย่าง argument ของ `files.read`:

```json
{"path":"res://scripts/player.gd","start_line":1,"line_count":40}
```

ไม่มีเครื่องมือเขียนไฟล์ แก้ Scene รัน GDScript หรือรัน shell ในรุ่นนี้ เส้นทางนอกโปรเจกต์ ไฟล์ซ่อน/ชื่อที่เกี่ยวกับ secrets และ links/reparse points จะถูกปฏิเสธ แต่ระบบไม่อาจรู้ว่าไฟล์ชื่อทั่วไปมีข้อมูลลับอยู่หรือไม่

## อ่านสถานะ

- Connected หมายถึงเชื่อมต่อ transport อยู่ ไม่ได้หมายความว่า AI กำลังคิดหรือรันเครื่องมือตลอดเวลา
- Activity แสดงคำขอที่ผ่าน bridge นี้จริง พร้อม client, tool, file/node/ช่วงบรรทัด, ผลสำเร็จ/ข้อผิดพลาด และระยะเวลา
- ชื่อแอป/version มาจาก MCP client ส่วนชื่อ provider/model เป็นข้อมูลที่ client รายงาน ถ้าไม่ส่งจะขึ้น Not reported ระบบไม่ยืนยันว่าโมเดลเป็นตัวใดจากชื่อเพียงอย่างเดียว
- ไม่เห็นกิจกรรมที่ AI ทำผ่าน shell หรือเครื่องมืออื่นนอก bridge และไม่แสดงตัวเลข token/cost ที่ไม่ได้รับจาก provider
- Activity เก็บล่าสุดสูงสุด 200 รายการ กด **Export activity...** เพื่อเก็บ Markdown; ไม่มี credential หรือเนื้อหาไฟล์ที่อ่านใน activity log

จุดแดงหยุดและตัดทุก connection, จุดเหลืองพับ/ขยายเนื้อหา, จุดเขียวเปิดหน้าต่างแยก ปุ่มควบคุมหน้าต่างของ Windows ยังทำงานตามปกติ การปิดหน้าต่าง AI Assistance เพียงซ่อน UI; ใช้ Disconnect all หากต้องการหยุด bridge

## แนวทางต่อไป

ดู [IDEAS.md](IDEAS.md) สำหรับ Context packets, Scene Diff + Undo และ Checkpoints ส่วนหน้า Loading, การตัดมุมโค้งจริง และ installer/uninstaller ถูกจดไว้ทำภายหลังตามคำสั่งล่าสุด
