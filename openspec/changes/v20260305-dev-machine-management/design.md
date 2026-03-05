# 开发机管理模块 — 设计文档

## 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                     Vue 前端                             │
│  实例管理 │ 规格套餐(管理员) │ 访问入口 │ 状态轮询        │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP / REST
┌────────────────────────▼────────────────────────────────┐
│                  GoFrame API Server                      │
│  ┌───────────┐  ┌──────────┐  ┌─────────┐  ┌────────┐  │
│  │ Instance  │  │  Spec    │  │  User   │  │  Cron  │  │
│  │   CRUD    │  │  Manager │  │  Auth   │  │(闲置检测)  │
│  └─────┬─────┘  └──────────┘  └─────────┘  └───┬────┘  │
│        │                                         │       │
│  ┌─────▼─────────────────────────────────────────▼────┐  │
│  │               K8S Client (client-go)               │  │
│  │       Pod / Service / Ingress 生命周期管理          │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                   Kubernetes Cluster                     │
│   namespace: jupyter                                    │
│                                                          │
│   ┌──────────────────────────────────────────────────┐  │
│   │  Pod: jupyterlab-{username}                       │  │
│   │    securityContext: runAsUser={uid}               │  │
│   │    /home/jovyan ← PVC subPath: data/home/{user}  │  │
│   │    /share       ← PVC subPath: share/            │  │
│   └──────────────────────────────────────────────────┘  │
│                                                          │
│   Service: svc-jupyterlab-{username}  (ClusterIP:8888)  │
│   Ingress: jupyter-{token}                              │
│     路由: /jupyter/{token}(/.*)? → Service:8888         │
│                                                          │
│   PVC: pvc-jupyter-shared  (RWX / NFS)                  │
└──────────────────────────────────────────────────────────┘
```

---

## 访问链路与 URL 设计

### 访问 URL 格式

```
https://platform.internal/jupyter/{token}
```

- `{token}` 同时作为路由 key 和 JupyterLab 认证凭证
- 分享链接即此 URL，无需额外权限验证（持有链接即可访问）
- 浏览器访问后由 JupyterLab 重定向到 `/jupyter/{token}/lab`

### 完整请求流程

```
Browser
  │  GET https://platform.internal/jupyter/{token}/lab
  ▼
Ingress (nginx)
  路由规则: /jupyter/([^/]+)(/.*)? → svc-jupyterlab-{username}:8888
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
  ▼
JupyterLab Pod (直连，nginx 转发)
  验证: token 匹配 → 放行
  base_url: /jupyter/{token}/
```

### K8S Ingress 资源示例

每个实例创建时动态生成一条 Ingress：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jupyter-{token}
  namespace: jupyter
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
spec:
  rules:
  - host: platform.internal
    http:
      paths:
      - path: /jupyter/{token}(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: svc-jupyterlab-{username}
            port:
              number: 8888
```

---

## K8S 资源管理

### 每个实例对应的 K8S 资源

| 资源类型 | 命名规则 | 说明 |
|---------|---------|------|
| Pod | `jupyterlab-{username}` | 开发机主体 |
| Service | `svc-jupyterlab-{username}` | ClusterIP，端口 8888 |
| Ingress | `jupyter-{token}` | 路由规则，按 token 标识 |
| PVC | `pvc-jupyter-shared` | 全局唯一，所有实例共享 |

创建实例 = 创建 Pod + Service + Ingress  
删除实例 = 删除 Pod + Service + Ingress（**PVC 永久保留**）

### Pod Spec 关键字段

> 参考内部测试案例，容器以 root 身份启动，由 jupyter 官方镜像的 `start.sh` 读取 `NB_UID`/`NB_GID` 完成用户切换，无需 securityContext.runAsUser。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: jupyterlab-{username}
  namespace: jupyter
  labels:
    app: jupyterlab-{username}
