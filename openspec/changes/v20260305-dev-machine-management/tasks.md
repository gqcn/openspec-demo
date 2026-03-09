# 开发机管理模块 — 任务拆解

## 任务状态说明
- [ ] 未开始
- [x] 已完成

---

## 零、缺陷修复（Bug Fixes）

> 本节记录事后发现并修复的问题，不改变原始需求任务编号。

- [x] **BUG-1** `frontend/src/api/http.ts`：修复 Axios 响应拦截器未检查 GoFrame 错误码  
  - 根因：GoFrame 所有错误以 HTTP 200 + `{ code: X, message: "...", data: null }` 返回，原拦截器无 code 检查，导致错误响应被视为成功  
  - 影响：登录失败崩溃（`Cannot read properties of undefined (reading 'token')`）、规格创建/修改静默失败  
  - 修复：在 success interceptor 中加入 `if (response.data?.code !== 0) return Promise.reject(response.data)` 判断

- [x] **BUG-2** `backend/internal/service/spec/spec.go`：`Update` 未加 `OmitEmpty()` 导致字段被清空  
  - 根因：`do.Spec` 所有字段为 `interface{}`；前端仅传 name/cpu/memory/gpu/gpuType 时，NodeSelector/Tolerations/Description 默认为空字符串（非 nil），ORM 会将其写入 DB，清除原有配置  
  - 修复：`dao.Specs.Ctx(ctx).Where("id", id).Data(in).OmitEmpty().Update()`

- [x] **BUG-3** `backend/internal/controller/spec/spec_v1_handlers.go`：`GET /api/spec` 始终过滤 enabled=1，管理员无法在规格管理页看到禁用规格  
  - 修复：在 List handler 中读取 JWT 上下文用户，管理员调用 `svcSpec.ListAll(ctx)`，普通用户调用 `svcSpec.List(ctx)`

- [x] **BUG-4** `frontend/src/views/NotebookListView.vue`：创建开发机按钮无禁用状态，有活跃实例时仍可点击  
  - 修复：添加 `hasActiveNotebook` computed（检测 creating/running/stopping 状态），对创建按钮添加 `:disabled="hasActiveNotebook"` 及 Tooltip 提示

- [x] **BUG-5** `frontend/src/views/NotebookListView.vue`：已停止/异常实例无删除记录按钮，旧记录无法手动清理  
  - 修复：为 stopped/failed 实例添加"删除记录"按钮（调用 `DELETE /api/notebook/{id}`）；后端 `Delete` 对已停止实例直接物理删除 DB 行

- [x] **BUG-6** `backend/internal/service/notebook/notebook.go`：创建新实例前不清理旧的 stopped/failed 记录，导致每次创建都留下历史条目  
  - 修复：在 `Create()` 的活跃实例检查通过后，自动删除该用户所有 stopped/failed 记录，保持列表整洁

- [x] **BUG-7** `backend/internal/service/spec/spec.go`：`Create` 未加 `OmitEmpty()`，JSON 列写入空字符串  
  - 根因：`node_selector` / `tolerations` 定义为 `JSON DEFAULT NULL`；未传时 `do.Spec` 对应字段为 `""`（空字符串），MySQL JSON 列不接受空字符串，报 Error 3140  
  - 修复：`dao.Specs.Ctx(ctx).Data(in).OmitEmpty().Insert()`（Update 在 BUG-2 时已修复）

- [x] **BUG-8** `backend/internal/service/user/user.go`：`Create` 未在 INSERT 中包含 `uid`，触发 NOT NULL 约束  
  - 根因：`users.uid INT UNSIGNED NOT NULL` 无 DEFAULT 值；原 Insert 省略 `uid` 字段导致 MySQL Error 1364  
  - 修复：INSERT 时先存入 `Uid: uint(0)` 占位（满足 NOT NULL），成功后 `UPDATE SET uid = 10000 + id`；同时修复 Update 改用 `g.Map{"uid": uid}` 避免全字段覆盖

