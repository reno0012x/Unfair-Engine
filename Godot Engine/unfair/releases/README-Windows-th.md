# Unfair 4.8 Beta — Build 9 สำหรับ Windows x64

ดาวน์โหลดตัวติดตั้งและ MCP ZIP จาก [หน้า GitHub Release](https://github.com/reno0012x/Unfair-Engine/releases/tag/v4.8.0-beta-unfair.9)

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

คำสั่งแก้ Scene ทำงานกับไฟล์ที่บันทึกบนดิสก์และอยู่นอกประวัติ Undo ของ Editor ให้บันทึก Scene ก่อนสั่งแก้ และโหลดไฟล์ใหม่ใน Editor หลังคำสั่งเสร็จ ดูรายชื่อเครื่องมือและข้อจำกัด UID ใน `README-th.md` ภายใน MCP ZIP

## เชื่อม Google Antigravity และ AI client อื่น

Unfair MCP ใช้ `stdio` บน Windows จึงตั้งค่าได้กับ **Antigravity App, Antigravity IDE และ Antigravity CLI** ตามรูปแบบ MCP ของ Google ให้รันคำสั่งนี้จากโฟลเดอร์ MCP ZIP ที่แตกแล้ว เพื่อสร้าง `client-config.json` โดยไม่ต้องใช้ Codex CLI

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Client Json -UnfairPath (Join-Path $env:LOCALAPPDATA 'Programs\Unfair\Unfair.exe')
```

หากติดตั้ง Unfair ไว้ที่อื่น ให้ส่งพาธจริงของ `Unfair.exe` ใน `-UnfairPath` เปิด `client-config.json` จากตำแหน่งที่สคริปต์พิมพ์ออกมา แล้วคัดลอกเฉพาะรายการ `unfair-engine` พร้อม `command`, `args` และ `env` เข้าไปใน `mcpServers` ของไฟล์ตั้งค่าปลายทาง โดยเก็บรายการเดิมของคุณไว้

| โปรแกรม | เปิดการตั้งค่า MCP |
| --- | --- |
| Antigravity App | **Customizations → Installed → MCP Servers → Copy Config File Path** เปิดไฟล์ตามพาธที่ได้ |
| Antigravity IDE | ในแผง Agent เลือก **… → MCP Servers → Manage MCP Servers → View raw config** |
| Antigravity CLI | ใช้ `~/.gemini/config/mcp_config.json` สำหรับทุกโปรเจกต์ หรือ `.agents/mcp_config.json` สำหรับ workspace เดียว ใช้ `/mcp` เพื่อโหลด config ใหม่และดูสถานะ |

บันทึกไฟล์แล้วเปิด client ใหม่หรือรีสตาร์ต MCP จากเมนูที่มี จากนั้นลองสั่ง “ใช้ `unfair-engine` เรียก `get_engine_diagnostics` แล้วบอกเวอร์ชันและพาธ Unfair” ตรวจแล้วว่า config ที่ตัวติดตั้งสร้างสามารถเปิด MCP ผ่าน `stdio` และเรียกเครื่องมือนี้ได้บน Windows x64 ส่วนขั้นตอนใน Antigravity อ้างอิงจากเอกสารของ Google [เอกสาร MCP ของ Google Antigravity](https://antigravity.google/docs/mcp)

ใช้ `client-config.json` ชุดเดียวกันเป็นต้นทางได้สำหรับ client อื่นที่เปิดโปรเซส `stdio` บนเครื่องเดียวกับ Engine

- **Claude Desktop** รวมรายการใน `mcpServers` ของ `%APPDATA%\Claude\claude_desktop_config.json` แล้วปิดและเปิดแอปใหม่ ส่วน **Claude Code** รองรับ config โปรเจกต์ใน `.mcp.json` [คู่มือ Claude Code](https://code.claude.com/docs/en/mcp) · [คู่มือ Claude Desktop](https://py.sdk.modelcontextprotocol.io/get-started/real-host/)
- **Cursor** รวมรายการใน `mcpServers` ของ `.cursor/mcp.json` และระบุ `"type": "stdio"` หากแอปต้องการ [คู่มือ Cursor](https://cursor.com/docs/mcp)
- **VS Code / GitHub Copilot** เลือก **MCP Servers → Add Server** ในการตั้งค่า Agent แล้วนำ `command`, `args` และ `env` ไปใส่ในรายการชนิด `stdio` ตามรูปแบบของ VS Code [คู่มือ VS Code](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)
- **ChatGPT บนเว็บ** ใช้การเชื่อมต่อกับเซิร์ฟเวอร์ระยะไกล การตั้งค่า `stdio` ใน ZIP นี้ใช้กับ client บนเครื่อง [คู่มือ OpenAI](https://help.openai.com/en/articles/12584461)

### ใช้ MCP กับ Godot 4

กำหนด `env.UNFAIR_PATH` ให้เป็นพาธของ Godot 4 `.exe` ที่ต้องการใช้ ถ้าใช้ Unfair และ Godot ควบคู่กัน ให้เก็บรายการ `unfair-engine` ของ Unfair ไว้ แล้วเพิ่มสำเนาชื่อ `godot-engine` ที่ชี้ไป Godot ตรวจทั้งพาธและเวอร์ชันด้วย `get_engine_diagnostics` ก่อนสั่งรันหรือแก้โปรเจกต์ ชุดเครื่องมือผ่านการทดสอบกับ Unfair 4.8 ส่วนความเข้ากันได้กับ Godot ขึ้นกับเวอร์ชันและโปรเจกต์ โดยเครื่องมือ UID ต้องใช้ 4.4 ขึ้นไป

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
- หากเพิ่ม MCP เองผ่าน `-Client Json` ให้ลบรายการที่เพิ่มใน client ด้วย
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
