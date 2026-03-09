---
description: Report bugs, improvements, or gaps — organize, fix, verify, and cover with E2E tests
---

Report bugs, improvements, or gaps discovered during manual verification.

This command activates the **openspec-feedback** skill, which:
1. Records all reported issues in `tasks.md` before any fix begins
2. Evaluates whether delta spec updates are needed
3. Fixes each issue systematically
4. Adds E2E test cases to prevent regression
5. Verifies everything works

**Input**: Describe the issues you found. Can be:
- A single bug: `/opsx-feedback 登录状态失效后还能访问页面`
- A numbered list of problems (paste directly after the command)
- Keywords like "问题反馈", "bug", "改进" followed by descriptions

**Examples**:
```
/opsx-feedback 用户管理页面的UID字段不应该允许编辑
```

```
/opsx-feedback
1. 对话框按钮显示英文
2. 创建用户表单多余的UID字段
3. token过期不跳转登录页
```