- [x] **BUG-9** `backend/internal/service/middleware/middleware.go`：`WriteStatus(200/401/403)` 向响应 Body 写入状态文本前缀  
  - 根因：GoFrame `r.Response.WriteStatus(code)` 在无第二参数时将 HTTP 状态文本（"OK"/"Unauthorized"/"Forbidden"）写入 Body Buffer，`WriteJson` 追加 JSON 后 Body 变为 `OK{...}`，前端 `JSON.parse` 报 SyntaxError  
  - 修复：移除所有 `WriteStatus` 调用；Auth/AdminOnly 中间件直接使用 `WriteJson` 输出错误体

- [x] **BUG-10** `backend/internal/service/middleware/middleware.go`：Auth 中间件写响应 + `HandlerResponse` 再次包装，导致 Body 中出现双份 JSON  
  - 根因：Auth 写完响应后调用 `r.ExitAll()`，但 `HandlerResponse` 的 `r.Middleware.Next()` 返回后仍继续执行并追加第二份 JSON  
  - 修复：在 `HandlerResponse` 后半段（`Next()` 返回后）加入 `if len(r.Response.Buffer()) > 0 { return }` 检查，若已有内容则跳过包装

---

## QA 测试脚本修复记录（e2e-test.sh）

> 以下记录测试脚本本身的缺陷，与产品功能无关，均已修复。

- [x] **QA-TS-1** `get_result()` 未过滤 `\r`，Windows CRLF 残留导致字符串比对失败  
  → 修复：`tr -d '"\\r'`

- [x] **QA-TS-2** GPU-标准 规格数据在多次运行间可能缺失  
  → 修复：在 TC0002 前增加自动播种逻辑（检测后按需调 POST /api/spec 创建）

- [x] **QA-TS-3** TC0004d/TC0008c：`localStorage.getItem('token')` 在 Node.js 回调上下文中不可用  
  → 修复：将 `localStorage` 访问移入 `page.evaluate()` 内（浏览器上下文）

- [x] **QA-TS-4** TC0002f/TC0002g：`getByPlaceholder('如: 4')` 部分匹配命中"如: 4C8G"（规格名称栏），Playwright 严格模式报错  
  → 修复：添加 `{ exact: true }` 参数

- [x] **QA-TS-5** TC0003d：创建用户对话框的确认按钮文本为"创建"而非"保存"  
  → 修复：将 `getByRole('button', { name: '保存' })` 改为 `getByRole('button', { name: '创建' })`

- [x] **QA-TS-6** TC0007：退出登录抽屉触发器为 `<span>`，`getByRole('button', { name: 'admin' })` 在部分状态下无法匹配  
  → 修复：增加 `.el-header .el-dropdown` / `[tabindex="0"]` 备用选择器兜底

- [x] **QA-TS-7** TC0007e/TC0008：`$WRONG_PASS_RESULT）` / `$BTN_ENABLED）` 后紧跟全角字符，bash `set -u` 将 UTF-8 首字节误解析为变量名的一部分，报 unbound variable  
  → 修复：改用 `${WRONG_PASS_RESULT}` / `${BTN_ENABLED}` 显式括号

- [x] **QA-TS-8** TC0008（停止确认）：`getByRole('button', { name: '停止', exact: true })` 在对话框打开时命中表行按钮 + 对话框确认按钮，Playwright 严格模式报 StrictModeViolationError，`catch {}` 吞掉错误导致对话框从未被确认，实例永不停止  
  → 修复：范围限定到 `.el-message-box` 后再查找确认按钮

- [x] **QA-TS-9** TC0004/TC0008（创建开发机对话框）：`[class*="select"]` 在点击规格卡片后命中 `.spec-card.selected`（"selected" 含子串 "select"），下拉框未打开，镜像未选择，创建静默失败  
  → 修复：改用 `.el-select__wrapper` 精确定位镜像下拉触发元素

