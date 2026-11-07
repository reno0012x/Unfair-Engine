# สถานะงาน

อัปเดต: 2569-11-07T10:04:22+07:00

## งาน SKILL-001: สร้างสกิลแบ่งงานและบันทึกความคืบหน้า

- เป้าหมาย: ให้ AI แบ่งงาน มอบหมายงานอิสระให้ sub-agent และบันทึกสิ่งที่ทำแล้วลง Markdown เพื่อทำต่อในแชตถัดไปได้
- สถานะรวม: Done
- การแบ่งงาน: main สร้างสกิล ตัวติดตั้ง กติกา และทดสอบ installer; sub-agent `review_workflow` ตรวจสกิลและ installer แบบอ่านอย่างเดียวและรายงานผลแล้ว

| ID | งาน / เงื่อนไขเสร็จ | ผู้รับผิดชอบ | สถานะ | ผลลัพธ์ / หลักฐาน |
| --- | --- | --- | --- | --- |
| SKILL-001.1 | สำรวจสกิลเดิมและแนวทาง Codex | main | Done | พบเฉพาะสกิลระบบ; อ่าน skill-creator และ OpenAI Docs |
| SKILL-001.2 | สร้างสกิล กติกา และสำเนากู้คืน | main | Done | ai-workflow/skills/parallel-work-log/, ai-workflow/global-AGENTS.md, ai-workflow/install.ps1, AGENTS.md |
| SKILL-001.3 | ตรวจสกิลและทดลองสถานการณ์ใช้งาน | main + review_workflow | Done | reviewer, PowerShell parser, installer scenarios, bundled skill validator และ YAML metadata ผ่าน |
| SKILL-001.4 | ติดตั้งระดับผู้ใช้และตรวจไฟล์ปลายทาง | main | Done | ติดตั้ง ~/.agents/skills/parallel-work-log และ ~/.codex/AGENTS.md แล้ว; hash ตรงกับต้นฉบับ; กติกาใหม่ถูกโหลดในแชตนี้แล้ว |

### สิ่งที่ทำแล้วและไฟล์ที่เกี่ยวข้อง

- สร้างสกิล `parallel-work-log` พร้อม metadata สำหรับเรียกใช้ตามงานและเรียกตรงด้วย `$parallel-work-log`
- กำหนดให้แบ่งงานจริง มอบหมาย sub-agent เมื่อมีงานอิสระ ให้ main รวมผลและดูแลไฟล์สถานะ
- กำหนดจุดบันทึกก่อนเริ่มงาน ระหว่างงาน หลังตรวจสอบ และก่อนจบ พร้อมหลักฐานและขั้นตอนถัดไป
- สร้าง `AGENTS.md` สำหรับ workspace นี้ และเตรียมกติกาส่วนตัวใน `ai-workflow/global-AGENTS.md`
- เก็บไฟล์ต้นฉบับและตัวติดตั้งใน `ai-workflow/` บนไดรฟ์ A: สำหรับติดตั้งกลับหลังลง Windows
- ติดตั้งสกิลจริงที่ `C:/Users/LEONIDASxII/.agents/skills/parallel-work-log/SKILL.md` และ metadata ที่ `agents/openai.yaml` ในโฟลเดอร์เดียวกัน
- ติดตั้งกติกาส่วนตัวที่ `C:/Users/LEONIDASxII/.codex/AGENTS.md` โดยชี้ path ของสกิลที่ติดตั้งจริง

### การตรวจสอบ

