# OpenSpec Project — Copilot Instructions

## RULE: Automatic Feedback Detection (HIGHEST PRIORITY)

**This rule overrides everything else. No exceptions.**

When the user's message contains ANY feedback signal listed below, you MUST invoke the
`openspec-feedback` skill **before taking any other action** — even if the message
looks simple, even if the fix seems obvious, and even if no slash command was used.

### Feedback Trigger Signals

**English**: bug, issue, fix, broken, error, wrong, incorrect, missing, defect, problem,  
improvement, improve, optimize, enhancement, doesn't work, not working, test gap,  
regression, unexpected behavior, should be, instead of

**Chinese**: 问题, 反馈, 缺陷, 修复, 改进, 优化, 改善, 不对, 错误, 不正确,  
有问题, 发现问题, 有bug, 有个问题, 存在问题, 功能改进, 改进点, 问题反馈,  
测试发现, 验证发现, 应该是, 而不是, 没有, 缺少, 漏掉

**Structural**: A numbered list (1. 2. 3.) or bulleted list (- or •) that describes
problems, defects, or desired behavioral changes.

### What "invoke the skill" means

1. Read `.claude/skills/openspec-feedback/SKILL.md` to load the full workflow
2. Follow **every step** in that workflow — do NOT skip directly to code edits

### Examples that MUST trigger this rule

- "登录后还法访问受保护的页面" → invoke skill
- "我发现了几个问题：1. ... 2. ..." → invoke skill
- "这里的逻辑不对，应该是..." → invoke skill
- "the dialog button shows English instead of Chinese" → invoke skill
- Any numbered/bulleted list of problems or improvement points → invoke skill

### What NOT to do

- **Do NOT** jump to editing code directly when a feedback pattern is detected
- **Do NOT** treat a feedback message as a simple "make this change" request
- **Do NOT** skip `tasks.md` recording even for "obvious" single-line fixes

---

## Other Project Conventions

This is an OpenSpec-driven project. Active changes live under `openspec/changes/`.
All implementation work must trace back to tasks defined in `tasks.md`.