- [x] **QA-TS-10** TC0008c：断言检查 `body.includes('pytorch-notebook')` 但前端镜像列展示的是 `imageName`（"PyTorch 2.2 + CUDA 12.1"）而非 Docker 镜像 URL  
  → 修复：改为 `body.includes('pytorch-cuda121') || body.includes('PyTorch')`

- [x] **QA-TS-11** TC0006：分三条独立的 `playwright-cli keydown/press/keyup` 命令触发 Shift+Enter，每次调用均重置键盘状态，实际未发出 Shift+Enter；`wait_for_text` 轮询上限 30 次不足以覆盖新 Pod 内核冷启动  
  → 修复：合并为单一 `run-code` 中的 `page.keyboard.press('Shift+Enter')`；`wait_for_text` 轮询次数从 30 增至 60

---

## 设计决策说明（Design Decisions）

> 以下记录实现过程中发现功能与原始设计文档不符的地方及处置决定。

### DD-1：每用户一实例策略（Issue 6 & 8）
**背景**：原设计中对"同时只能有一个实例"的约束未明确说明是否允许保留历史已停止记录，也未明确前端如何防止重复创建。  
**决定**：
- 后端创建检查已正确拦截 creating/running/stopping 状态（allowed to have stopped/failed records prior to fix）
- 前端增加 `hasActiveNotebook` 计算属性，禁用创建按钮并显示 Tooltip
- 后端 `Create()` 自动清理旧 stopped/failed 记录（保留最多 1 条活跃记录，无历史堆积）
- 前端新增"删除记录"按钮，允许用户手动清除已停止实例的 DB 条目

### DD-2：管理员规格列表可见性（Issue 3）
**背景**：原设计 `GET /api/spec` 文档写的是返回 enabled=1 的规格，但管理员在规格管理页面需要看到所有规格（含禁用）以便操作。  
**决定**：同一接口根据 JWT 身份动态切换返回策略  
- 管理员 → 返回所有规格（`ListAll`）
- 普通用户 → 仅返回启用的规格（`List`，用于创建开发机选择）
- 创建开发机弹窗客户端侧仍额外过滤 `enabled === 1`，防止管理员无意选择已禁用规格

### DD-3：HTTP 响应统一错误处理（Issue 1 & 3 & 4）
**背景**：GoFrame 的约定是所有错误以 HTTP 200 + `{ code: X }` 返回，而非 HTTP 4xx。原 Axios 拦截器只处理 HTTP 状态码，导致业务错误被当作成功处理。  
**决定**：在 Axios success 拦截器中统一检查 `response.data.code`，非 0 时 `Promise.reject`，让各页面的 catch 块正确显示错误信息。

---



- [ ] **INFRA-1** 创建 K8S namespace `jupyter`
- [ ] **INFRA-2** 部署 NFS StorageClass，创建共享 PVC `pvc-jupyter-shared`（RWX）
- [ ] **INFRA-3** 初始化 PVC 目录结构：`/share`（GID=20000，chmod 2775）
- [ ] **INFRA-4** 确认集群中 nvidia device plugin 已部署（GPU 节点支持）
- [x] **DB-1** 创建数据库，执行建表 SQL：`users` / `specs` / `images` / `instances`
- [x] **DB-2** 初始化默认规格套餐数据（至少 3 个：CPU-小、CPU-大、GPU-标准）
- [ ] **DB-3** 初始化默认镜像数据（至少 2 个：通用 Python、PyTorch+CUDA）

---

## 二、后端 — GoFrame API Server

### 2.1 项目基础

- [x] **BE-1** 初始化 GoFrame 项目结构（gf cli 脚手架）
- [x] **BE-2** 配置 MySQL 数据源，集成 GoFrame ORM
- [x] **BE-3** 集成 K8S client-go，封装 K8S 操作客户端
- [x] **BE-4** 实现 JWT 中间件（颖发、验证、刷新）
- [x] **BE-5** 实现统一错误码和响应结构

