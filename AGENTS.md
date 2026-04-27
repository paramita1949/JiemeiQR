# AGENTS.md - QRSCAN Project Agent Rules

## Mandatory Skills
For every programming/development task in this workspace, load and follow:
- `using-superpowers`
- `systematic-debugging`
- `verification-before-completion`

Use additional skills only when the request clearly matches them. Do not load extra workflows just to appear thorough.

## UI And Design Skills
When the task changes UI, interaction flow, screens, page structure, or visual design, additionally load the relevant skills:
- `brainstorming` before creative UI work, behavior changes, or new components.
- `web-design-guidelines` when reviewing UI, accessibility, visual quality, or interaction quality.
- `figma` / `figma-implement-design` only when the user provides Figma URLs, node IDs, or asks to match a Figma design.
- `playwright`, `playwright-interactive`, or `agent-browser` when browser/app UI behavior needs visual or flow verification.

## Pencil Design Tools
There is no separate local `pencil` SKILL.md currently confirmed. Treat Pencil as an available design toolset through the `mcp__pencil__` tools.

Use Pencil tools when editing or inspecting `.pen` design files, creating UI mockups, exporting design screenshots, or verifying visual layout:
- `get_editor_state`, `batch_get`, and `snapshot_layout` for reading design state.
- `batch_design` for controlled design edits.
- `get_screenshot` and `export_nodes` for visual verification/export.

Do not use Pencil edits as decoration. Use them only when they clarify or improve an actual screen, flow, or visual decision.

## Working Principles
- Be practical and lightweight. Prefer small, direct changes over broad refactors.
- Do not over-optimize, over-engineer, or add architecture/process that the current app does not need.
- Do not change code just for style, novelty, or theoretical cleanliness.
- Challenge unnecessary requested changes when the current behavior is adequate or the tradeoff is poor.
- Preserve existing user-approved business rules recorded in `.learnings/LEARNINGS.md`.
- Before changing UI or behavior, identify the actual user problem and avoid inventing extra features.

## UI Design Direction
- UI should be human-friendly, clear, and task-oriented.
- Prioritize readable Chinese labels, obvious actions, safe destructive confirmations, and low operator workload.
- Avoid decorative complexity that does not improve warehouse/order/inventory operations.
- Improve design quality through consistency, spacing, hierarchy, and concrete workflow fit, not visual noise.

## Debugging And Verification
- For bugs or test failures, investigate root cause before fixing.
- Make the smallest change that addresses the verified cause.
- Before claiming completion, run fresh verification when feasible and report the exact command/result.
- If local tooling is missing, use known workspace paths from `.learnings/ERRORS.md` before declaring verification blocked.

## Flutter Toolchain
- Do not assume `flutter` or `dart` are available on `PATH` in this workspace.
- Use `C:\tools\flutter\bin\flutter.bat` for Flutter commands.
- Use `C:\tools\flutter\bin\dart.bat` for Dart commands.
- Typical verification command: `C:\tools\flutter\bin\flutter.bat test` from `flutter_app/`.
- Do not repeatedly search for the Flutter SDK unless `C:\tools\flutter\bin\flutter.bat` is missing or fails.

## Project Memory
- Use `.learnings/` for durable project memory:
  - `LEARNINGS.md` for user corrections, project conventions, and better practices.
  - `ERRORS.md` for tool failures or unexpected command behavior.
- Promote repeated or high-value learnings into this file only when they are broadly useful.