spec:
  containers:
  - name: jupyterlab
    image: {image.image}          # 来自后端配置文件
    imagePullPolicy: IfNotPresent
    command:
      - /bin/bash
      - -c
      - |
        set -e
        # 软链 NFS 用户目录到 /home/{username}
        ln -sf /data/home/{username} /home/{username}
        # 启动 JupyterLab（start.sh 负责切换到 NB_UID 用户）
        exec /usr/local/bin/start.sh start-notebook.sh
    securityContext:
      runAsUser: 0                # root 启动，start.sh 内部切换至 NB_UID
      runAsGroup: 0
    ports:
    - containerPort: 8888
      name: http
    env:
    - name: JUPYTER_ENABLE_LAB
      value: "yes"
    - name: JUPYTER_TOKEN
      value: "{token}"           # guid.S() 生成，来自 instances.token
    - name: JUPYTER_BASE_URL
      value: "/jupyter/{token}/" # 路由前缀，与 Ingress 路径匹配
    - name: NB_USER
      value: "{username}"
    - name: NB_UID
      value: "{uid}"             # 10000 + users.id
    - name: NB_GID
      value: "{uid}"
    resources:
      requests:
        cpu: "{spec.cpu}"
        memory: "{spec.memory}"
        # nvidia.com/gpu 仅 gpu > 0 时设置
      limits:
        cpu: "{spec.cpu}"
        memory: "{spec.memory}"
    livenessProbe:
      httpGet:
        path: /jupyter/{token}/lab
        port: 8888
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /jupyter/{token}/lab
        port: 8888
      initialDelaySeconds: 10
      periodSeconds: 5
    volumeMounts:
    - name: workspace
      mountPath: /data/home      # 挂载整个 home 目录区
      subPath: data/home
    - name: workspace
      mountPath: /share
      subPath: share
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: pvc-jupyter-shared
  nodeSelector: {spec.nodeSelector}   # GPU 节点亲和（无 GPU 时省略）
  tolerations: {spec.tolerations}
```

**关键说明：**

| 字段 | 说明 |
|------|------|
| `runAsUser: 0` | 容器以 root 启动，`start.sh` 内部读取 `NB_UID` 后切换非 root 用户运行 Jupyter |
| `NB_UID / NB_GID` | 来自平台分配的用户 UID（`10000 + users.id`），由后端创建 Pod 时注入 |
| `JUPYTER_TOKEN` | 来自 `instances.token`，即访问 URL 中的 `{token}`，认证与路由复用同一值 |
| `JUPYTER_BASE_URL` | 必须与 Ingress 路径前缀保持一致，否则 JupyterLab 静态资源路径错误 |
| `mountPath: /data/home` | 将 PVC 的 `data/home` subPath 挂载到容器，用户目录为 `/data/home/{username}` |
| 软链 | 启动脚本将 `/data/home/{username}` 软链至 `/home/{username}`，符合 jupyter 镜像约定 |

---

## 存储设计

### PV / PVC 配置

```yaml
# PersistentVolume（运维一次性创建）
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jupyter-pv
spec:
  capacity:
    storage: 100Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  mountOptions:
    - vers=3
    - rsize=1048576
    - wsize=1048576
    - hard
    - nolock
    - proto=tcp
  nfs:
    server: {nfs-server-host}
    path: /jupyter         # NFS 服务器上的根路径
---
# PersistentVolumeClaim（运维一次性创建）
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-jupyter-shared
  namespace: jupyter
spec:
  resources:
    requests:
      storage: 100Ti
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: jupyter-pv
```

### PVC 目录结构

```
PVC: pvc-jupyter-shared (RWX / NFS)
│
├── data/
│   └── home/
│       ├── zhangsan/    ← UID=10001, chmod 700
│       ├── lisi/        ← UID=10002, chmod 700
│       └── wangwu/      ← UID=10003, chmod 700
│
└── share/               ← chmod 1777 (所有用户可读写)
    ├── datasets/
    └── public/
```

### 目录初始化

用户首次创建实例时，后端通过 K8S Job（以 root 运行）初始化用户目录：

```bash
mkdir -p /data/data/home/{username}
chown {uid}:{uid} /data/data/home/{username}
chmod 700 /data/data/home/{username}
```

`/share` 目录在 NFS 服务器初始化时由运维一次性创建，chmod 1777（sticky bit，任何人可写但不能删他人文件）。

### 权限隔离

- 每个用户注册时分配固定 UID = `10000 + user.id`，存入 `users.uid`
- Pod 以 root 启动，`start.sh` 读取 `NB_UID` 后以用户 UID 运行 Jupyter 进程
- NFS 基于文件系统 UID 做权限控制，`/data/home/{username}` chmod 700 保证私有
- `/share` 使用 sticky bit，所有用户均可读写但不能删除他人文件

---

## 数据库设计

### users 表

```sql
CREATE TABLE `users` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(64)  NOT NULL,
  `password_hash` VARCHAR(256) NOT NULL COMMENT 'bcrypt',
  `uid`           INT UNSIGNED NOT NULL COMMENT '容器内 UID = 10000 + id',
  `email`         VARCHAR(128) DEFAULT NULL,
  `status`        TINYINT      NOT NULL DEFAULT 1 COMMENT '1=正常 0=禁用',
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### specs 表（规格套餐）