### 2.2 用户认证模块

- [x] **BE-6** `POST /api/auth/login` — 账号密码登录，bcrypt 校验，返回 JWT
- [x] **BE-7** `POST /api/auth/logout` — 登出（客户端丢弃 Token）
- [x] **BE-8** 用户注册接口（管理员创建用户，自动分配 UID = 10000 + id）

### 2.3 规格套餐管理

- [x] **BE-9**  `GET /api/spec` — 套餐列表（enabled=1）
- [x] **BE-10** `POST /api/spec` — 新建套餐（管理员）
- [x] **BE-11** `PUT /api/spec/{id}` — 修改套餐（管理员）
- [x] **BE-12** `DELETE /api/spec/{id}` — 删除套餐（管理员）

### 2.4 镜像配置（配置文件，本期无过 DB）

- [x] **BE-13** 在配置文件中定义镜像列表结构（名称、镜像地址、描述、是否启用）
- [x] **BE-14** `GET /api/image` — 读取配置文件返回可用镜像列表（供前端创建开发机时选择）

### 2.5 开发机实例管理

- [x] **BE-17** `GET /api/notebook` — 实例列表，实时查询 K8S Pod 状态并合并返回
- [x] **BE-18** `GET /api/notebook/{id}` — 实例详情
- [x] **BE-19** `POST /api/notebook` — 创建开发机
  - 校验用户是否已有活跃实例（creating/running/stopping）
  - 使用 `guid.S()` 生成 token，写入 DB
  - 初始化用户 NFS 目录（创建 `/data/home/{username}` 并 chown）
  - 调 K8S API 创建 Pod + Service + Ingress
  - 轮询 Pod 状态至 Running，更新 DB status = 'running' 及 pod_ip
- [x] **BE-20** `DELETE /api/notebook/{id}` — 手动停止
  - 删除 K8S Pod + Service + Ingress
  - 更新 DB status = 'stopped'
- [x] **BE-21** `POST /api/notebook/{id}/restart` — 重启：先删 Pod 再重建，保留 token 不变
- [x] **BE-22** 封装 K8S Pod 创建函数，按测试案例模式构造 Pod spec：
  - `runAsUser: 0` + `NB_UID`/`NB_GID`/`NB_USER` 环境变量注入
  - `JUPYTER_TOKEN` = token，`JUPYTER_BASE_URL` = `/jupyter/{token}/`
  - 启动命令：`start.sh start-notebook.sh`（软链 `/data/home/{username}` 到 `/home/{username}`）
  - livenessProbe / readinessProbe 路径：`/jupyter/{token}/lab`
  - volumeMounts: `subPath: data/home` 挂载到 `/data/home`，`subPath: share` 挂载到 `/share`
  - GPU 规格时附加 `nvidia.com/gpu` 资源限制及 nodeSelector/tolerations
- [x] **BE-23** 封装 K8S Service 创建/删除函数
- [x] **BE-24** 封装 K8S Ingress 创建/删除函数（含 WebSocket 所需 annotations）
- [x] **BE-25** 实现 NFS 目录初始化逻辑（通过临时 K8S Job 或 initContainer 执行 chown）

### 2.6 闲置检测定时任务

- [x] **BE-26** 注册 cron 任务（每 1 小时执行）
- [x] **BE-27** 实现 Kernel API 轮询逻辑：`GET http://{pod_ip}:8888/api/kernels`，携带 token
- [x] **BE-28** 实现闲置判断逻辑：所有 kernel 的 `last_activity` 距今 > 48h 且非 busy 状态
- [x] **BE-29** 实现 `idle_since` 记录与 48h 超时触发逻辑
- [x] **BE-30** 实现连续请求失败（3次）标记 status=failed 逻辑
- [x] **BE-31** 实现回收动作：删除 K8S 资源，更新 DB，写入系统操作日志

