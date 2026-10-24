# Agent Tools guidance

This directory is the canonical home for reusable local tooling used by coding agents. Keep tool implementations here rather than copying helpers into individual projects.

## GameMaker

- For GameMaker work, start with `C:\Agent Tools\game-maker\AGENTS.md` (entry points, command catalog, workflows) and use only the implemented commands listed in `C:\Agent Tools\game-maker\README.md`.
- Run `C:\Agent Tools\game-maker\gmtool.ps1 capabilities --json` before planning a resource mutation; treat the per-family/per-operation manifest as authoritative and stop on `planned` capabilities.
- Review `gmtool graph ... --direction both` before rename/delete operations; hard metadata references and soft/static code references are reported separately.
- Treat `C:\Agent Tools\game-maker\PLAN.md` as design guidance, not as proof that a command already exists. Check the status table in the README before invoking anything.
- Use `C:\Agent Tools\game-maker\RESOURCE_COVERAGE.md` as the definition of full resource support. A resource family is not complete until its entire lifecycle and preview contract pass the listed acceptance tests.
- Use YoYo Games' `gm-cli` as the authoritative integration for ResourceTool operations and for compiling, running, and testing projects. Route it through the wrappers implemented in the GameMaker tools (`gmtool compile`/`test`/`run`/`resource-tool`/`resource`) rather than duplicating its behavior.
- Prefer the agent-friendly `resource` recipes for common resource, object-event, room, sprite, sound, shader, script, note, tileset, group, and configuration operations. Keep `resource-tool` for deliberate official expressions and always review its disposable-copy diff.
- Use `compile`/`test` for build checks and bounded `run` for smoke/debug feedback. Preserve the exact profile, timeout, exit status, logs, and unexpected-project-change report.
- If an agent or process is interrupted during a mutation, inspect `gmtool recover --json`; use `recover --rollback --transaction-id ...` only for an unfinished journal after checking its recorded project root.
- In PowerShell, never invoke `gm` expecting GameMaker; `gm` is the built-in alias for `Get-Member`. Resolve `gm-cli.cmd` or use the GameMaker tool wrapper.
- Do not treat `gm-cli resourcetool eval` as read-only. It can save and normalize project metadata even for a query. Run previews against a disposable copy, hash the working project before and after direct calls, and review the resulting diff.
- For syntax failures, use the diagnostic/repair workflow in `C:\Agent Tools\game-maker\SYNTAX_REPAIR.md` (`diagnose`/`explain-error`/`repair-syntax` are implemented; repair is dry-run by default and needs `--apply`). Auto-apply only compiler-verified, high-confidence, minimal fixes; leave ambiguous or semantic changes for review.
- Build all GameMaker-specific code, fixtures, tests, and documentation under `C:\Agent Tools\game-maker`.
- Preserve GameMaker's source formatting and metadata. Structural changes must be transactional, support a dry run, and validate cross-file references before being considered complete.
- Keep the tools project-agnostic. Project-specific behavior belongs in a version profile, fixture, or explicit command option rather than a hard-coded `Simple3D` rule.
- When a capability is added or changed, update the README status and command examples in the same change.
