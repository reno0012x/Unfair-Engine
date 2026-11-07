<!-- BEGIN parallel-work-log -->
## Project work: divide, delegate, and record progress

For every substantive workspace task, use the `parallel-work-log` skill. Read its `SKILL.md` from the available skill path; the user installation is normally `~/.agents/skills/parallel-work-log/SKILL.md`. If unavailable, look for the workspace backup `ai-workflow/skills/parallel-work-log/SKILL.md`.

Break work into owned tasks before execution. The user requests delegation to sub-agents by default: delegate useful independent tasks when tools and applicable instructions allow it; otherwise record why the tasks must run sequentially. The coordinating agent owns integration and the shared status file.

Read and maintain the project's `WORK_STATUS.md`: save the initial plan, meaningful progress, changed paths, decisions, verification results, blockers, and a concrete next step. Preserve existing and concurrent task history. Use Thai for explanations and status unless the user chooses another language. Send concise progress updates during work and link the log in the final reply.

Keep this lightweight for small tasks. Greetings and standalone factual answers do not need a log. Honor explicit solo work, no-file-change requests, project-specific rules, and tool or access restrictions. Never fabricate agents, completed work, or test results.
<!-- END parallel-work-log -->