---

## 三、前端 — Vue

### 3.1 公共基础

- [x] **FE-1** 初始化 Vue 项目（Vite + TypeScript + Vue Router + Pinia）
- [x] **FE-2** 集成 UI 组件库（如 Element Plus）
- [x] **FE-3** 封装 Axios，实现 JWT 请求拦截和 401 自动跳转
- [x] **FE-4** 实现登录页面（账号密码，JWT 存 localStorage）

### 3.2 开发机管理页面

- [x] **FE-5** 实例列表页
  - 展示：实例状态、规格、镜像、创建时间、访问链接
  - 状态轮询：creating/stopping 状态下每 5 秒刷新一次
  - 操作按钮：进入、重启、停止
- [x] **FE-6** 创建实例弹窗
  - 规格套餐选择（单选卡片，展示 CPU/内存/GPU）
  - 镜像选择（下拉列表）
  - 提交后跳转至实例列表，进入 creating 轮询状态
- [x] **FE-7** 访问实例：点击"进入"按钮，新窗口打开 `https://platform.internal/jupyter/{token}`
- [x] **FE-8** 停止/重启实例的二次确认弹窗
- [x] **FE-9** 实例状态 Badge 样式（creating=蓝，running=绿，stopping=橙，stopped=灰，failed=红）

### 3.3 管理员页面

- [x] **FE-10** 规格套餐管理页（CRUD 表格 + 启用/禁用开关）
- [x] **FE-11** 用户管理页（创建用户，查看 UID，禁用/启用）

> 本期不实现镜像管理页面，镜像列表由后端配置文件维护。

---

## 四、本地测试环境搭建（Kind）

- [x] **KIND-1** 安装本地依赖工具：`kind`、`kubectl`、`helm`
- [x] **KIND-2** 编写 `hack/kind-cluster.yaml`（1控制面+3节点，extraPortMappings 映射 80/443）
- [x] **KIND-3** 执行 `kind create cluster --config hack/kind-cluster.yaml` 创建集群
- [x] **KIND-4** 安装 nginx Ingress Controller for Kind
- [x] **KIND-5** 创建 namespace `jupyter`
- [x] **KIND-6** 编写并部署 `hack/nfs-server.yaml`（NFS Server Deployment + Service + PV + PVC）
- [x] **KIND-7** 验证 `pvc-jupyter-shared` 状态为 Bound
- [x] **KIND-8** 配置本地 `/etc/hosts`，添加 `127.0.0.1 platform.internal`
- [x] **KIND-9** 手动创建测试 Pod，验证 NFS 挂载、权限隔离（`/data/home/{username}` chmod 700）、`/share` 读写
- [x] **KIND-10** 编写 `hack/Makefile` 或 shell 脚本，一键完成 KIND-1~KIND-8 的环境初始化

---

## 五、联调 & 测试

- [x] **QA-1** 基于 Kind 测试环境（见 KIND-* 任务）执行全流程验证
  - Playwright 验证：登录/登出、规格管理、用户管理、创建开发机全流程 ✓
  - 修复：JupyterLab 4.x 启动方式（NOTEBOOK_ARGS env var 替代废弃的 --NotebookApp.*）
  - 修复：Ingress 去掉 rewrite-target，改用 PathTypePrefix 保留完整路径
  - 前端代理：Vite 新增 /jupyter/ → http://platform.internal:8081 代理
  - Token 生成：改用 `guid.S()`（GoFrame `util/guid`），移除 `uuid` 依赖
- [x] **QA-2** 端到端流程验证：创建 → 访问 JupyterLab → Pod 运行中
  - 创建开发机 → pod 1/1 Running（0 restarts）→ 前端状态 运行中 ✓
  - http://localhost:3002/jupyter/{token}/lab?token={token} 正常加载 JupyterLab UI ✓
  - /home/admin 文件浏览器可见、NFS work 目录挂载正常 ✓
  - 数据持久化（停止→重建恢复）、停止流程待进一步验证
