# 开发机管理模块 — 任务拆解

## 任务状态说明
- [ ] 未开始
- [x] 已完成

---

## 一、基础设施 & 数据库

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
- [ ] **QA-3** 多用户权限隔离验证：用户 A 无法访问用户 B 的 `/home/jovyan`
- [ ] **QA-4** `/share` 目录读写验证：多用户互相可读写
- [ ] **QA-5** WebSocket 稳定性验证：JupyterLab kernel 通信、Terminal 长时间连接不断开
- [ ] **QA-6** 闲置检测联调：mock `last_activity` 超时，验证回收流程
- [ ] **QA-7** GPU 规格实例创建验证（需 GPU 节点）

---

## 六、测试用例明细

> 测试脚本：`hack/tests/e2e-test.sh`（playwright-cli）

| 编号 | 测试用例 | 覆盖 QA | 验证点 |
|------|---------|---------|--------|
| TC-1a | 登录后跳转到 /notebooks | QA-1 | 输入凭据后 URL 为 /notebooks |
| TC-1b | 侧边栏显示管理员菜单 | QA-1 | 页面包含"规格管理"菜单项 |
| TC-1c | 顶部显示用户名 | QA-1 | 页面包含"admin"用户名 |
| TC-2a | 规格管理页面标题 | QA-1 | 页面含"规格管理"文本 |
| TC-2b | CPU-小 规格存在 | QA-1 | 列表包含 CPU-小 |
| TC-2c | CPU-大 规格存在 | QA-1 | 列表包含 CPU-大 |
| TC-2d | GPU-标准 规格存在 | QA-1 | 列表包含 GPU-标准 |
| TC-2e | 规格编辑操作可见 | QA-1 | 列表含"编辑"按钮 |
| TC-3a | 用户管理页面标题 | QA-1 | 页面含"用户管理"文本 |
| TC-3b | admin 用户存在 | QA-1 | 列表包含 admin |
| TC-3c | admin 用户状态正常 | QA-1 | 状态列显示"正常" |
| TC-4a | 创建开发机记录存在 | QA-2 | 列表包含当前用户名 |
| TC-4b | 实例状态为创建中或运行中 | QA-2 | status ∈ {创建中, 运行中} |
| TC-5a | Pod 1/1 Running | QA-2 | kubectl 120s 内 Pod Ready |
| TC-5b | 前端实例状态运行中 | QA-2 | 页面显示"运行中" |
| TC-5c | JupyterLab UI 加载成功 | QA-2 | 新标签页 jp-* DOM 元素数量 > 5 |
| TC-5d | 文件浏览器可见 | QA-2 | .jp-FileBrowser / .jp-BreadCrumbs 元素存在 |
| TC-6a | 训练代码执行完成 | QA-8 | 输出含 TRAINING_TEST_PASSED |
| TC-6b | 训练代码无运行错误 | QA-8 | 不含 AssertionError/Traceback |
| TC-6c | 梯度下降收敛 | QA-8 | 输出包含 Trained: 行（断言通过即 w≈2.0） |
| TC-7a | 退出登录跳转 /login | QA-1 | URL 变为 /login |
| TC-7b | 退出成功提示 | QA-1 | 页面含“已退出登录” |
| TC-7c | 登录表单可见 | QA-1 | 登录按鈕文字可见（登 录） |
| TC-7d | 未登录访问保护路由重定向 | QA-1 | /notebooks → /login |

> 最终执行结果（2026-03-05）：**PASS=24 FAIL=0** — 全郡 24 个测试用例全部通过 ✅



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
