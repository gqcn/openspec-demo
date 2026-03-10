# 开发机管理模块 — 任务拆解

## 任务状态说明
- [ ] 未开始
- [x] 已完成

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

## Feedback

- [x] **FB-1**：现有 e2e 测试仅覆盖单用户（admin）场景，未验证不同用户登录各自开发机后能否查看 /share 目录下的共享文件
- [x] **FB-2**：规格管理列表和用户管理列表缺少分页组件，数据量大时无法翻页
  - 修复：后端 spec/user list API 增加 page/size 参数与 total 返回；前端 SpecManageView、UserManageView 添加 `el-pagination` 组件
  - 测试：TC0016a~TC0016e（分页组件可见、API 返回 total 字段、分页参数生效）
- [x] **FB-3**：规格管理列表后端 SpecItem 未返回 createdAt 字段，前端表格创建时间列为空
  - 修复：`api/spec/v1/list.go` SpecItem 增加 `CreatedAt string`；controller 映射 `Format("Y-m-d H:i:s")`
  - 测试：TC0016c（规格管理列表创建时间列有数据）
- [x] **FB-4**：创建用户时若 username 与已软删除用户重复，应使用 Unscoped 绕过软删除过滤进行唯一性检查，避免 INSERT 触发唯一索引冲突
  - 修复：`user.Create()` 重复检查改用 `dao.Users.Ctx(ctx).TX(tx).Unscoped().Where(...)` 含已删除用户
  - 测试：TC0017a（创建→删除→再创建同名用户返回友好错误而非 SQL 异常）
- [x] **FB-5**：开发机 Pod 未设置 NB_USER 环境变量且 home 挂载到 /home/jovyan，导致 Terminal 显示 jovyan 而非真实用户名，home 路径应当为 /home/{username}
  - 修复：`pod.go` 增加 `NB_USER` 环境变量；启动命令增加 `ln -sfn /data/home/{username} /home/{username}`；volume mount 改为 `/data/home`
  - 测试：TC0018a~TC0018d（NB_USER 环境变量、/home/admin 软链、passwd 中用户记录）
  - 回归修复：TC0013 `/home/jovyan` → `/home/admin` 路径更新
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
- [x] **FB-7**：用户名未校验 Linux 用户名格式（`^[a-z_][a-z0-9_-]{0,31}$`），允许纯数字或含非法字符的用户名，导致 K8S Pod 内 `groupadd` / `useradd` 报错崩溃
  - 修复：`backend/internal/service/user/user.go` 中 `Create()` 冒头增加正则校验，不符合格式返回错误
  - 修复：`frontend/src/views/UserManageView.vue` 用户名 rules 增加 `pattern` 正则验证，前端即时拦截
  - 测试：TC0003g（前端表单拦截非法用户名）、TC0003h（后端 API 拒绝非法用户名并接受合法用户名）
- [x] **FB-8**：Pod Phase=Running 但容器 Ready=0/1 时，后端将实例状态提前标记为 running，前端显示"运行中"与实际可用性不符
  - 修复：`backend/internal/service/k8s/pod.go` `GetPodStatus` 增加容器 Ready 检查，Phase=Running 且 ContainerStatuses 全部 Ready 才返回 `"Running"`，否则返回 `"Pending"`
- [x] **FB-9**：主容器 CHOWN_HOME 在 NFS 挂载上递归 chown 导致启动缓慢（0/1 状态持续时间过长），应由 initContainer 负责 chown 并移除 CHOWN_HOME 相关环境变量
  - 修复：`pod.go` 移除主容器 `NB_USER`、`CHOWN_HOME`、`CHOWN_HOME_OPTS` 环境变量；ReadinessProbe `InitialDelaySeconds` 10→30 避免过早 probe 失败
- [x] **FB-10**：主容器挂载 subPath 错误（`data/home` → `/data/home`），JupyterLab 将文件写入容器本地 `/home/jovyan` 而非 NFS，重启后文件丢失；应将 `data/home/{username}` 直接挂载到 `/home/jovyan`
  - 修复：`pod.go` 主容器 VolumeMounts 改为 `MountPath: "/home/jovyan"`，`SubPath: fmt.Sprintf("%s/%s", consts.NFSHomeSubPath, opts.Username)`
  - 测试：TC0013（重启后 `/home/jovyan` 文件持久化验证）