- [x] **QA-8** [NEW] JupyterLab 中运行训练代码验证
  - 在 JupyterLab 中新建 Python 3 Notebook，执行梯度下降线性回归训练  
  - 验证：训练收敛（w≈2.0，b≈0.0），无 AssertionError/Traceback 输出
  - 验证：输出 `TRAINING_TEST_PASSED`
- [x] **QA-9** [NEW] Bug 修复验证
  - 登录失败边界：输入错误密码 → 显示错误提示，页面不崩溃，留在登录页
  - 规格 CRUD：创建新规格后出现在管理列表，修改 CPU 后正确持久化
  - 用户 CRUD：创建新用户后出现在用户列表，禁用后状态变为禁用
  - 重复创建防护：有活跃实例时创建按钮禁用；API 返回错误码（非 0）
  - 不同镜像创建：选择 PyTorch 镜像创建开发机，实例列表显示正确镜像
  - 停止后清理：停止实例后"删除记录"按钮出现，删除后列表清空，创建按钮恢复可用
- [ ] **QA-3** 多用户权限隔离验证：用户 A 无法访问用户 B 的 `/home/jovyan`
- [x] **QA-4** `/share` 目录读写验证：多用户互相可读写（TC0009a~TC0009d）
- [ ] **QA-5** WebSocket 稳定性验证：JupyterLab kernel 通信、Terminal 长时间连接不断开
- [ ] **QA-6** 闲置检测联调：mock `last_activity` 超时，验证回收流程
- [ ] **QA-7** GPU 规格实例创建验证（需 GPU 节点）

---

## 六、测试用例明细

> 测试文件遵循 `openspec-e2e` 技能规范：每个测试案例一个文件，命名 `TC{NNNN}-{brief-name}.ts`。

### E2E — TC0001 登录验证
- 文件：`hack/tests/e2e/auth/TC0001-login-verification.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0001a | 登录后跳转到 /notebooks | QA-1 | 输入凭据后 URL 为 /notebooks |
| TC0001b | 侧边栏显示管理员菜单 | QA-1 | 页面包含"规格管理"菜单项 |
| TC0001c | 顶部显示用户名 | QA-1 | 页面包含"admin"用户名 |

### E2E — TC0002 规格管理
- 文件：`hack/tests/e2e/admin/TC0002-spec-management.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0002a | 规格管理页面标题 | QA-1 | 页面含"规格管理"文本 |
| TC0002b | CPU-小 规格存在 | QA-1 | 列表包含 CPU-小 |
| TC0002c | CPU-大 规格存在 | QA-1 | 列表包含 CPU-大 |
| TC0002d | GPU-标准 规格存在 | QA-1 | 列表包含 GPU-标准 |
| TC0002e | 规格编辑操作可见 | QA-1 | 列表含"编辑"按钮 |
| TC0002f | 创建规格后出现在列表 | QA-9 | 新规格 Test-CPU-E2E 在列表可见 |
| TC0002g | 修改规格 CPU 后更新成功 | QA-9 | 修改后 1000m 可见 |

### E2E — TC0003 用户管理
- 文件：`hack/tests/e2e/admin/TC0003-user-management.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0003a | 用户管理页面标题 | QA-1 | 页面含"用户管理"文本 |
| TC0003b | admin 用户存在 | QA-1 | 列表包含 admin |
| TC0003c | admin 用户状态正常 | QA-1 | 状态列显示"正常" |
| TC0003d | 创建新用户后出现在列表 | QA-9 | testuser01 在用户列表可见 |
| TC0003e | 禁用用户后状态变更 | QA-9 | testuser01 状态变为禁用 |
| TC0003f | 新增用户对话框不含 UID 字段 | FB-4 | 对话框中无 UID 输入项 |

### E2E — TC0004 创建开发机
- 文件：`hack/tests/e2e/notebook/TC0004-create-notebook.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0004a/b | 创建开发机后记录存在且状态正确 | QA-2 | 列表包含用户名，status ∈ {创建中, 运行中} |
| TC0004c | 有活跃实例时创建按钮禁用 | QA-9 | el-button disabled 属性为 true |
| TC0004d | API 拒绝重复创建开发机 | QA-9 | 后端返回非 0 code |

