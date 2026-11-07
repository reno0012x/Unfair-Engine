---
name: parallel-work-log
description: "Break project work into owned tasks, delegate independent work to available sub-agents, and maintain WORK_STATUS.md for progress and handoff. Use when starting, continuing, changing, checking, or finishing substantive workspace work."
---

# Parallel work and persistent status

The user wants work divided every time and progress saved in Markdown so another session can continue. Apply this to substantive project tasks, including investigations and reviews. Keep small tasks lightweight; greetings and short standalone answers do not need a project log.

## Start or resume

- Read applicable project instructions and the existing `WORK_STATUS.md` before planning or changing project files. Resolve its location from project instructions first; otherwise use the relevant repository root, or the current workspace when there is no repository. Reuse an established project status file if one already serves this purpose.
- Reconcile the log with current files and actual tool results. Treat old status as context, not proof that work or tests are still current. Preserve unfinished tasks from other requests.
- Before substantive work, split the request into concrete tasks with stable IDs, an owner, dependencies where needed, and an observable completion condition. Even small changes can use a short inspect/change/check plan rather than an elaborate process.
- Record the objective and plan in the log, then briefly tell the user what work is starting. Do not request approval for routine decomposition or already authorized work.

## Delegate real work

- The user requests sub-agent delegation as the default for project work. When delegation tools are available and there is a useful independent task, actually delegate it. Suitable tasks include bounded research, implementation in separate files, reproduction, and an independent review of completed work.
- Choose the number of agents to fit the work and available slots. Do not manufacture busywork or spawn agents merely to populate a table. If no useful independent task exists, or tools/instructions prevent delegation, record the specific reason and perform the divided tasks sequentially.
- Give each agent a task ID, objective, relevant context, permitted files or read-only scope, dependencies, expected evidence, and reporting requirements. Make one owner responsible for each edited file. Explicitly tell agents that other workers may be changing the workspace and that they must preserve those changes.
- The coordinating agent alone updates the shared status file. Sub-agents report progress, changed paths, checks, findings, blockers, and next steps to the coordinator; they do not concurrently edit `WORK_STATUS.md`.
- Keep useful integration or implementation work with the coordinator while independent tasks run. Before finishing, collect relevant agent results, inspect their actual output, and run the checks appropriate to the integrated result. Do not label planned delegation as completed delegation.

## Maintain WORK_STATUS.md

- Write the log in the user's language, normally Thai for this user. Keep code identifiers, paths, and command names exact. Use UTF-8 and unambiguous timestamps with a timezone; this user's default is Asia/Bangkok (`+07:00`) unless they specify otherwise.
- Update after the initial plan, meaningful changes or findings, an agent result, verification, a blocker or scope change, and before ending or handing off. Do not wait until the end to create the first checkpoint. Avoid entries for every tool call or repeated entries when nothing changed.
- Before each edit, reread the relevant task section and preserve unrelated work or concurrent updates. Use a separate task section and stable IDs when more than one request is active in the same log.
- Keep a current summary and concise chronological checkpoints. Record what actually happened, affected paths, decisions and reasons, checks and outcomes, remaining work, and a concrete next step. Never record secrets or raw credentials.
- Use consistent states: `Pending`, `In progress`, `Blocked`, `Done`, and `Cancelled`. A blocker needs a reason and an unblocking action. Mark work `Done` only when its completion condition is satisfied; distinguish verified results from untested work.
- For a purely read-only request that prohibits file changes, respect that restriction: keep the plan and status in the reply and explain that no Markdown file was written. A workflow preference does not override the user's current constraints or grant additional access.

Use this compact structure when creating a log; adapt existing logs without replacing their history:

```markdown
# สถานะงาน

อัปเดต: YYYY-MM-DDTHH:mm:ss+07:00

## งาน TASK-ID: ชื่องาน

- เป้าหมาย: ผลลัพธ์ที่ผู้ใช้ต้องการ
- สถานะรวม: In progress
- การแบ่งงาน: agent ที่ใช้งานจริง หรือเหตุผลที่ทำตามลำดับ

| ID | งาน / เงื่อนไขเสร็จ | ผู้รับผิดชอบ | สถานะ | ผลลัพธ์ / หลักฐาน |
| --- | --- | --- | --- | --- |
| TASK-ID.1 | ผลลัพธ์ที่ตรวจสอบได้ | main | Pending | ยังไม่เริ่ม |

### สิ่งที่ทำแล้วและไฟล์ที่เกี่ยวข้อง

- บันทึกเฉพาะสิ่งที่เกิดขึ้นจริง พร้อม path

### การตรวจสอบ

- คำสั่งหรือวิธีตรวจ พร้อมผลจริง; ถ้ายังไม่ได้ตรวจให้ระบุ

### งานค้าง / อุปสรรค / ขั้นตอนถัดไป

- ระบุจุดเริ่มทำต่อได้ทันที หรือระบุว่างานนี้เสร็จแล้ว

### บันทึกความคืบหน้า

- YYYY-MM-DDTHH:mm:ss+07:00 — เหตุการณ์และผลลัพธ์ที่เกิดขึ้นจริง
```

## Communicate and finish

- During active work, send short progress updates in the user's language about meaningful findings and the next step. Avoid more than about 60 seconds of silence when tools allow updates; do not send empty status messages.
- If interrupted or blocked, save a checkpoint whenever tools and permissions allow. Include what is safe to resume and any still-running work. Do not claim that an unexpected termination will always allow a final write.
- Before the final reply, update the log with actual completion state, verification, remaining work, and the next action. Briefly summarize the result and link the status file. Do not claim recovery of files or skills that were not recovered.
