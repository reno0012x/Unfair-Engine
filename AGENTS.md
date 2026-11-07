# Workspace workflow

For every substantive task in this workspace, read and apply `ai-workflow/skills/parallel-work-log/SKILL.md` (or the installed `parallel-work-log` skill).

- Divide work into owned tasks. The user requests sub-agent delegation for useful independent tasks when tools and applicable instructions allow it. Record a concrete reason when working sequentially.
- The coordinating agent reads and updates `WORK_STATUS.md` in this workspace root before work, at meaningful checkpoints, and before finishing. Preserve other task sections and evidence.
- Explain progress and write status in Thai unless the user chooses another language. Record changed paths, actual checks and results, blockers, and the next step. Agents report to the coordinator instead of editing the shared log.
- Honor explicit solo or no-write requests and more specific project rules. Keep short standalone answers lightweight.

The Godot source tree is under `Godot Engine/`. The reusable skill backup and Windows installer are under `ai-workflow/`.