### E2E — TC0005 JupyterLab 访问
- 文件：`hack/tests/e2e/notebook/TC0005-jupyterlab-access.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0005a | Pod 1/1 Running | QA-2 | kubectl 120s 内 Pod Ready |
| TC0005b | 前端实例状态运行中 | QA-2 | 页面显示"运行中" |
| TC0005c | JupyterLab UI 加载成功 | QA-2 | 新标签页 jp-* DOM 元素数量 > 5 |
| TC0005d | 文件浏览器可见 | QA-2 | .jp-FileBrowser / .jp-BreadCrumbs 元素存在 |

### E2E — TC0006 训练代码执行
- 文件：`hack/tests/e2e/notebook/TC0006-training-execution.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0006a | 训练代码执行完成 | QA-8 | 输出含 TRAINING_TEST_PASSED |
| TC0006b | 训练代码无运行错误 | QA-8 | 不含 AssertionError/Traceback |
| TC0006c | 梯度下降收敛 | QA-8 | 输出包含 Trained: 行（断言通过即 w≈2.0） |

### E2E — TC0007 退出登录
- 文件：`hack/tests/e2e/auth/TC0007-logout.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0007a | 退出登录跳转 /login | QA-1 | URL 变为 /login |
| TC0007c | 登录表单可见 | QA-1 | 登录按钮文字可见（登 录） |
| TC0007d | 未登录访问保护路由重定向 | QA-1 | /notebooks → /login |
| TC0007e | 错误密码登录后留在登录页 | QA-9 | URL 保持 /login，不崩溃 |
| TC0007f | 错误密码显示错误提示 | QA-9 | Element Plus error toast 出现 |

### E2E — TC0008 不同镜像开发机创建
- 文件：`hack/tests/e2e/notebook/TC0008-multi-image-notebook.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0008b | 清除记录后创建按钮可用 | QA-9 | 按钮 disabled 为 false |
| TC0008c/d | PyTorch 镜像创建并显示正确 | QA-9 | 列表镜像列显示 PyTorch 或 pytorch-cuda121，状态为创建中或运行中 |

### E2E — TC0009 多用户共享目录
- 文件：`hack/tests/e2e/notebook/TC0009-shared-directory.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0009a | admin 在 /share 创建共享文件 | QA-4 | kubectl exec 写入 /share 成功并可读回 |
| TC0009b | testuser01 可见 /share 共享文件 | QA-4 | testuser01 Pod 中 cat admin 创建的文件内容正确 |
| TC0009c | testuser01 可在 /share 写入文件 | QA-4 | testuser01 Pod 中写入 /share 成功并可读回 |
| TC0009d | /share 包含两个用户的文件 | QA-4 | ls 验证 admin 和 testuser01 的文件同时存在 |

### E2E — TC0010 过期/无效 Token 自动跳转登录
- 文件：`hack/tests/e2e/auth/TC0010-expired-token-redirect.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0010a | 无效 token 访问 /notebooks 后跳转 /login | FB-2 | URL 变为 /login |
| TC0010b | 跳转后 localStorage token 已清除 | FB-2 | token 为空 |
| TC0010c | 过期 JWT token 访问后立即跳转 /login | FB-2 | 路由守卫解码 JWT 后跳转 |

### E2E — TC0011 对话框按钮中文化
- 文件：`hack/tests/e2e/admin/TC0011-dialog-chinese-buttons.ts`

