# Unfair Engine

Unfair เป็น fork ของ Godot Engine ที่ปรับแบรนด์และ Editor UI พร้อม AI Assistance,
MCP tools และเครื่องมือสร้างตัวติดตั้ง Windows โดยยังใช้ GDScript และรูปแบบโปรเจกต์
ของ Godot ตามเดิม

## โครงสร้างโปรเจกต์

- [`Godot Engine/`](<Godot Engine/>) — engine source รวม Editor, platform,
  modules, third-party libraries, tests และสคริปต์ build
- [`Godot Engine/unfair/`](<Godot Engine/unfair/>) — งานออกแบบ, branding/loading
  assets, validation และสคริปต์ build/QA ของ Unfair
- [`Godot Engine/unfair/ai/`](<Godot Engine/unfair/ai/>) — native AI Assistance
  MCP companion และคู่มือการเชื่อมต่อแบบอ่านข้อมูล
- [`Godot Engine/unfair/mcp/`](<Godot Engine/unfair/mcp/>) — Unfair MCP ที่ดัดแปลง
  จาก Coding-Solo/godot-mcp พร้อม source, tools ติดตั้ง/ถอน/ตรวจ และ build ZIP
- [`Godot Engine/unfair/installer/`](<Godot Engine/unfair/installer/>) — NSIS
  installer/uninstaller source และการทดสอบ
- [`ai-workflow/`](ai-workflow/) — สกิลและเครื่องมือแบ่งงาน/บันทึกสถานะ AI
- [`WORK_STATUS.md`](WORK_STATUS.md) — ประวัติงานและหลักฐานการตรวจสอบ

## Build บน Windows

ต้องมี Visual Studio C++ build tools/Windows SDK, Python และ SCons ที่รองรับ
Godot source รุ่นนี้ ดูรายละเอียด upstream ใน
[`Godot Engine/README.md`](<Godot Engine/README.md>) และเอกสาร build ของ Godot

```powershell
Set-Location 'Godot Engine'
.\unfair\build-windows.ps1 -Python python -Jobs 8
```

โปรแกรมที่ build แล้วอยู่ใน `Godot Engine/bin/Unfair.exe` สคริปต์ installer ใช้
NSIS 3.13 และ Python embeddable runtime ตามคู่มือ
[`unfair/installer/README.md`](<Godot Engine/unfair/installer/README.md>)

Unfair MCP ใช้ TypeScript/Node; source และ lockfile อยู่ใน
`Godot Engine/unfair/mcp/server/` ดู
[`คู่มือ MCP`](<Godot Engine/unfair/mcp/README-th.md>) และ
[`packaging`](<Godot Engine/unfair/mcp/packaging/README.md>) ก่อน build/ติดตั้ง

Repository เก็บ source, assets และสคริปต์ที่จำเป็น ส่วน EXE/DLL ที่ build แล้ว,
toolchains, dependencies ที่ดาวน์โหลด, caches, QA exports และ connection config
ส่วนตัวถูกตัดออกด้วย `.gitignore` เอกสาร validation อ้างถึงผลทดสอบจากเครื่องพัฒนา;
path ของผลลัพธ์ที่ถูก ignore จะต้องสร้างใหม่เมื่อรัน QA

## เครดิตและสิทธิ์ใช้งาน

Unfair Engine พัฒนาต่อจาก [Godot Engine](https://github.com/godotengine/godot)
ภายใต้ MIT license โดยเก็บ [`LICENSE.txt`](<Godot Engine/LICENSE.txt>),
[`COPYRIGHT.txt`](<Godot Engine/COPYRIGHT.txt>),
[`AUTHORS.md`](<Godot Engine/AUTHORS.md>) และ notices ของ third-party ไว้

Unfair MCP พัฒนาจาก [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)
ภายใต้ MIT license เช่นกัน ดู
[`server/LICENSE`](<Godot Engine/unfair/mcp/server/LICENSE>) และ
[`server/UPSTREAM.md`](<Godot Engine/unfair/mcp/server/UPSTREAM.md>)
