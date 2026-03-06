---
name: openspec-hotfix
description: Organize, fix, and verify bugs, improvements, or gaps reported during manual verification of an OpenSpec change. Use this skill when the user reports bugs, issues, defects, missing test cases, missing coverage, or improvement points after AI implementation. This skill ensures every reported issue is tracked as a task artifact before any fix begins, creating a closed-loop management process.
license: MIT
compatibility: Requires openspec CLI. Works with any openspec schema that has a tasks artifact.
metadata:
  author: openspec
  version: "1.0"
---

# Hotfix: Structured Bug Fix & Verification Loop

When users perform manual verification after AI-driven implementation, they often discover bugs or improvement points. This skill captures those issues, organizes them into a traceable task list stored in the change's `tasks.md`, then systematically fixes and verifies each one — ensuring nothing falls through the cracks.

The core principle: **write it down first, then fix it**. Every issue gets recorded as a task artifact before any code change happens. This creates accountability, traceability, and a clean audit trail.

---

## When This Skill Activates

- User reports one or more bugs, defects, improvement points, or gaps (missing features / missing test cases / incomplete coverage)
- User describes untested scenarios, missing test cases, or test coverage gaps
- The project uses OpenSpec with an active change
- The issues relate to an existing implementation (post-development feedback)

---

## Workflow

### 1. Identify the Active Change

Determine which change the issues relate to:

- If the user specifies a change name, use it
- If conversation context makes it obvious, use that
- If only one active change exists, auto-select it
- If ambiguous, run `openspec list --json` and ask the user to select

Announce: "Applying hotfixes to change: **<name>**"

### 2. Read Current Context

Read existing artifacts to understand the implementation state:

- Read `tasks.md` to understand the current task structure, naming conventions, and numbering
- Read `design.md` and `proposal.md` if they exist, for architectural context
- Scan relevant source files mentioned by the user

This context is essential — fixes must be consistent with the existing architecture and coding patterns.

### 3. Analyze and Organize Issues

Parse the user's reported issues carefully. For each issue:

1. **Classify** — Is it a bug (incorrect behavior), a missing feature, a UX improvement, a test gap (missing test case / incomplete test coverage), or a missing implementation?
2. **Identify root cause** — What's the likely technical root cause? Which files are affected?
3. **Assess impact** — What does this break? What's the blast radius?
4. **Define verification** — How will we confirm the fix works?

Group related issues together. If one root cause explains multiple symptoms, merge them into a single task with multiple verification points.

### 4. Write the Task List to tasks.md

Append a new **Hotfix section** to the existing `tasks.md` file. Follow the existing file's conventions for formatting and numbering.

**Section format:**

If `tasks.md` does not yet have a Hotfix section, append one:

```markdown
## 人工验证修复（Hotfix）

> 本节记录人工验证中发现的问题及修复记录。

- [ ] **HF-1** `<primary file path>`：<concise issue title>
  - 现象：<what the user observed / reported>
  - 根因：<technical root cause analysis>
  - 影响：<impact scope>
  - 修复方案：<planned fix approach>
  - 验证：<how to verify the fix>

- [ ] **HF-2** `<primary file path>`：<concise issue title>
  - 现象：...
  - 根因：...
  - 影响：...
  - 修复方案：...
  - 验证：...
```

If the Hotfix section already exists (from a previous round of feedback), simply append new tasks to it with the next sequential number.

**Numbering rules:**
- Task IDs use simple sequential numbering: `HF-1`, `HF-2`, `HF-3`, ...
- Check the existing Hotfix section for the last used number and continue from there
- All hotfix tasks — regardless of when they were reported — live in the same single section

**Important:** Show the draft task list to the user and confirm before writing to `tasks.md`. The user may want to adjust priorities, merge issues, or add details. Once confirmed, append the section to the file.

### 5. Execute Fixes (Loop)

Work through the task list sequentially. For each task:

**a. Announce**
```
## Fixing HF-X: <issue title>
```

**b. Investigate**
- Read the relevant source files
- Understand the current behavior
- Confirm the root cause matches the analysis

**c. Implement the fix**
- Make minimal, focused changes
- Keep the fix scoped to the specific issue
- Follow existing code patterns and conventions
- If the fix reveals a deeper issue, pause and discuss with the user

**d. Verify**
- Run relevant tests if they exist
- If the project has e2e tests, run them to check for regressions
- Manually verify the specific behavior described in the task's verification criteria
- Check for side effects in related functionality

**e. Update tasks.md**
- Mark the task as complete: `- [ ]` → `- [x]`
- Add a brief fix summary if the actual fix differed from the planned approach:
  ```markdown
  - [x] **HF-1** `path/to/file.go`：<issue title>
    - 现象：...
    - 根因：...
    - 影响：...
    - 修复方案：<what was actually done>
    - 验证：<verification result — ✓ or details>
  ```

**f. Continue to next task**

### 6. Run Comprehensive Verification

After all individual fixes are complete:

1. Run the full test suite if available
2. Report results — which tests pass, which fail
3. If new failures appear, analyze whether they are regressions from the fixes
4. If regressions exist, add them as new tasks and loop back to Step 5

### 7. Report Completion

Display a summary:

```
## Hotfix Complete

**Change:** <change-name>
**Issues reported:** X
**Issues fixed:** Y/X
**Verification:** <all passed / N issues remaining>

### Fixed This Session
- [x] HF-1: <title> ✓
- [x] HF-2: <title> ✓
- [x] HF-3: <title> ✓

### Remaining (if any)
- [ ] HF-4: <title> — blocked by <reason>

All fixes verified. The tasks.md has been updated with full fix records.
```

If all tasks are complete and verified, suggest archiving the change.

---

## Handling Edge Cases

**User reports a single issue:** Still follow the full workflow — even one issue benefits from being recorded before fixing. The task list will just have one item.

**User reports missing test cases:** This is a test gap, not a bug. Classify as test gap, record the expected test scenarios in the task, implement the test cases (add to e2e test scripts or unit tests as appropriate), then verify by running the tests. The fix is the new test code itself.

**Fix reveals additional problems:** Add them as new tasks in the same Hotfix section. Announce: "While fixing HF-X, I discovered an additional issue. Adding HF-Y to the task list."

**Issue is actually a design change:** If a reported "bug" is actually a feature request or design change, flag it: "This looks like a design change rather than a bug. Want me to update the design artifacts, or treat it as a hotfix?" Respect the user's decision.

**No active openspec change:** If the project uses openspec but there's no active change (e.g., all archived), create a new hotfix-specific change:
```bash
openspec new change "hotfix-<brief-description>"
```
Then generate the tasks.md in that new change directory.

**Multiple rounds of hotfixes:** All hotfix tasks from every round of feedback are appended to the same single Hotfix section. Sequential numbering (`HF-1`, `HF-2`, ...) naturally preserves the chronological order of when issues were discovered and fixed.

---

## Guardrails

- **Always write tasks before fixing** — Never start coding a fix without first recording it in tasks.md
- **Confirm the task list with the user** — The user knows what they observed; validate your analysis matches their experience
- **Minimal fixes** — Don't refactor or improve code beyond what's needed to fix the reported issue
- **Verify each fix individually** — Don't batch all fixes and hope for the best
- **Update tasks.md in real time** — Mark tasks complete immediately after verification, not at the end
- **Preserve existing task format** — Match the conventions already used in the file
- **Don't lose context** — If the user's description is detailed, preserve those details in the task record