```sql
CREATE TABLE `specs` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`          VARCHAR(64)  NOT NULL COMMENT '如: CPU-小, GPU-标准',
  `description`   VARCHAR(256) DEFAULT NULL,
  `cpu`           VARCHAR(16)  NOT NULL COMMENT 'K8S 格式, 如: 4',
  `memory`        VARCHAR(16)  NOT NULL COMMENT 'K8S 格式, 如: 16Gi',
  `gpu`           VARCHAR(8)   NOT NULL DEFAULT '0' COMMENT 'GPU 数量',
  `gpu_type`      VARCHAR(64)  DEFAULT NULL COMMENT '如: nvidia.com/gpu',
  `node_selector` JSON         DEFAULT NULL COMMENT 'K8S nodeSelector',
  `tolerations`   JSON         DEFAULT NULL COMMENT 'K8S tolerations 数组',
  `enabled`       TINYINT      NOT NULL DEFAULT 1,
  `sort_order`    INT          NOT NULL DEFAULT 0,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 镜像配置文件（本期不入 DB）

镜像列表由后端配置文件维护，GoFrame 启动时读取并缓存，通过 `GET /api/image` 接口返回给前端。示例结构：

```yaml
images:
  - key: base-notebook
    name: "通用 Python 环境"
    image: "registry.internal/jupyter/base-notebook:2026-01"
    description: "Python 3.11，含常用科学计算库"
    enabled: true
  - key: pytorch-cuda121
    name: "PyTorch 2.2 + CUDA 12.1"
    image: "registry.internal/jupyter/pytorch-notebook:2.2-cuda12.1"
    description: "含 PyTorch、torchvision，适用于 GPU 实例"
    enabled: true
```

后续镜像管理模块上线后，可将此配置迁移至独立数据表，`GET /api/image` 接口无需改动。

### instances 表（开发机实例）

```sql
CREATE TABLE `instances` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`        INT UNSIGNED NOT NULL,
  `username`       VARCHAR(64)  NOT NULL COMMENT '冗余字段，便于查询',
  `pod_name`       VARCHAR(128) NOT NULL COMMENT 'jupyterlab-{username}',
  `spec_id`        INT UNSIGNED NOT NULL,
  `image_key`      VARCHAR(128) NOT NULL COMMENT '对应配置文件中的镜像 key',
  `image`          VARCHAR(256) NOT NULL COMMENT '创建时快照的完整镜像地址，防止配置变更影响历史记录',
  `token`          VARCHAR(128) NOT NULL COMMENT 'guid.S() 生成，用于 JupyterLab 认证和路由',
  `status`         VARCHAR(32)  NOT NULL DEFAULT 'creating'
                   COMMENT 'creating|running|stopping|stopped|failed',
  `pod_ip`         VARCHAR(64)  DEFAULT NULL,
  `node_name`      VARCHAR(128) DEFAULT NULL,
  `last_active_at` DATETIME     DEFAULT NULL COMMENT '最近一次检测到活跃的时间',
  `idle_since`     DATETIME     DEFAULT NULL COMMENT '首次检测到闲置的时间',
  `stopped_at`     DATETIME     DEFAULT NULL,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_token` (`token`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> **注意**：1 用户 1 实例的约束由应用层保证（创建前检查该用户是否有 `status IN ('creating','running','stopping')` 的实例），不使用 DB 唯一索引，以保留历史停止记录。

---

## 闲置检测

### 定时任务

- 调度周期：每 1 小时执行一次
- 单个 Goroutine 串行处理所有 running 实例

### 检测逻辑

```
每小时执行:

SELECT * FROM instances WHERE status = 'running'

for each instance:
  GET http://{pod_ip}:8888/api/kernels
  Header: Authorization: token {token}

  ├── 请求失败（连续 3 次）
  │     → 更新 status = 'failed'，记录系统日志

  ├── kernels 为空 OR 所有 kernel:
  │   execution_state != 'busy'
  │   AND now() - last_activity > 48h
  │     │
  │     ├── idle_since IS NULL → 设置 idle_since = NOW()
  │     └── idle_since IS NOT NULL
  │         AND now() - idle_since >= 48h
  │               → 触发自动回收（见下）

  └── 有活跃 kernel
        → last_active_at = NOW(), idle_since = NULL