- [x] **FB-11**：所有页面 HTML title 均显示 "frontend"，应根据路由动态设置中文标题
  - 修复：`frontend/src/router/index.ts` 各路由添加 `meta.title`，`beforeEach` 中设置 `document.title`；`frontend/index.html` 默认 title 改为"AI 训练平台"
  - 测试：TC0001d（登录页 title）、TC0001e（开发机页 title）
- [x] **FB-12**：Pod 探针 PeriodSeconds 过长（就绪探针 10s、存活探针 20s），导致 0/1 状态检测延迟，应调整为 5 秒一次
  - 修复：`backend/internal/service/k8s/pod.go` LivenessProbe PeriodSeconds 20→5，ReadinessProbe PeriodSeconds 10→5
- [x] **FB-13**：开发机状态刷新仅在 creating/stopping 状态下轮询，running 状态停止轮询；应扩展为 running 状态也持续刷新（5 秒一次）
  - 修复：`frontend/src/views/NotebookListView.vue` `needsPolling()` 增加 `'running'` 判断
- [x] **FB-14**：用户管理缺少编辑功能，无法修改用户角色（isAdmin）和密码
  - 修复：后端新增 `PUT /user/{id}` 接口（UpdateReq/UpdateRes）；前端用户管理页增加编辑对话框，支持修改角色和密码
  - 测试：TC0014（TC0014a~TC0014e）
- [x] **FB-15**：用户管理缺少删除功能；删除应实现为软删除（deleted_at 字段），删除后列表不可见
  - 修复：数据库 users 表新增 `deleted_at DATETIME DEFAULT NULL`；后端新增 `DELETE /user/{id}` 软删除接口；List/GetById/Login 均过滤 deleted_at IS NULL；前端增加删除按钮
  - 测试：TC0015（TC0015a~TC0015d）
- [x] **FB-16**：用户列表创建时间列无数据显示（UserItem 响应结构缺少 createdAt 字段）
  - 修复：`api/user/v1/user.go` UserItem 增加 `CreatedAt string`；controller List 映射 `u.CreatedAt.Format("Y-m-d H:i:s")`
  - 测试：TC0003i
- [x] **FB-17**：`entity.User` / `do.User` 缺少 `deleted_at` 字段，GoFrame ORM 软删除特性未激活 —— 所有 `AND deleted_at IS NULL` 条件散落在 service 与 auth 中手动维护（共 5 处），`user.Delete()` 也需手动执行 UPDATE 而非 ORM 自动处理
  - 修复：`entity/users.go` + `do/users.go` 添加 `DeletedAt` 字段；删除 `user.go` / `auth.go` 中全部手动 `deleted_at IS NULL` 条件；`user.Delete()` 改为 ORM 标准 `Delete()`
- [x] **FB-18**：`user.Create()` 先 INSERT 再 UPDATE uid 两步操作未包裹事务，若 UPDATE 失败将残留 `uid=0` 的僵尸记录
  - 修复：`user.Create()` 整体包裹 `dao.Users.Transaction()`，INSERT + UPDATE uid 在同一事务中原子执行
- [x] **FB-19**：`spec.Delete()` 执行物理硬删除且无引用检查，若规格仍被实例引用则 `spec_id` 成悬空引用
  - 修复：`spec.Delete()` 先查询 `dao.Instances` 是否存在对该 `spec_id` 的引用，存在则返回业务错误拒绝删除
- [x] **FB-20**：`spec_v1_handlers.go` 内联提取当前用户的逻辑重复，应提取为 `model.GetContextUser(ctx)` 辅助函数
  - 修复：`model/context.go` 新增 `GetContextUser(ctx)` 函数；`spec_v1_handlers.go` 和 `notebook_v1_handlers.go` 均改用该函数，移除各自的内联提取逻辑
- [x] **FB-21**：`notebook.Create()` 后台 goroutine 使用 `context.Background()` 丢失链路追踪信息，应改用 `context.WithoutCancel(ctx)`
  - 修复：`notebook.go` goroutine 内 `bgCtx := context.Background()` 改为 `bgCtx := context.WithoutCancel(ctx)`

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