- ก่อนติดตั้ง: `~/.codex/skills` มีเฉพาะ `.system`; ไม่พบ `~/.codex/AGENTS.md` หรือ `AGENTS.override.md`
- เอกสาร [OpenAI Docs: Build skills](https://learn.chatgpt.com/docs/build-skills) ระบุตำแหน่งสกิลระดับผู้ใช้เป็น `~/.agents/skills`; [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) ระบุกติกาส่วนตัวที่ `~/.codex/AGENTS.md`
- PowerShell AST parser: ผ่าน
- ทดลอง installer ในโฟลเดอร์ชั่วคราว: ติดตั้งใหม่และเทียบ hash ผ่าน, เก็บกติกาเดิมพร้อม backup ผ่าน, ติดตั้งซ้ำไม่เพิ่ม block/backup ผ่าน, ปฏิเสธ skill ที่เนื้อหาต่างก่อนเปลี่ยนกติกาผ่าน, ตรวจ AGENTS.override.md ก่อนเขียนผ่าน, อัปเดตเฉพาะ managed block โดยเก็บข้อความรอบข้างผ่าน
- sub-agent `review_workflow`: ตรวจ workflow แบบงานสั้น งานคู่ขนาน ห้ามเขียนไฟล์ และทำต่อจากสถานะเดิม ไม่พบปัญหาขวางการใช้งานค่าเริ่มต้น; แนะนำให้กติกาชี้ path จริงเมื่อใช้ตำแหน่งติดตั้งพิเศษ ซึ่ง main แก้แล้ว
- bundled `quick_validate.py`: ผ่าน (`Skill is valid!`) หลังเตรียม PyYAML ในโฟลเดอร์ชั่วคราวและเรียก Python ด้วย `-X utf8` เพื่ออ่านภาษาไทยบน Windows
- `agents/openai.yaml`: parse ผ่าน; ชื่อสกิลใน default prompt, ความยาว short description และ implicit invocation ผ่าน
- หลังแก้ custom install path: กติกาชี้ไฟล์ปลายทางจริงผ่าน, ติดตั้งซ้ำไม่เปลี่ยนไฟล์ผ่าน, PowerShell parser ผ่าน
- ตรวจหลังติดตั้ง: SHA-256 ของ SKILL.md และ agents/openai.yaml ตรงกับต้นฉบับ; global AGENTS.md มี managed block เพียงชุดเดียวและชี้ path จริงถูกต้อง
- แชตนี้ได้รับกติกา global AGENTS.md ใหม่แล้วหลังติดตั้ง; ยังไม่ได้ทดสอบเริ่มแชตใหม่ในทุกโปรเจกต์

### งานค้าง / อุปสรรค / ขั้นตอนถัดไป

- งานนี้เสร็จแล้ว ไม่มีอุปสรรคค้าง
- งานโปรเจกต์ถัดไป: อ่านไฟล์นี้และใช้สกิล `parallel-work-log` เพื่อสร้าง task section ใหม่; อย่านำสถานะงานนี้ไปอ้างว่าแก้ซอร์ส Godot แล้ว
- เมื่อลง Windows ใหม่และยังมีชุดสำรองบน A: ให้เปิด PowerShell แล้วรัน `& 'A:\Game Engine\Godot Engine Remake\ai-workflow\install.ps1'` เพื่อติดตั้งสกิลและกติกากลับ; ตัวติดตั้งไม่ต้องใช้ Python หรือ PyYAML

### บันทึกความคืบหน้า

- 2026-11-06T17:42:28+07:00 — สำรวจสกิลเดิม อ่านแนวทาง และสร้างชุดสกิลพร้อมตัวติดตั้ง; ยังไม่ได้ติดตั้งส่วนตัว
- 2026-11-06T17:46:38+07:00 — sub-agent ตรวจทานเสร็จ; ทดสอบ installer ในพื้นที่ชั่วคราวผ่าน และแก้พร้อมตรวจ path สำหรับตำแหน่งติดตั้งพิเศษผ่านแล้ว
- 2026-11-06T18:12:07+07:00 — validator และ metadata ผ่าน; ติดตั้งระดับผู้ใช้สำเร็จ ตรวจ hash และ managed block แล้ว และพบว่ากติกาใหม่ถูกโหลดเข้ามาในแชตนี้

## งาน UNFAIR-001: Redesign Godot เป็น Unfair

- เป้าหมาย: เปลี่ยนแบรนด์และ UI ของ editor/project manager เป็น Unfair ธีมดำ–ขาว พร้อม interaction states โดยรักษา GDScript, project formats และระบบ engine เดิม
- สถานะรวม: Done
- การแบ่งงาน: main ดูแลโลโก้ เรฟ การรวมงานและตรวจ build; theme agent ดูแลธีม; branding agent ดูแลชื่อที่แสดง; interaction agent ดูแล transition/loading

| ID | งาน / เงื่อนไขเสร็จ | ผู้รับผิดชอบ | สถานะ | ผลลัพธ์ / หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-001.1 | สำรวจ UI และออกแบบธีม native | review_workflow | Done | Unfair preset/shared theme; native runtime QA ผ่านบน 4 renderer drivers |
| UNFAIR-001.2 | เปลี่ยนชื่อที่แสดง โดยรักษา API/format | unfair_branding | Done | ชื่อแสดงใน editor/Windows และ metadata macOS/Linux/Android; รักษา API/format/license |
| UNFAIR-001.3 | เพิ่ม transition/loading แบบไม่เปลี่ยนพฤติกรรม | unfair_motion | Done | progress transition 120ms, indeterminate loading, reduce motion |
| UNFAIR-001.4 | ค้นหาเรฟ เจนโลโก้ และเปลี่ยน asset ตอนเปิด | main | Done | เจน concept พร้อม native vector และ splash/icons หลายแพลตฟอร์ม |
| UNFAIR-001.5 | ตรวจ compatibility/build และบันทึกข้อจำกัดจริง | main | Done | final build + 1434 tests/425416 assertions + GDScript smoke + renderer startup/QA ผ่าน; มี VALIDATION.md |

### สิ่งที่ทำแล้วและไฟล์ที่เกี่ยวข้อง

- พบซอร์ส Godot 4.8 beta ใน Godot Engine/; โฟลเดอร์นี้ไม่มี .git
- เพิ่ม Unfair เป็น default native theme: พื้นผิวดำหลายระดับ ตัวอักษรขาว ขอบบาง hover/pressed/disabled/focus, tabs, inputs, trees, project rows, popup/dialogs; คงสีที่มีความหมาย เช่น error และแกน 3D
- เปลี่ยนชื่อแสดงและ metadata เป็น Unfair; GDScript, project.godot/.godot, identifiers ภายใน และเครดิต/ลิขสิทธิ์เดิมยังอยู่
- เพิ่ม progress panel transition 120ms, indeterminate loading และ reduce-motion setting
- ใช้ image_gen สร้างแนวคิดโลโก้ขาว แล้วสร้าง production vector/wordmark พร้อม PNG/ICO/ICNS/Android assets และ splash ตอนเปิด; อยู่ใน Godot Engine/unfair/branding/; prompt อยู่ใน PROMPT.md
- เรฟจาก Unreal/Unity/Stride และ design decisions อยู่ใน Godot Engine/unfair/DESIGN.md
- โปรแกรม Windows: Godot Engine/bin/Unfair.exe; CLI: Unfair.console.exe; เปิดจากโฟลเดอร์ bin เพื่อให้ใช้ DLL ที่อยู่ข้างกันได้
- เป็น developer build พร้อม tests; ใช้ portable editor settings ที่ bin/editor_data ผ่าน marker bin/_sc_
- source generator: Godot Engine/unfair/generate_brand_assets.py; build helper: unfair/build-windows.ps1; manifest/hash: unfair/build-manifest.json
- เก็บ executable พรีวิวเก่าที่ Windows ยัง lock ไว้เป็น bin/Unfair.previous-preview.exe; ไฟล์ส่งมอบตัวล่าสุดคือ Unfair.exe และเทียบ hash ตรงกับผล build แล้ว

### การตรวจสอบ

- final Windows x86_64 build รวม AccessKit, D3D12 และ ANGLE ผ่าน: unfair-build-final.log (6m33s); incremental หลังแก้ test ผ่าน: unfair-rebuild-final.log (22s)
- full native suite: 1434 ผ่าน, 0 ตก, 3 skipped; 425416 assertions ผ่านทั้งหมด (unfair-full-tests-final.log)
- GDScript typed arrays/lambda, native classes, Theme และ scene pack/save/load ผ่าน (unfair-smoke-final.log)
- Native Editor theme QA ผ่านแบบ headless และแบบ GUI; เปิดและ capture บน OpenGL, ANGLE/D3D11, Vulkan Forward+ และ D3D12 Forward+ บน RTX 3070 Ti ได้
- Native renderer logs: unfair-editor-visual.log, unfair-renderer-opengl3_angle.log, unfair-renderer-vulkan.log, unfair-renderer-d3d12.log
- ภาพ UI จริง: Godot Engine/unfair/smoke/unfair-editor.png; ผล QA: editor-qa-result.json; ตรวจภาพแล้ว
- แก้เฉพาะ test PCK size assumption ที่ผูกกับโลโก้เก่า ให้คำนวณจาก payload ที่เขียนจริงรวม PNG ก่อน override; ไม่เปลี่ยน runtime packer และไม่เพิ่ม padding ให้รูปเพื่อหลอก test
- ตรวจ SVG/alpha/splash/ICO และ cross-platform metadata parse ผ่าน; รายละเอียด/ข้อจำกัดอยู่ใน Godot Engine/unfair/VALIDATION.md

### งานค้าง / อุปสรรค / ขั้นตอนถัดไป

- งาน implementation และ Windows validation รอบนี้เสร็จแล้ว; เปิด Godot Engine/bin/Unfair.exe เพื่อใช้งาน
- ยังไม่ใช่คำรับรองว่าทุก workflow ใช้งานเหมือนเดิม 100%: ยังไม่ได้ทำ manual regression ทุกเมนู/plugin/DPI, ทดสอบ screen reader จริง, export ทุกแพลตฟอร์ม หรือ build macOS/Linux/Android; ไม่มี custom export templates รวมในชุดนี้
- งาน release ถัดไปหากต้องการ: ทดสอบโปรเจกต์จริงและ export pipelines, ทำ optimized release build และแพ็ก export templates ตามแพลตฟอร์มเป้าหมาย

### บันทึกความคืบหน้า
- 2026-11-06T18:46:52+07:00 — เริ่มงาน Unfair และสำรวจโครงสร้างซอร์ส

- 2026-11-06T18:53:19+07:00 — รวม theme/branding/loading และ production logo assets แล้ว; พบ MSVC/Windows SDK; build preflight ยังขาด AccessKit/D3D12 dependencies; เพิ่มเรฟและ acceptance gates ใน Godot Engine/unfair/DESIGN.md

- 2026-11-06T19:38:35+07:00 — ทำต่อหลังผู้ใช้สั่ง continue; independent review พบ loading fill contrast ต่ำ จึงเพิ่มเป็น .40 grayscale; ตรวจ SVG, alpha โลโก้ขาว, splash dimensions, multi-size ICO และชื่อ compatibility ผ่าน; เตรียม unfair/build-windows.ps1

- 2026-11-06T19:41:35+07:00 — ติดตั้ง AccessKit/D3D12 SDK และ zstandard สำเร็จ; คอมไพล์ Windows editor พร้อม tests แล้ว; เตรียม GDScript/scene/theme smoke project ที่ Godot Engine/unfair/smoke/

- 2026-11-06T19:48:00+07:00 — editor/theme/loading C++ คอมไพล์ผ่านเข้าส่วน core; อัปเดต metadata ชื่อแสดง macOS/Linux/Android อีก 6 ไฟล์และตรวจ parse/คง identifiers ผ่าน; เตรียม native EditorPlugin QA พร้อม screenshot ใน smoke project

- 2026-11-06T19:57:23+07:00 — build สำเร็จ (6m59s), Theme 4 เคส/466 assertions ผ่าน, GDScript save/load ผ่าน, native EditorPlugin QA ผ่านและเก็บภาพ unfair/smoke/unfair-editor.png แล้ว; full suite รอบแรก 1433/1434 ผ่าน โดย PCK size test ผูกขนาดโลโก้เดิม จึงแก้ให้เทียบ payload จริงและ rebuild ผ่าน; กำลังติดตั้ง ANGLE ก่อน final build เพื่อคง renderer fallback

- 2026-11-06T20:10:46+07:00 — final build รวม ANGLE ผ่าน (6m33s), แก้ test payload ให้รวม PNG ก่อน override และ incremental build ผ่าน; full suite 1434/1434 เคสและ 425416/425416 assertions ผ่าน (skip 3); GDScript ผ่าน; Editor QA/screenshot บน ANGLE และ Vulkan ผ่าน; Direct3D12 เริ่มได้แล้ว กำลังรอ UI QA เสร็จ
- 2026-11-06T20:11:33+07:00 — Direct3D12 Editor QA/capture ผ่าน; ตรวจภาพและ hash executable ตัวส่งมอบตรงกับ build แล้ว บันทึก manifest และข้อจำกัดครบ งานรอบนี้เสร็จ

## งาน UNFAIR-002: ออกแบบ workbench ใหม่จากภาพ feedback

- เป้าหมาย: titlebar ตามธีม, project manager/editor layout ที่อ่านง่ายและมีเอกลักษณ์, directory picker ใหม่, โลโก้ใหม่ตามรูปที่ 5, viewport 3D neutral และ detached windows ที่ค้นพบง่าย โดยรักษาคำสั่งและ GDScript เดิม
- สถานะรวม: Done
- การแบ่งงาน: titlebar agent, project-manager agent, file-dialog agent; main ดูแล workbench/viewport/โลโก้และการรวมทดสอบ

| ID | งาน / เงื่อนไขเสร็จ | ผู้รับผิดชอบ | สถานะ | หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-002.1 | Titlebar และ dialog chrome ตามธีม/active state | review_workflow + main QA | Done | DWM probe ยืนยัน main/folder dark=true/false; detached/PM dialogs inherit theme; exact RGB Win11 ยังไม่ได้ทดสอบ |
| UNFAIR-002.2 | Project manager/new-project hierarchy ใหม่ | unfair_branding + main QA | Done | PM/NewProject/Browse native QA ผ่านและตรวจภาพจริงแล้ว |
| UNFAIR-002.3 | Open a Directory: navigation/sidebar/actions ชัดเจน | unfair_motion + main QA | Done | 2-row navigation/sidebar/footer; ขนาดเหมาะสม; dir_selected ส่ง path ถูกต้อง |
| UNFAIR-002.4 | Editor command bar/layout/detached windows/viewport | main + unfair_motion | Done | command row/workspace tabsครบที่1600/1152px; Content Browserล่าง; neutral preview; Script detach/returnผ่าน |
| UNFAIR-002.5 | เจนโลโก้จากภาพ 5 ใช้กับ startup/icon | main | Done | image_gen จากภาพ 5; production vector คง diagonal cuts + Inter Bold wordmark; เปลี่ยน assets แล้ว |
| UNFAIR-002.6 | Build/regression/ตรวจภาพจริง | main | Done | buildผ่าน; full1434 cases/425416 assertionsผ่าน; GDScript/PM/Editor QAผ่าน; ส่งมอบUnfair.exeและmanifestv2แล้ว |

### สิ่งที่ทำแล้วและไฟล์ที่เกี่ยวข้อง

- อ่าน feedback ทั้ง 6 ภาพ: titlebar Windows ขาว, toolbar กระจาย/ไอคอนล้วน, directory picker เข้าใจยาก, ต้องการรูปทรง logo ภาพ 5, viewport ยังมี sky/ground สีน้ำตาลแบบเดิม
- ยอมรับว่ารอบก่อนเปลี่ยน palette มากกว่าโครง UI; รอบนี้ต้องแก้ composition และ workflow จริง
- เปลี่ยน PM เป็น navigation rail, search/sort และ New/Open actions; New Project เป็น details/rendering cards พร้อม form scroll
- Windows titlebar ส่งสีจาก Editor และ PM ผ่าน DisplayServerWindows ไปยังทุก native window และ dialog; รักษา High Contrast/native resizing/drag/Snap
- EditorFileDialog ใช้ editor-only opt-in layout; runtime FileDialog คง layout/shortcuts/filters/callbacks เดิม
- Workbench แยก application header กับ command row มี brand, Content Browser, workspace tabs, Play/Pause/Stop และ Windows menu
- Default workspace วาง Content Browser ด้านล่าง และ History รวม Inspector; โปรเจกต์เดิมเก็บ layout ไว้จนเลือก Windows → Reset to Unfair Workspace
- Windows menu เปิด Content/Scene/Inspector/Script/3D แยกและfocusหน้าต่างเดิมได้; เคารพ feature profile/multiwindow setting และขนาดหน้าต่างใช้งานได้
- 3D temporary preview เป็น charcoal studio; เปลี่ยนค่า sky/ground เก่าเฉพาะเมื่อเป็น default คู่เดิม รักษา scene environment/material/light และแกน RGB
- ปรับ stroke icons, primary/active/focus states, default font size; logo reference5 → image_gen → clean SVG พร้อม Inter Bold wordmark; new-project default icon เปลี่ยนเป็นUnfair แต่ไม่แก้ icon ของโปรเจกต์ผู้ใช้เดิม
- โปรแกรมส่งมอบ: Godot Engine/bin/Unfair.exe และ Unfair.console.exe; ไฟล์เดิมที่รันอยู่เก็บเป็น Unfair.before-workbench-v2.exe โดยไม่หยุดโปรแกรมผู้ใช้
- เอกสาร: Godot Engine/unfair/DESIGN-v2.md, VALIDATION-v2.md, build-manifest-v2.json; prompt/provenance: unfair/branding/PROMPT-v2.md

### การตรวจสอบ

- ผลทดสอบ UNFAIR-001 เป็น baseline เดิม ไม่ใช่ผลทดสอบรอบนี้
- ผลรอบนี้: unfair-v2-build.log buildผ่าน; unfair-v2-tests-final.log 1434ผ่าน/0ตก/3skip และ425416 assertionsผ่าน; unfair-v2-smoke-final.log GDScript/scene pack-save-loadผ่าน
- Native PM/NewProject/Folder: project-manager-qa-result.json pass=true; Editor/compact1152/Folder selection/Script detach&return/Light regeneration: workbench-qa-result.json pass=true
- DWM probe main editor/folder มี dark=true และfalse ตามธีมจริง; PM/new dialogs/Script inherit dark mode; เครื่องนี้ไม่รองรับ DWM exact caption RGB34–36 จึงยืนยันได้เฉพาะ dark/light
- ภาพจริงอยู่ Godot Engine/unfair/smoke/qa-output/unfair-v2-*.png; ตรวจ workbench, compact, light, NewProject, folder, detached Script แล้ว
- แก้ปัญหาที่พบจาก review/QA: nullcenter dereference, invisible primary focus, stale icon themes, floating-disabled/profile guard, clipped tabs, auto-wrapทำdialogสูง, settings notification ในQA, theme forwarding ที่เดิมเฉพาะAndroid
- SHA256 Unfair.exe ตรงกับผลbuild: 4BA02E743D187681EB5BBEDF8A6BF77057D87103D9B947A8E1F10033EDBAFA4D

### งานค้าง / ขั้นตอนถัดไป

- งานรอบนี้เสร็จแล้ว: ปิด Unfair รุ่นเก่าและเปิด Godot Engine/bin/Unfair.exe; โปรเจกต์เดิมใช้ Windows → Reset to Unfair Workspace หากต้องการ layout ใหม่
- ยังเป็น developer build; ไม่รับรองทุกworkflowเหมือนเดิม100%ก่อน manual regression โปรเจกต์จริง/ทุกplugin/DPI/language/exportplatform; Win11 exact caption colors และ OSอื่นยังต้องตรวจเพิ่มเติม
- คง GDScript/publicAPI/project.godot/.godot/license/credits เดิม; renderer regressionครอบคลุม4driversจากรอบก่อน ส่วนรอบนี้ visual QA ใช้OpenGL

### บันทึกความคืบหน้า
- 2026-11-06T20:23:38+07:00 — เริ่มรอบ redesign จากภาพ feedback

- 2026-11-06T20:35:36+07:00 — source redesign ทุกส่วนและ logo v2 พร้อมแล้ว; เริ่ม build รวม (unfair-v2-build.log); มอบหมาย review อิสระขณะรอ compile

- 2026-11-06T20:45:38+07:00 — ทำต่อหลัง continue; integration build ผ่านพร้อม review fixes (null center, primary focus contrast, icons refresh, multiwindow/feature-profile guard); เริ่ม native visual QA และ regression

- 2026-11-06T20:48:44+07:00 — ผู้ใช้สั่งทำต่อหลังหยุด Computer Use; main รับงาน integration/QA ที่เหลือ (agent reviews เสร็จแล้วและบาง agent ติด usage limit จึงไม่ spawn งานซ้ำ); เตรียม isolated workbench QA ตรวจ compact/dark/light/folder confirmation/detached script และ regression รอบใหม่


- 2026-11-06T20:54:13+07:00 — regression ใหม่1434/1434 และ425416 assertions ผ่าน; native PM/NewProject/Folder captures ได้แล้ว; พบ NewProject สูงเกินจึงจำกัดข้อความช่วยและแก้ auto-wrap; แก้ workspace tab max-width และ default layout Content Browser ด้านล่าง; ตรวจ DWM dark mode20=true บน dialog (Windows รุ่นนี้ไม่รองรับ exact caption RGB attributes); เริ่ม rebuild แก้ภาพจริง


- 2026-11-06T20:58:51+07:00 — PM/NewProject/Browse QA ผ่านหลังแก้ความสูง; folder confirmation และ detached script window ผ่าน; ภาพจริงพบ maximum_size=(0,0) จำกัด tabs จึงแก้เป็น(-1,-1); พบ EditorNode ส่ง window_set_color เฉพาะ Android จึงแก้ forwarding ทุก platform; default workspace เปลี่ยน Content Browser ล่าง/History รวม Inspector; รอ QA สุดท้าย dark/light และ compact


- 2026-11-06T21:02:41+07:00 — Workbench QA ผ่านพร้อมภาพ1600/1152px, folderยืนยันpathผ่าน, Script detached/ปิดกลับdockผ่าน; แก้tabsให้expandแล้วเห็น2D/3D/Script/Game/AssetStoreครบ; DWM probeยืนยันหน้าต่างหลักและFolderสลับ dark=true/false ได้จริง; PM/NewProject/Folder QA ผ่าน; กำลังรัน regressionสุดท้ายและอัปเดตไฟล์ส่งมอบ
- 2026-11-06T21:06:17+07:00 — regressionสุดท้าย1434cases/425416assertionsและGDScriptผ่าน; แก้QAให้ส่งsettings notificationตามUIจริงและLight regenerationผ่าน; ตรวจภาพLightและคืนUnfairแล้ว; ส่งมอบexe/hash/manifestและเอกสารv2ครบ งานเสร็จ


## งาน UNFAIR-003: เก็บ chrome, interaction และพื้นที่ viewport

- เป้าหมาย: ปุ่มminimize/maximize/closeชัดเจน, titlebarตามธีมตั้งแต่startup, centered workspace tabs, Content Browserพับได้/ไม่ซ้อนกินพื้นที่กับOutput, detached windowsครบ, transportมีสี, hover/activeเด่น, root-node chooserใหม่, splashให้เครดิตGodot
- สถานะรวม: Done
- การแบ่งงาน: mainดูแลcentered commandbar/content drawer/integration; delegate chrome/startup และ interaction/rootchooser; mainบันทึกสถานะและQA

| ID | งาน | ผู้รับผิดชอบ | สถานะ | หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-003.1 | Window controls/startup titlebar/detached polish | unfair_branding + main QA | Done | startup dark/native min-max-close state+rect ผ่าน; minimized restore/Return All ผ่าน |
| UNFAIR-003.2 | Hover/active/colored transport/root-node chooser | unfair_motion + main QA | Done | dark/light cards+glyphs; live run/pause/stop พร้อมสีและfocus ผ่าน |
| UNFAIR-003.3 | Center tabs + collapsible Content Browser + output coexistence | main | Done | center1600/compact1152, drawer toggle/Output exclusion และ Return All ผ่าน |
| UNFAIR-003.4 | Splash fork credit | main | Done | regenerate splash_editor.png และตรวจภาพเครดิตGodotแล้ว |
| UNFAIR-003.5 | Build/native regression/window-controls/content layout QA | main | Done | final build/full1434cases/425416assertions/GDScript/Editor/PM native QA ผ่าน |

### การตรวจสอบ

- รอบนี้ต้องตรวจcaption buttonsและfirst-frame ไม่ถือผลDWMรอบก่อนว่าเพียงพอ

### งานค้าง / ขั้นตอนถัดไป

- ส่งมอบ Godot Engine/bin/Unfair.exe แล้วและเปิด Project Manager รุ่นใหม่ไว้; โปรเจกต์เดิมใช้ Windows → Reset to Unfair Workspace เพื่อรับ drawer layout ใหม่ แล้วกด Ctrl+Space เพื่อเปิด/พับ Content Browser
- ข้อจำกัด: Computer Use capture native frame timeout2ครั้ง; ตรวจcaptionผ่านnative API/state/rectแทน จึงยังไม่ตรวจglyph pixelsด้วยhelper; exactWin11RGB/ทุกDPI/plugin/exportยังไม่ได้ทดสอบ

### บันทึกความคืบหน้า
- 2026-11-06T21:18:37+07:00 — เริ่มรอบเก็บงานจากภาพfeedback

- 2026-11-06T21:27:31.4407040+07:00 — รวม source จาก unfair_branding/unfair_motion และ main; เพิ่ม native QA สำหรับ center/drawer/Output/brand/transport/Return All; กำลังแก้ compile startup ก่อนทดสอบจริง

- 2026-11-06T21:34:38.0083519+07:00 — final build ผ่าน; native Editor QA ผ่าน center1600/compact1152, drawer toggle/Output mutual exclusion, minimize/maximize และคืน Script ที่minimized/Return All; caption probeยืนยันmin/max/close visible+available และ startup dark; full regression1434cases/425416assertionsผ่าน/3skip; กำลังตรวจtransportขณะrunจริงและPMสุดท้าย


### ไฟล์และผลส่งมอบ

- main: editor/editor_node.cpp/.h, editor/gui/unfair_command_bar.cpp/.h, editor/docks/editor_dock_manager.cpp/.h, editor/project_manager/project_manager.cpp, unfair/generate_brand_assets.py และmain/splash_editor.png
- agents: main/main.cpp, platform/windows/display_server_windows.cpp/.h, editor/gui/editor_title_bar.cpp/.h, editor/gui/window_wrapper.cpp, editor/themes/theme_modern.cpp, editor/run/editor_run_bar.cpp, editor/docks/scene_tree_dock.cpp/.h
- QA/docs: unfair/verify_titlebar.ps1, verify-workbench.ps1, unfair/smoke/addons/unfair_qa/*, project_manager_qa.gd, run_fixture.tscn, unfair/DESIGN-v3.md, VALIDATION-v3.md, build-manifest-v3.json
- final log: unfair-v3-build.log, unfair-v3-tests-final.log, unfair-v3-smoke-final.log, unfair-v3-editor-qa.log, unfair-v3-pm-qa.log; QA JSON pass=true ทั้งEditor/PM
- SHA256 Unfair.exe ตรงกับbuild: AA0BBAA4A6C59D8271F0932BF52303AE7B6AA511C71D2A388BC6A8B2AF125958; เก็บรุ่นก่อนเป็นUnfair.before-polish-v3.exe
- 2026-11-06T21:38:32.1833199+07:00 — final source/build/QA ส่งมอบครบ; native PM test harnessแก้Hidden startupด้วยmaximize/restoreแล้วผ่าน; delivered PM visibleและcaption probeผ่าน; เปิดรุ่นใหม่ให้ผู้ใช้แล้ว งานรอบนี้เสร็จ

## งาน UNFAIR-004: Navigation feedback, brand scale และ tool windows

- เป้าหมาย: PM hover/active ชัดพร้อมโลโก้ใหม่; Undo/Redo ข้างContent BrowserและขนาดFolderพอดี; brandใหญ่ขึ้น; ชื่อprojectอยู่ขวา; Output/Debugger/Audio/Animation/Shaderแยกwindow; Windows menuมีicons/separators
- สถานะรวม: Done
- การแบ่งงาน: unfair_branding ดูแลPM feedback/theme; unfair_motion ดูแลbottom tool detach; mainดูแลbrand assets/header/UndoRedo/Windows menu/integrationและQA

| ID | งาน / เงื่อนไขเสร็จ | เจ้าของ | สถานะ | หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-004.1 | PM navigation/list hover+active และbrand readable | unfair_branding → main | Done | nativePM hover/selected/About/Settings statesผ่าน; stockGodoticonแสดงUnfairและไฟล์ต้นฉบับhashเดิม |
| UNFAIR-004.2 | Bottom tools detach/redockได้และค้นพบง่าย | unfair_motion → main | Done | all5bottomtoolsเปิดแยก/ปิดกลับdockและOpeninWindowผ่าน |
| UNFAIR-004.3 | Brand/header right title + UndoRedo + menu icons/separators | main | Done | nativehistory undo/redo, logo36px, titleขวา, compact1152, Windowsicons+separatorsผ่าน |
| UNFAIR-004.4 | Build/QA/delivery | main | Done | final1434cases/425416assertions/GDScript/Editor/PMQAผ่าน; ส่งมอบexe/hash/manifestครบ |

### งานค้าง / ขั้นตอนถัดไป

- งานรอบนี้เสร็จ: ปิดUnfairรุ่นเดิมแล้วเปิด Godot Engine/bin/Unfair.exe; Undo/Redoอยู่ข้างContent Browser; Windowsมีbottom toolsครบ หรือเลือกtabแล้วกดOpen in Window

### บันทึกความคืบหน้า
- 2026-11-06T21:55:34.4768980+07:00 — เริ่มรอบจากfeedback6ภาพ


- 2026-11-06T22:47:19.0689733+07:00 — ทำต่อหลังผู้ใช้ส่งfeedbackเดิมซ้ำ; รักษาscopeเดิม พบสาเหตุPM flat modeและblueiconมาจากproject config; mainรับช่วงbottomtoolจากagentที่ติดusage limit

- 2026-11-06T22:53:34.5166286+07:00 — first v4 buildผ่าน; UndoRedo/all5toolwindows/header assertionsผ่าน เหลือQA popup screenshot/AcceptDialog close path; แก้QAให้กดOKจริงและรันGUIตามลำดับ; พบfloatingrectติดลบก่อนget_screenจึงsanitizeก่อนlookup; ทั้ง2agentติดusage limit mainรับงานที่เหลือ ไม่spawnซ้ำ

- 2026-11-06T22:58:58.3503180+07:00 — ตรวจภาพจริงแล้วแก้PM expand_iconที่บีบโลโก้หาย; compact barใช้Contentเมื่อแคบ; พบconstructor get_windowก่อนเข้าต้นไม้ทำstartup crash จึงใช้SceneTree rootที่มีอยู่; tests1434/425416ผ่านบนbuildก่อนfix; linkerชนไฟล์testที่รันอยู่ รอtestเสร็จแล้วrelink; ยังไม่ส่งมอบbuildนี้

- 2026-11-06T23:01:35.6667451+07:00 — Editor QAผ่านครบหลังfixstartup/compact: actualhistoryundo-redo/center/righttitle/16pxactions/menuicons/5toolwindows/nativecaption/dark-light; PM QAผ่านLibraryselected, logohover/Aboutactiveclear, Settingsactiveclear และstandardGodoticonแสดงUnfairจริง; ตรวจภาพจริงแล้ว กำลังเปลี่ยนmenuglyphOutput→Terminal/Outliner→Hierarchyแล้วbuildสุดท้าย

- 2026-11-06T23:04:49.3759152+07:00 — finalbuildพร้อมHierarchy/Terminalmenuiconsผ่าน; EditorQA/GDScriptผ่าน; ตรวจภาพmenu/compact/PMlogo&hoverและAudiofloatingแล้ว ไม่มีERRORในGUIlogsล่าสุด; รอfullnative regressionบนbinaryสุดท้าย


### สิ่งที่เปลี่ยนและผลตรวจสุดท้าย

- Source: editor/editor_node.cpp/.h, editor/project_manager/project_manager.cpp/.h, project_list.cpp, editor/themes/theme_modern.cpp, editor/gui/editor_bottom_panel.cpp/.h, editor/gui/window_wrapper.cpp, editor/icons/UnfairBrand.svg และunfair/generate_brand_assets.py
- QA: unfair/smoke/addons/unfair_qa/plugin.gd, workbench_qa.gd, unfair/smoke/project_manager_qa.gd, unfair/verify-workbench.ps1; nativecaptures unfair/smoke/qa-output/unfair-v4-*.png
- เอกสาร: unfair/DESIGN-v4.md, VALIDATION-v4.md, build-manifest-v4.json
- Final buildผ่าน; native1434ผ่าน/0ตก/3skip,425416assertionsผ่าน; GDScript/scene save-loadผ่าน; Editor/PMQA pass=true; GUIlogsสุดท้ายไม่มีERROR/SCRIPTERROR
- ตรวจUndoRedoจริงกับhistory, PMLibrary/hover/About/Settingsactive lifecycle, logo36px/toolbar16px/righttitle/compact1152, Windowsmenuicons+separators, all5bottomtoolsdetach-close-redock/OpeninWindow/ReturnAll, transportและdark/lightผ่าน
- icon.svgของprojectเดิมhashก่อน/หลังตรงกัน6C80384360A5B269D1054BFB27241258154E2CC8167C522016FDC1820E84E0F8; เปลี่ยนเฉพาะdisplayเมื่อเป็นstocktemplateตรงhash ไม่แก้project filesหรือcustomicons
- ส่งมอบUnfair.exe SHA256 EFE6C465D4CAE16D911C9479295C594D46DA20D60200499586F15BA0DA273563 ตรงกับbinaryที่build; สำรองรุ่นก่อนเป็นUnfair.before-navigation-v4.exeและconsoleคู่กัน โดยไม่หยุดprocessของผู้ใช้
- ข้อจำกัด: ยังไม่ได้manualทุกplugin/language/DPI/export/OS; exactWin11RGBไม่รองรับบนhost; ภาพเป็นviewport ส่วนnativecaptionตรวจด้วยAPI; stockiconรองรับhashtemplateที่ยืนยันแล้วเท่านั้น
- 2026-11-06T23:06:00.5284145+07:00 — finalregressionและUIQAผ่าน ส่งมอบไฟล์/manifest/docsครบ งานUNFAIR-004เสร็จ

## งาน UNFAIR-005: AI Assistance — MCP status และเครื่องมืออ่านข้อมูล

- เป้าหมาย: native AI Assistance dock/window ธีมเฉพาะโค้งมน macOS, connection/sessionจริง, live tool activityพร้อมfile/node/line/status, สารบัญcontextแบบประหยัดข้อมูล และMCPเชื่อมAIภายนอกได้
- ขอบเขตที่ผู้ใช้เลือก: รอบแรก read-only ไม่เพิ่มคำสั่งแก้Scene/ไฟล์
- สถานะรวม: Done
- สถาปัตยกรรม: external MCP stdio bridge → authenticated loopback editor bridge → bounded editor read tools; UIดูeventsจริง ไม่อ้างรู้modelหรือกิจกรรมนอกbridge; ไม่เพิ่มLLM/chatproviderภายใน
- การแบ่งงาน: backend/server+readtools, MCP companion+protocoltests, main UI/integration/QA; coordinatorดูแลlog

| ID | งาน / เงื่อนไขเสร็จ | เจ้าของ | สถานะ | หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-005.1 | Loopbackserver/session/events + bounded read-only context tools | unfair_branding + main | Done | native6tools/23cases, bounds/auth/JSONinteger/targetmetadataและprivateWindowsACLผ่าน |
| UNFAIR-005.2 | MCP stdio companion/catalog และprotocoltests | unfair_motion + main | Done | MCPcompanion11testsและnative23casesผ่าน; EOF/disconnect/recoveryผ่าน |
| UNFAIR-005.3 | Rounded AI Assistance UI + Windows integration + config handoff | main | Done | AI-only UI/dots, live sessions/activity, tool directory, copyconfig/exportMD/dark-lightผ่าน; trueclippingเป็นbacklog |
| UNFAIR-005.4 | Architecture/upgrade ideas/docs + native integration validation | main | Done | IDEAS/README/Thaiquickstart/VALIDATION; final1434cases+GDScript+workbenchQAผ่าน; ส่งมอบexeและcompanion |

### การตัดสินใจและข้อจำกัด

- ต่อAIผ่านMCPclientภายนอก; client name/version/modelถ้ามีเป็นข้อมูลที่clientรายงาน ไม่ใช่การตรวจสอบidentity/model
- แสดงเฉพาะกิจกรรมที่ผ่านbridge; connectionไม่เท่ากับกำลังทำงาน; ไม่มีtoken-costตัวเลขถ้าproviderไม่ส่งusage
- Tool outputsมีbounds/line ranges/truncation และread-only annotations; ไม่รัน arbitrary GDScript/shell หรือสแกนไฟล์นอกproject
- localhostonly, opt-in enable/stop, sessionsecretไม่ลงactivitylog, จำกัดconnections/messages/output; ไม่อ่านsecret foldersโดยdefault

### บันทึกความคืบหน้า
- 2026-11-07T00:10:22.4374759+07:00 — เริ่มงานหลังผู้ใช้เลือกสถานะและread-only tools; ตรวจGodot Editor/LSP/DAPและMCPspecแล้ว


- 2026-11-07T00:25:15.3416050+07:00 — mainUI/sourceintegrationและAI-onlyroundedappearanceพร้อม; backendตรวจschema/bounds/readonly/tokenredactionแล้ว; เพิ่มprotectedDACL configwriterและuniqueconnectionfilename; สร้างnativeUI+stdiointegrationQAเพื่อยืนยันสถานะจริง ยังไม่ถือsourceว่าผ่านnativeจนทดสอบ

- 2026-11-07T00:29:44.8484189+07:00 — AIUI compileผ่านและถ่ายภาพจริงได้; nativeQAพบJSONparseตัวเลขเป็นFLOATทำrequestid/schemaถูกปฏิเสธ จึงแก้validationเฉพาะfiniteintegralและเพิ่มfraction/boolnegativecases; แก้C++literalที่encodingผิด; configสร้างแบบatomicprotectedDACLแล้ว รอnativeยืนยัน; กำลังrebuild

- 2026-11-07T00:39:35.0906090+07:00 — ผู้ใช้ยืนยันทำUNFAIR-005 AI Assistanceให้เสร็จก่อน; จดbacklogภายหลัง: loadingassetพร้อมภาพเบลอเจนใหม่, มุมโค้งจริง, install.exe+uninstall+แสดงEXE/DLL/assets/toolsเป็นไฟล์ปกติและตัวเลือกเปิดโฟลเดอร์หลังติดตั้ง; ยังไม่ลงมือloading/installer และไม่เปลี่ยนscopeงานปัจจุบัน


- 2026-11-07T00:42:25.0097913+07:00 — AI native23cases/GUI/ACLผ่าน; พบfocusซ้ำระหว่างteardownในWindowWrapper จึงคืนfocusเฉพาะwindowที่เคยvisibleและไม่กำลังexit แล้วQAสะอาด; core1434cases/425416assertionsและGDScriptผ่าน, Editorworkbenchregressionผ่าน; เพิ่มexportQAuniqueชื่อเพื่อกันstale/overwriteconfirm แล้วกำลังยืนยันMDrecordsจริงก่อนส่งมอบ


### ผลส่งมอบและไฟล์ที่เปลี่ยน

- nativeใหม่: editor/ai/unfair_ai_bridge_server.cpp/.h, unfair_ai_assistance_dock.cpp/.h, unfair_ai_private_config.cpp/.h และSCsub; integration editor/SCsub, register_editor_types.cpp, editor_node.cpp/.h, editor/icons/UnfairAI.svg; WindowWrapper guard focusตอนhidden/exit
- companion/tests/docs: unfair/ai/unfair_mcp_bridge.py, test_mcp_bridge.py, test_native_bridge.py, README.md, QUICKSTART-th.md, IDEAS.md, VALIDATION.md; nativeQA unfair/verify-ai.ps1 และsmoke/addons/unfair_qa/ai_qa.gd/plugin.gd
- ส่งมอบ bin/Unfair.exe +Unfair.console.exe +bin/unfair_ai/{unfair_mcp_bridge.py,README.md,QUICKSTART-th.md}; สำรองรุ่นก่อน Unfair.before-ai-v1.exe และconsoleคู่กัน ไม่หยุดprocessผู้ใช้
- SHA256ตรงcompiledbinary ED510ADEDAAF1817DA0165DCBBA94D548154FF7F499CBCD2AFF7481504E7CCEE; manifest unfair/build-manifest-ai-v1.json
- ผลจริง: protocol11ผ่าน/nativeMCP23casesผ่าน; UIOffline/Ready/Connected/Disconnected/stop/dark-light/exportMDactualrecordsผ่าน; protectedDACLเฉพาะcurrentSID+SYSTEM/noinheritanceผ่าน; full1434/425416ผ่าน/3skip; GDScriptและworkbenchregressionผ่าน; finalAIGUIlogไม่มีERROR
- ข้อจำกัด: model/clientรายงานเอง; เห็นเฉพาะbridgecalls; ไม่มีmutationtools/LLMภายใน/token-savingsเปอร์เซ็นต์; Python3.10+แนะนำ; ไฟล์อ่าน64KiB/200lines; nonWindowsและทุกplugin/DPI/exportไม่ได้ตรวจครบ
- เริ่มใช้: ปิดโปรแกรมรุ่นเดิม เปิดbin/Unfair.exeแล้วAI Assist →Enable connection →Copy MCP config; ดูThaiquickstartสำหรับclientsetup
- 2026-11-07T00:45:07.5045247+07:00 — UNFAIR-005 functionalv1เสร็จและส่งมอบ; ทำตามคำสั่งล่าสุดคือยังไม่เริ่มLoading/installer

## งาน UNFAIR-006: Loading, true rounding และ installer

- สถานะ: Done — ผลส่งมอบและหลักฐานสุดท้ายอยู่ในหัวข้อผลส่งมอบ UNFAIR-006 ด้านล่าง
- จดไว้: หน้าloadingproject/assetแบบมีgeneratedblurredbackground, ตัดมุมโค้งจริงไม่ใช่แค่border, install.exe+uninstaller, แสดงEXE/DLL/assets/toolsเป็นไฟล์ปกติไม่ซ่อน และตัวเลือกเปิดโฟลเดอร์เมื่อติดตั้งเสร็จ
- รอบนี้อ่านข้อมูลเบื้องต้นเท่านั้น ยังไม่เจนloadingimage/เปลี่ยนloading/สร้างinstaller


### แผนดำเนินงานที่ได้รับอนุญาต

| ID | งาน / เงื่อนไขเสร็จ | เจ้าของ | สถานะ | หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-006.1 | Project/asset loading presentation พร้อมgeneratedblurredbackgroundและprogressจริง | unfair_branding | Done | installed/embedded startup+scan+reimport+Cancel ผ่าน |
| UNFAIR-006.2 | AI roundedmaskตัดเนื้อหา/พื้นหลังจริงพร้อมnativewindowfallback | unfair_motion + main | Done | geometry/real clicks/alpha+Win32region ผ่าน |
| UNFAIR-006.3 | install.exe+uninstallerและvisiblefiletree/shortcuts/openfolder | review_workflow + main | Done | final install/upgrade/uninstall/hash + HKCU/shortcuts ผ่าน |
| UNFAIR-006.4 | Mainเจนasset/integration/build/visualQA/install-uninstallQA | main | Done | ส่งมอบEXE/installer พร้อม VALIDATION-v6.md |

- 2026-11-07T00:46:20.6189814+07:00 — ผู้ใช้สั่งทำต่อ; ใช้imagegenสำหรับloadingartworkใหม่ และparallel-work-logแบ่งงานจริง; installerลงแบบper-userและไม่ลบproject/userdataตอนuninstall; packageไม่รวมsource/obj/backupexe/editor_data

- 2026-11-07T00:56:02.4599642+07:00 — ผู้ใช้เพิ่มUIล้นจอกดปุ่มไม่ได้: rootcausewrap_controlsขยายหลังclamp; sourceเปลี่ยนfixedcontrols+scrollbodyและclampouterframeแล้ว; image_genสร้างartใหม่และcopyเข้workspace/embeddedbuilder; Python3.14.10embeddableตรวจofficialSHA256+PSFsignaturesผ่านสำหรับbundle; เริ่มbuildรวม

- 2026-11-07T01:12:23.2798978+07:00 — แก้startupcrashจากการreparentซ้ำระหว่างENTER_TREEโดยdeferงานwindowจนPOST_ENTER_TREE; buildรวมผ่านแล้ว ขนาดinitial/640x480/oversized recoveryและalpha cornerผ่านขั้นแรก แต่real-clickQAยังเปิดbridgeไม่ได้ กำลังแยกinputbugก่อนส่งมอบ; installerแก้canonicalpathของfolderใหม่และตรวจcollisionแล้ว isolatedinstall/upgrade/uninstallผ่านพร้อมเก็บuserfiles


## งาน UNFAIR-007: แปลง Coding-Solo/godot-mcp เป็น Unfair MCP พร้อมแจกและติดตั้ง

- สถานะ: Done — แพ็กเกจทดสอบผ่านและติดตั้งให้ผู้ใช้แล้ว
- เป้าหมาย: รักษาเครื่องมือupstreamที่เข้ากันได้ เพิ่มUnfair detection/diagnostics/installation tools ทำแพ็กเกจพร้อมติดตั้งผู้ใช้และclient
- แบ่งงาน: mainตรวจupstream/แปลงserver+integration+installer; unfair_motionตรวจarchitectureหลังแก้footer; unfair_brandingทำloadingQAของ006; review_workflowทำinstallerQA006 (agentติดusage limit จึงmainรับช่วง)
- 2026-11-07T07:17:40.9537186+07:00 — เริ่มตามคำสั่งใหม่หลัง006ยังค้างส่งมอบ; AI006 real-click/nativeMCP23/region/ACLผ่านแล้ว; ต้องตรวจupstreamก่อนอ้าง100%compatibility และติดตั้งCodexแบบรักษาconfigเดิม


- 2026-11-07T07:29:55.1309221+07:00 — UNFAIR006 nativeAIrealclick/MCP23/ACL/alpha+Win32regionผ่าน; footerlabelแก้แล้ว, loadinginstalled+embeddedจริงผ่านstartup0..4/5/reimport/scan/cancelและแก้firstcardสูงเกินจอ; core1434/425416และGDScriptsmokeผ่าน; workbenchWindows/transport/darklightผ่าน; ส่งมอบUnfair.exeใหม่ตรงcompiledและกำลังbuildinstall.exeLZMA
- 2026-11-07T07:29:55.1309221+07:00 — UNFAIR007 source16toolsbuildผ่าน รักษา14upstreamtools+เพิ่มdiagnostics/search; testจริงพบUIDtextureต้องใช้ResourceLoaderและupdate_project_uidsใช้absolutepathผิด จึงแก้ทั้งสองก่อนfinalQA; เครื่องมือติดตั้ง/ถอน/doctorและZIPbundleNodeเตรียมแล้ว ยังไม่ลงclientจนตรวจแพ็กเกจผ่าน


### ผลส่งมอบ UNFAIR-006 — Done

- 2026-11-07T07:37:05.4677203+07:00 — ส่งมอบbin/Unfair.exe SHA2564cfa0382be31960db26cce579a7d5957871417406c20aebcc6ac9734d9fd3d49; backupก่อนหน้าเก็บครบ; install.exe LZMA55files SHA256cc22f744dee19853cd2fbae4f8d27a9a8e43e7142a28d33a1bd7a0fd41c7e761; finalinstall/upgrade/uninstallผ่าน พร้อมnormalHKCU/4shortcutsQAcleanupโดยไม่แตะproduction
- installedappจริงไม่มีportablemarkerผ่านAIUI/MCP23ด้วยbundledPythonและถอนQAเสร็จ; Loadingfinalinstalled/embedded10ภาพnonblankจริงต่อcase ผ่านstartup/scan/reimport/nativeCancel ไม่มีERROR/SCRIPTERROR มีwindowhoverwarningเดิม; UIviewport668x342/352 ไม่ล้น
- Native1434/425416ผ่าน, GDScriptsmokeและworkspaceRegressionผ่าน; เอกสารunfair/VALIDATION-v6.md +build-manifest-v6.json; งาน006ครบ ขั้นต่อไปทำ007MCPpackageให้ผ่านUIDcorrectnessและติดตั้งclient


### ผลส่งมอบ UNFAIR-007 — Done

- 2026-11-07T07:58:38.5412957+07:00 — ปรับforkจากCoding-Solo/godot-mcp commit1209744fad78f3998f98c7394fd0f6ef50da5281 รักษาMIT/14toolsและเพิ่มget_engine_diagnostics+search_toolsรวม16; แก้UIDmetadataบนheadlessให้รักษาrootUIDเดิม/refreshtextreference/สร้างmissingGDsidecarจริง; binaryexternalUIDrefreshยังไม่รองรับและcompressedbinaryปฏิเสธแบบเก็บresourceเดิม ตามคู่มือ
- FinalZIPWindowsx64มี606files/hashmanifest+Node24.22.1/DLL/license/productiondeps ไม่ต้องลงNode/npmเพิ่ม; ZIP38,464,566bytes SHA256e411e8d27b023e963a1a75e6d30b1eba78e7989bb27282d988fe2b0b24583dc6; source+toolsอยู่Godot Engine/unfair/mcp; agentpackagingติดusage limitจึงmainรับช่วงbuild/QA/ติดตั้งจนจบ
- package-native-mcp.jsonpass=true: ทั้ง14legacy+2addedtoolsกับUnfair.exeจริง, UIDrootคงอยู่หลังadd/load/save/update, textureUIDถูกต้อง, traversalinvalidtype/unknownreject, log1500lines/128KiB, stdinEOFปิดownedrunprocessผ่าน
- install/uninstall/doctorPS1ผ่านisolatedCodexconfig/reinstall/hash/managedcollision/เก็บmodifiedfile+nestedproject/pristineuninstall; finalpackagetรวจsortedmanifest+ZIPทุกentryผ่าน
- ติดตั้งผู้ใช้จริงที่C:/Users/LEONIDASxII/AppData/Local/Unfair/MCP/1.0.0-8f5a1d9aaa7b และลงCodexserverunfair-engineพร้อมUNFAIR_PATHชี้bin/Unfair.exe; สำรองconfigข้างต้นฉบับ; configเดิมsemanticเหมือนเดิม/ยังมีnode_repl (CLIomitdefaultargs=[]เท่านั้น); actualinstalledinitialize/list16/diagnostics/Doctorallhashผ่าน ตามqa-output/user-install-verification.json
- เอกสารunfair/mcp/README-th.md และVALIDATION.mdระบุsaved-fileoperationsนอกUndoและยังไม่ส่งActivityไปnativeAIpanel; ยังไม่ได้publishGitHub/npm/marketplace และไม่รับรองทุกplugin/OS; ไม่มีงานค้างที่ต้องทำก่อนใช้งาน — เปิดCodexchatใหม่หรือrestartclientเพื่อโหลด16tools


## งาน UNFAIR-008: จัดตำแหน่ง AI Assist และเก็บงานหน้าต่าง AI

- สถานะ: Done — ส่งมอบ EXE และ installer ใหม่พร้อมผลตรวจ
- เป้าหมาย: ปุ่มAI Assistอยู่ก่อนContent Browser→Undo→Redoในแถบเดียวกัน และหน้าต่างAIไม่มีกรอบclassicซ้อน/โค้งเพี้ยน จัดองค์ประกอบให้อ่านง่ายโดยbridgeเดิมครบ
- ใช้parallel-work-log; mainรับheader/nativeframe/integrationQA/buildส่งมอบ; unfair_brandingรับAIpanel cpp/h; unfair_motionตรวจสาเหตุnativeframeแบบread-only (หากติดquota mainรับช่วงตามไฟล์ที่แยกไว้)
- เงื่อนไขเสร็จ: nativecapturesขนาดปกติ/compact/darklight, ปุ่มtoolbarไม่เบียดcenter/workspace, windowcaption/controlsใช้ได้, MCP23และworkspaceQAผ่าน, อัปเดตEXE+installer
- 2026-11-07T09:27:25.3092224+07:00 — อ่านภาพและsourceแล้ว พบAIbuttonอยู่title_barและnativecornerใช้SetWindowRgnร่วมtransparentflag กำลังแก้ตำแหน่งพร้อมแยกสาเหตุclassiccaptionก่อนเลือกวิธีrounding


- 2026-11-07T09:42:29.1755468+07:00 — UNFAIR008 sourceย้ายAIbuttonเข้าแถวContentก่อนUndo/Redoแล้ว; themeicon+activeตามdockจริง; UIใหม่พับPythonsettings, honestemptyStates, primaryConnect, footerแถวเดียว; wrapperAIใช้opaqueHWND+ไม่มีcustomregionและDWMNCenabledป้องกันclassicframe; actualnativePrintWindowตรวจปุ่มmin/max/close+dark/lightและchildclipด้วยpolygonผ่าน
- Native1434/425416+GDScriptsmokeผ่าน; AI23MCP/ACL/initial640x480/oversize/reopen/advancedGUIhit-testผ่านรอบlayoutใหม่; workbenchพบtoolbarเกินที่1152จึงปรับWindowsmenuเป็นicon-onlyพร้อมtooltipเฉพาะcompact แล้วกำลังrebuild/verifyก่อนส่งมอบ; QAเลิกพึ่งOSpointerเพื่อไม่แย่งfocusจากแอปผู้ใช้ ใช้viewporttouchpress/releasehit-testingแทน


- 2026-11-07T09:45:01.2595015+07:00 — finalAIUIQA pass=true: toolbarorder+active, 640x480/offscreenrecovery, advancedfold, emptyStates, actualchildclip(polygonpixeltest), nativeGetWindowRgn=0+DWMNCenabled=1 และmin/max/closeavailableพร้อมdark/lightstate; MCP23/ACLผ่าน ไม่มีERROR; finalworkspaceQA1152/1600/UndoRedo/detach/transport/darklightผ่านหลังcompactWindowslabelลดเป็นicon; ส่งมอบUnfair.exeตรงcompiled+backupbefore-ai-ui-v8แล้ว กำลังสร้างinstallerLZMA


- 2026-11-07T09:47:18.0578146+07:00 — installerLZMAรุ่น008buildผ่าน SHA256eb762646454e79d0e3cb462af30ac633dd9454aa8ed66ce25e012160ff622534 ใช้Unfair.exe SHA25606d11cd72701dc78c3d638398612f9f577d5544294053bd38b87bd6e3427703c; installedCodexMCP16tools+engineDiagnosticsยังผ่านหลังเปลี่ยนexe; เอกสารVALIDATION-v8.md+manifestพร้อม รอinstallerfinalQAก่อนปิดงาน


### ผลส่งมอบ UNFAIR-008

| ID | งาน | ผู้รับผิดชอบจริง | สถานะ | หลักฐาน |
| --- | --- | --- | --- | --- |
| UNFAIR-008.1 | ย้ายAI Assistก่อนContent/Undo/Redoและcompacttoolbar | main | Done | toolbarorder+active+1152/1600QAผ่าน |
| UNFAIR-008.2 | จัดหน้าAIpanel/advanced/empty-state/footer | unfair_branding + main | Done | nativecaptures+GUIhit-test+MCP23ผ่าน |
| UNFAIR-008.3 | แก้classicframeซ้อนและรักษามุมโค้งจริงด้านใน | unfair_motionตรวจread-only + mainแก้ | Done | DWMNC=1/region=0/darklight+captionbuttons+polygonclipผ่าน |
| UNFAIR-008.4 | Build/integration/regression/ส่งEXE+installer | main | Done | finalinstaller55hash/install/upgrade/uninstallผ่าน พร้อมเก็บprojectsentinel |

- 2026-11-07T09:48:20.8835840+07:00 — งาน008เสร็จ: bin/Unfair.exe hash06d11cd72701dc78c3d638398612f9f577d5544294053bd38b87bd6e3427703c ตรงcompiled; install.exe hasheb762646454e79d0e3cb462af30ac633dd9454aa8ed66ce25e012160ff622534 ผ่านfinalQA; สำรองexeก่อนหน้าเก็บครบ ไม่หยุดโปรแกรมผู้ใช้; nativecaptionPrintWindowตรวจจริงภาพunfair-v8-ai-native-dark/light.png
- ขอบเขต: Windows10ใช้outerframeปกติของOS, Windows11ขอroundhint; AIsurfaceมีchildclipจริง; exactcaptionRGBขึ้นกับOS; existingwindowhoverwarningพบในworkbenchแต่ไม่มีERROR/SCRIPTERROR; ไม่มีงานค้างก่อนใช้ — ปิดรุ่นเดิมแล้วเปิดbin/Unfair.exeหรือใช้installerใหม่


## งาน UNFAIR-009: ปรับความสูงปุ่ม AI Assist ให้เท่า Content Browser

- สถานะ: Done
- แผน: UNFAIR-009.1 mainตรวจsizeflags; UNFAIR-009.2 mainใช้vertical-fillแบบเดียวกัน; UNFAIR-009.3 mainbuild/ดูภาพGUIจริง/ส่งEXE+installerใหม่
- ทำตามลำดับเพราะเป็นlayoutflagจุดเดียวในeditor_node.cppและการverifyขึ้นกับbuild ไม่มีงานอิสระคุ้มแก่การแยกagent
- 2026-11-07T09:59:20.0559407+07:00 — พบAI Assistใช้SIZE_SHRINK_CENTER ส่วนContent Browserใช้ค่าFILL ทำให้ความสูงต่างกันในHBoxเดียวกัน; ปรับAIให้fillความสูงแถวเช่นเดียวกัน โดยยังให้ความกว้างตามข้อความ


- 2026-11-07T10:02:10.4477921+07:00 — buildผ่านและตรวจภาพจริงพบAI Assist/Content Browserสูงเท่ากันแล้ว; workbenchassertionsผ่าน แต่harnessเดิมwarpOSpointerไปปุ่มโลโก้และพบAboutเปิดซ้อนmodal จึงเปลี่ยนเฉพาะhovercaptureเป็นControlnotificationที่ไม่ย้ายpointer แล้วกำลังverifylogสะอาด; ส่งมอบexeพร้อมbackupแล้วและinstallerกำลังbuild ไม่มีproductionlogicนอกsizeflagเปลี่ยน


- 2026-11-07T10:04:22.0700956+07:00 — UNFAIR009เสร็จ: ภาพnativeworkbenchยืนยันความสูง/แนวข้อความของAI AssistและContent Browserตรงกัน; finalworkbench1152/1600/UndoRedo/transport/nativewindowsผ่าน ไม่มีERROR/SCRIPTERRORหลังเลิกwarpOSpointer; bin/Unfair.exe hashf43eb7f01d345429a6c0801db0fb0e01d9574a27dd15957f5df8e79f1abb9f13 ตรงcompiled สำรองก่อนหน้าไว้ครบ
- install.exe hashba65012e6798ec5ba7bd62e4a0d5750e5370de3a5634abe2f904fc4ffe6e7b26 ผ่านinstall/upgrade/uninstall+payloadhashโดยเก็บprojectsentinel; หลักฐานVALIDATION-v9.md/build-manifest-v9.json และunfair-v9-toolbar.png; ไม่มีงานค้าง — ปิดรุ่นเก่าแล้วเปิดbin/Unfair.exeหรือใช้installerใหม่


## งาน UNFAIR-010: อัปโหลด source ไป GitHub Private

- สถานะ: In progress
- เป้าหมาย: สร้างrepoใหม่แบบPrivateในบัญชีGitHubที่เชื่อมต่อและpushsourceโปรเจกต์ พร้อมตรวจvisibility/commitหลังpush
- UNFAIR-010.1 mainตรวจauth/reponame + review_workflowตรวจinventoryแบบread-only; UNFAIR-010.2 main.gitignore/README/localcommit; UNFAIR-010.3 mainสร้างPrivateก่อนpushและตรวจremoteSHA
- ขอบเขตsource: Godot Engine/ engine+UnfairUI/MCP/installer source, assetsที่ใช้build, ai-workflow และเอกสาร; ไม่รวมbin/build/cache/node_modules/QAexports/localconnections/SDK/downloadedruntimes
- 2026-11-07T10:07:48.6287856+07:00 — rootยังไม่มีGitrepo; connectedGitHubบัญชีreno0012x; connectorไม่มีcreate-repository จึงเตรียมใช้GitHubCLI/APIที่ยืนยันตัวตนสำหรับcreate/push โดยไม่แสดงcredentialในlog


- 2026-11-07T10:13:25.8048397+07:00 — ผู้ใช้ยืนยันdevice loginแล้ว GitHubCLIล็อกอินreno0012xสำเร็จ; CLIofficialv2.103.3ดาวน์โหลดตรงreleaseและSHA256ตรงchecksums; เตรียมGitrootbranchmain/README/.gitignoreและstage14,630files330.03MiB ไม่มีfiles>=50MiB/ไม่มีbin,node_modules,qa-output,.godot,.gitหรือtoolchainหลุด; inventoryagentยืนยันupstreamtest.zip/crypto.keyเป็นfixturesจึงเก็บไว้