| 编号 | 子断言 | 覆盖 QA | 验证点 |
|------|--------|---------|--------|
| TC0011a | 规格管理禁用确认对话框按钮为中文 | FB-3 | 不含 Cancel/OK，含取消 |
| TC0011b | 规格管理删除确认对话框按钮为中文 | FB-3 | 不含 Cancel/OK，含取消 |

> 最终执行结果（2026-03-05 全量 Bug 修复后）：**PASS=36 FAIL=0** — 全部 36 个测试用例通过 ✅
> （初版：PASS=24；后续 Bug 修复后新增 TC0007e/TC0007f、TC0002f/TC0002g、TC0003d/TC0003e、TC0004c/TC0004d、TC0008a~TC0008d 共 12 个，合计 36 个）
> [HF-1] 新增 TC0009a~TC0009d（多用户 /share 共享目录访问），合计 40 个
> [HF-2] 新增 TC0003f、TC0010a~TC0010c、TC0011a~TC0011b（Feedback FB-2/3/4 修复验证），合计 46 个



---

## Feedback

- [x] **FB-1**：现有 e2e 测试仅覆盖单用户（admin）场景，未验证不同用户登录各自开发机后能否查看 /share 目录下的共享文件
- [x] **FB-2**：JWT 过期后访问 /notebooks 等页面仍可正常展示，不会跳转登录页
  - 修复：在 `frontend/src/router/index.ts` 路由守卫中增加 `isTokenExpired()` 函数，解码 JWT payload 检查 `exp` 字段，过期时清除 auth 状态并跳转 /login
  - 测试：TC0010a~TC0010c（新增 TC0010c 过期 JWT 场景）
- [x] **FB-3**：ElMessageBox 确认对话框按钮显示英文 Cancel/OK，应统一为中文
  - 修复：为 `NotebookListView.vue`、`SpecManageView.vue`、`UserManageView.vue` 中所有 `ElMessageBox.confirm()` 调用显式传入 `confirmButtonText` 和 `cancelButtonText` 中文文本
  - 测试：TC0011a~TC0011b
- [x] **FB-4**：新增用户对话框中不应允许编辑 UID，UID 应由后端自动生成
  - 验证：代码已正确实现——表单无 UID 字段，后端自动生成 uid = 10000 + id
  - 测试：TC0003f
- [x] **FB-5**：将 NFS 用户目录初始化从独立 K8S Job（产生 init-home-xxx Pod）改为 jupyterlab Pod 的 initContainer，消除多余 Pod，并解决初始化与主容器启动的竞态条件
  - 修复：`backend/internal/service/k8s/pod.go` 中为 Pod spec 添加 `init-home` initContainer（busybox:1.36，以 root 运行，执行 mkdir/chown/chmod）
  - 修复：`backend/internal/service/notebook/notebook.go` 移除 `InitUserHomeDir` goroutine（步骤 7）
  - 修复：删除 `backend/internal/service/k8s/nfs_init.go`（K8S Job 逻辑不再需要）
  - 测试：无需新增 E2E 用例，现有 TC0004/TC0008 开发机创建流程覆盖；此为内部架构改进，`kubectl get pod` 不再出现 `init-home-*`

- [ ] **FB-6**：开发机创建异常时（CreatePod 失败、Pod 进入 Failed 状态、超时），删除 failed 状态记录不会清理 K8S 中已创建的 Pod/Service/Ingress，造成集群脏数据持续占用资源

---

## 依赖关系

```
INFRA-1,2,3 → BE-25 → BE-19
KIND-1~8    → 本地开发注册测试前完成
DB-1        → BE-1 (项目初始化后)
BE-3        → BE-22,23,24 → BE-19,20,21
BE-4        → 所有需要鉴权的接口
BE-13,14    → FE-6 (镜像选择由配置文件驱动)
BE-19       → FE-6
BE-17       → FE-5
FE-1~4      → FE-5~11
KIND-1~8    → QA-1~7
```