```

### 回收动作

```
1. 更新 status = 'stopping'
2. 记录系统日志（who/when/reason=idle_timeout）
3. 调 K8S API:
   - 删除 Pod: jupyterlab-{username}
   - 删除 Service: svc-jupyterlab-{username}
   - 删除 Ingress: jupyter-{token}
4. 更新 status = 'stopped', stopped_at = NOW()
   idle_since = NULL

注：PVC subPath 数据永久保留，用户重建实例后可继续使用。
```

---

## 前端状态感知

前端通过**定时轮询**获取实例状态：

- 实例列表页：每 5 秒调用 `GET /api/instances` 接口
- 后端该接口实时调用 K8S API 查询 Pod 状态，与 DB 状态合并返回
- 实例处于 `creating` 状态时，前端显示进度动画直到状态变为 `running`

Pod 状态映射：

| K8S Pod Phase | DB Status | 前端显示 |
|--------------|-----------|---------|
| Pending | creating | 启动中 |
| Running (Ready) | running | 运行中 |
| - | stopping | 停止中 |
| - | stopped | 已停止 |
| Failed / Unknown | failed | 异常 |

---

## 镜像配置

本期镜像列表由后端配置文件或 DB `images` 表维护，管理员可通过管理接口增删改查。  
用户创建实例时从可用镜像中选择一个。  
后续平台新增镜像管理模块后，可直接复用 `images` 表。

---

## 用户认证

- 账号密码登录，密码使用 bcrypt 哈希存储
- 登录成功后颁发 JWT Token（存于 `Authorization: Bearer` Header）
- 预留 LDAP 扩展点：`users` 表增加 `auth_source` 字段区分本地账号与 LDAP

---

## UID 分配规则

```
uid = 10000 + users.id

user.id=1  → uid=10001
user.id=2  → uid=10002
...
user.id=999 → uid=10999
```

UID 在用户创建时自动计算写入，后续不变。

---

## 接口清单（后端）

> 路由单词统一使用**单数**形式。

### 用户认证
- `POST /api/auth/login` — 账号密码登录，返回 JWT
- `POST /api/auth/logout` — 登出

### 开发机
- `GET    /api/notebook` — 当前用户的实例（含实时状态）
- `POST   /api/notebook` — 创建开发机（选规格、选镜像）
- `GET    /api/notebook/{id}` — 实例详情
- `DELETE /api/notebook/{id}` — 手动停止并回收
- `POST   /api/notebook/{id}/restart` — 重启（保留数据）

### 规格套餐
- `GET    /api/spec` — 套餐列表（用户侧仅返回 enabled=1）
- `POST   /api/spec` — 新建套餐（管理员）
- `PUT    /api/spec/{id}` — 修改套餐（管理员）
- `DELETE /api/spec/{id}` — 删除套餐（管理员）

### 镜像配置（只读，本期无管理界面）
- `GET /api/image` — 镜像列表（来自后端配置文件，用于创建开发机时选择）

> 本期镜像列表由后端配置文件维护，不提供增删改接口。后续镜像管理模块上线后再扩展。

---

## 本地测试环境搭建（Kind）

生产环境使用真实 K8S 集群 + NFS。本地开发阶段使用 Kind（Kubernetes in Docker）搭建测试集群，用 NFS Server Pod 模拟共享存储。

### 环境依赖

| 工具 | 说明 |
|------|------|
| Docker | Kind 运行基础 |
| kind | `brew install kind` |
| kubectl | `brew install kubectl` |
| helm | `brew install helm`（安装 ingress 用） |

### 第一步：创建 Kind 集群

保存以下配置为 `hack/kind-cluster.yaml`：

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-cluster
nodes:
  - role: control-plane
    image: kindest/node:v1.27.3
    # 将本机 80/443 映射到 control-plane，供 Ingress 使用
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP

  - role: worker
    image: kindest/node:v1.27.3
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        name: node0

  - role: worker
    image: kindest/node:v1.27.3
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        name: node1

  - role: worker
    image: kindest/node:v1.27.3
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        name: node2
```

```bash
# 创建集群（约 2-5 分钟）
kind create cluster --config hack/kind-cluster.yaml

# 验证节点就绪
kubectl get nodes
# 预期: kind-cluster-control-plane + node0/node1/node2 均为 Ready
```

### 第二步：安装 nginx Ingress Controller

Kind 不内置 Ingress Controller，需手动安装：

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 等待 ingress-nginx 就绪（约1分钟）
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 第三步：创建 namespace

```bash
kubectl create namespace jupyter
```

### 第四步：模拟 NFS 存储（集群内 NFS Server）

Kind 节点运行在 Docker 内，无法直接使用宿主机 NFS。采用在集群内部署一个 NFS Server Pod 的方式模拟：

```yaml
# hack/nfs-server.yaml
---
# NFS Server Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-server
  namespace: jupyter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-server
  template:
    metadata:
      labels:
        app: nfs-server
    spec:
      containers:
      - name: nfs-server
        image: itsthenetwork/nfs-server-alpine:latest
        env:
        - name: SHARED_DIRECTORY
          value: /data
        ports:
        - containerPort: 2049
        securityContext:
          privileged: true
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        emptyDir: {}      # 测试用，Pod 重启数据丢失；生产用 hostPath 或真实 NFS
---
# NFS Server Service
apiVersion: v1
kind: Service
metadata:
  name: nfs-server
  namespace: jupyter
spec:
  selector:
    app: nfs-server
  ports:
  - port: 2049
    protocol: TCP
---
# PV（指向集群内 NFS Server）
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jupyter-pv
spec:
  capacity:
    storage: 10Gi        # 测试用小容量
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  nfs:
    server: nfs-server.jupyter.svc.cluster.local
    path: /
---
# PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-jupyter-shared
  namespace: jupyter
spec:
  resources:
    requests:
      storage: 10Gi
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: jupyter-pv
```

```bash
kubectl apply -f hack/nfs-server.yaml

# 等待 NFS Server 就绪
kubectl wait -n jupyter --for=condition=ready pod \
  --selector=app=nfs-server --timeout=60s

# 验证 PVC 绑定
kubectl get pvc -n jupyter
# 预期: pvc-jupyter-shared STATUS=Bound
```

### 第五步：加载本地镜像到 Kind

开发阶段使用本地构建的镜像时，需先导入 Kind：

```bash
# 加载 JupyterLab 测试镜像
kind load docker-image --name kind-cluster \
  jupyter/base-notebook:latest

# 加载后端 API Server 镜像（如果本地构建）
kind load docker-image --name kind-cluster \
  platform-api:dev
```

### 第六步：配置本地 hosts

```bash
# /etc/hosts 追加（用于本地 Ingress 访问）
echo "127.0.0.1  platform.internal" | sudo tee -a /etc/hosts
```

### 验证完整流程

```bash
# 1. 手动创建一个测试 JupyterLab Pod，验证 NFS 挂载和权限
kubectl apply -f hack/test-jupyter-pod.yaml -n jupyter

# 2. 查看 Pod 状态
kubectl get pod -n jupyter

# 3. 查看 Pod 日志，确认 start.sh 用户切换成功
kubectl logs -n jupyter jupyterlab-testuser

# 4. 通过 API Server 创建实例，验证动态 Ingress 生成
curl -X POST http://platform.internal/api/notebook \
  -H "Authorization: Bearer {jwt}" \
  -d '{"spec_id":1,"image_key":"base-notebook"}'

# 5. 检查 Ingress 是否创建
kubectl get ingress -n jupyter

# 6. 浏览器访问 http://platform.internal/jupyter/{token}
#    验证: JupyterLab 正常加载，Terminal 可用，/share 目录可读写
```

### 集群清理

```bash
# 删除整个测试集群
kind delete clusters kind-cluster

# 清理 hosts
sudo sed -i '' '/platform.internal/d' /etc/hosts
```

### 测试环境 vs 生产环境对照

| 项目 | 本地测试（Kind） | 生产（真实集群） |
|------|----------------|----------------|
| K8S 集群 | Kind（Docker 内） | 物理/云 K8S |
| NFS 存储 | 集群内 NFS Server Pod（emptyDir） | 外部 NFS 服务器 |
| Ingress | nginx ingress for Kind | nginx ingress（已有） |
| 镜像拉取 | kind load docker-image | 私有 Registry |
| GPU | 不支持（跳过 GPU 套餐测试） | nvidia device plugin |
| 数据持久化 | Pod 重启后丢失（emptyDir） | NFS 持久化 | 
