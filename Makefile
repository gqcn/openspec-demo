.PHONY: kind-setup kind-teardown kind-status k8s-load k8s-preload dev stop status test up

CLUSTER_NAME  := kind-cluster
NAMESPACE     := jupyter
BACKEND_DIR   := apps/backend
FRONTEND_DIR  := apps/frontend
BACKEND_BIN   := $(BACKEND_DIR)/bin/platform
PID_DIR       := /tmp/platform-pids
BACKEND_PID   := $(PID_DIR)/backend.pid
FRONTEND_PID  := $(PID_DIR)/frontend.pid
FRONTEND_PORT := 3002
BACKEND_PORT  := 8080


## 依赖Claude Code，自动生成 commit message 并提交到远程仓库
up:
	@if git diff --quiet HEAD && git diff --cached --quiet && [ -z "$$(git ls-files --others --exclude-standard)" ]; then \
		echo "No changes to commit"; \
		exit 0; \
	fi
	@git add -A
	@echo "Analyzing changes and generating commit message via AI..."
	@set -e; \
	MSG=$$(git diff --cached --stat && echo "---" && git diff --cached | head -2000 | \
		claude -p "Analyze the git diff above and generate a concise commit message (single line, max 72 chars, lowercase, no quotes). Output only the commit message itself, nothing else." \
		--model haiku) || { echo "Error: Claude command failed"; exit 1; }; \
	COMMIT_MSG=$$(echo "$$MSG" | tail -1); \
	if [ -z "$$COMMIT_MSG" ]; then \
		echo "Error: Failed to generate commit message"; \
		exit 1; \
	fi; \
	echo "Commit: $$COMMIT_MSG"; \
	git commit -m "$$COMMIT_MSG" && \
	git push origin


## dev: 启动前后端开发服务器，并打印访问地址
dev:
	@mkdir -p $(PID_DIR)
	@# ── 停掉旧进程 ──────────────────────────────────────────────
	@if [ -f $(BACKEND_PID) ]; then kill $$(cat $(BACKEND_PID)) 2>/dev/null || true; fi
	@if [ -f $(FRONTEND_PID) ]; then kill $$(cat $(FRONTEND_PID)) 2>/dev/null || true; fi
	@# ── 编译后端 ────────────────────────────────────────────────
	@echo "正在编译后端..."
	@cd $(BACKEND_DIR) && go build -o bin/platform . || { echo "后端编译失败"; exit 1; }
	@echo "✓ 后端编译成功"
	@# ── 启动后端 ────────────────────────────────────────────────
	@cd $(BACKEND_DIR) && ./bin/platform >> /tmp/backend.log 2>&1 & echo $$! > $(BACKEND_PID)
	@sleep 1
	@# ── 启动前端 ────────────────────────────────────────────────
	@cd $(FRONTEND_DIR) && npx turbo run dev --filter=@vben/web-antd >> /tmp/frontend.log 2>&1 & echo $$! > $(FRONTEND_PID)
	@sleep 2
	@echo ""
	@echo "╔══════════════════════════════════════════════╗"
	@echo "║         AI Training Platform - Dev           ║"
	@echo "╠══════════════════════════════════════════════╣"
	@echo "║  前端地址:  http://localhost:$(FRONTEND_PORT)            ║"
	@echo "║  后端地址:  http://localhost:$(BACKEND_PORT)            ║"
	@echo "║  后端日志:  /tmp/backend.log                 ║"
	@echo "║  前端日志:  /tmp/frontend.log                ║"
	@echo "╚══════════════════════════════════════════════╝"
	@echo ""

## stop: 停止前后端开发服务器
stop:
	@echo "正在停止服务..."
	@if lsof -ti :$(BACKEND_PORT) >/dev/null 2>&1; then \
		kill $$(lsof -ti :$(BACKEND_PORT)) 2>/dev/null; rm -f $(BACKEND_PID); echo "✓ 后端已停止"; \
	else \
		rm -f $(BACKEND_PID); echo "  后端未在运行"; \
	fi
	@if lsof -ti :$(FRONTEND_PORT) >/dev/null 2>&1; then \
		kill $$(lsof -ti :$(FRONTEND_PORT)) 2>/dev/null; rm -f $(FRONTEND_PID); echo "✓ 前端已停止"; \
	else \
		rm -f $(FRONTEND_PID); echo "  前端未在运行"; \
	fi

## status: 查看前后端运行状态及日志路径
status:
	@echo ""
	@echo "╔══════════════════════════════════════════════╗"
	@echo "║         AI Training Platform - Status        ║"
	@echo "╠══════════════════════════════════════════════╣"
	@if lsof -ti :$(BACKEND_PORT) >/dev/null 2>&1; then \
		echo "║  后端: ✓ 运行中  http://localhost:$(BACKEND_PORT)       ║"; \
	else \
		echo "║  后端: ✗ 未运行  (端口 $(BACKEND_PORT))                 ║"; \
	fi
	@if lsof -ti :$(FRONTEND_PORT) >/dev/null 2>&1; then \
		echo "║  前端: ✓ 运行中  http://localhost:$(FRONTEND_PORT)       ║"; \
	else \
		echo "║  前端: ✗ 未运行  (端口 $(FRONTEND_PORT))                 ║"; \
	fi
	@echo "╠══════════════════════════════════════════════╣"
	@echo "║  后端日志:  /tmp/backend.log                 ║"
	@echo "║  前端日志:  /tmp/frontend.log                ║"
	@echo "╚══════════════════════════════════════════════╝"
	@echo ""


## kind-setup: 一键初始化本地 Kind 测试环境（Steps 1-6）
kind-setup:
	@bash hack/setup-kind.sh

## kind-teardown: 销毁 Kind 集群并清理 hosts
kind-teardown:
	kind delete clusters $(CLUSTER_NAME)
	@sudo sed -i '' '/platform.internal/d' /etc/hosts 2>/dev/null || true
	@echo "✅ Kind 集群已删除，hosts 已清理"

## kind-status: 查看集群节点和存储状态
kind-status:
	@echo "=== Nodes ==="
	kubectl get nodes
	@echo ""
	@echo "=== Namespace: $(NAMESPACE) ==="
	kubectl get pod,svc,pvc,ingress -n $(NAMESPACE)

## k8s-load: 将本地 Docker 镜像加载到 Kind 集群
## 用法: make k8s-load IMAGE=myimage:tag
k8s-load:
	kind load docker-image --name $(CLUSTER_NAME) $(IMAGE)

# 开发机容器镜像列表（与 backend/manifest/config/config.yaml 中 notebook.images 保持同步）
NOTEBOOK_IMAGES := quay.io/jupyter/base-notebook:latest

## k8s-preload: 将本地 Docker 中的开发机镜像同步到 Kind 集群（加快 Pod 创建速度，E2E 测试前必须执行）
k8s-preload:
	@echo "� 检查 NFS 挂载配置..."
	@NFS_CURRENT=$$(kubectl -n $(NAMESPACE) get pod -l app=nfs-server \
	  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null); \
	NFS_PV=$$(kubectl get pv jupyter-pv -o jsonpath='{.spec.nfs.server}' 2>/dev/null); \
	if [ -n "$$NFS_CURRENT" ] && [ "$$NFS_CURRENT" != "$$NFS_PV" ]; then \
		echo "  ⚠️  NFS IP 漂移（PV: $$NFS_PV → 当前: $$NFS_CURRENT），重建 PV/PVC..."; \
		kubectl -n $(NAMESPACE) get pods --no-headers 2>/dev/null \
		  | grep -E '^(jupyterlab-|init-home-)' | awk '{print $$1}' \
		  | xargs -r kubectl -n $(NAMESPACE) delete pod --force --grace-period=0 \
		    --ignore-not-found 2>/dev/null || true; \
		kubectl -n $(NAMESPACE) delete pvc pvc-jupyter-shared --ignore-not-found 2>/dev/null || true; \
		kubectl delete pv jupyter-pv --ignore-not-found 2>/dev/null || true; \
		sed "s/NFS_SERVER_IP/$$NFS_CURRENT/g" hack/nfs-server.yaml | kubectl apply -f - 2>/dev/null || true; \
		echo "  ✓ PV/PVC 已重建（NFS: $$NFS_CURRENT）"; \
	else \
		echo "  ✓ NFS IP 正常（$$NFS_PV）"; \
	fi
	@echo "🧹 清理残留的 Jupyter Pod..."
	@kubectl -n $(NAMESPACE) get pods --no-headers 2>/dev/null \
	  | grep -E '^(jupyterlab-|init-home-)' | awk '{print $$1}' \
	  | xargs -r kubectl -n $(NAMESPACE) delete pod --force --grace-period=0 \
	    --ignore-not-found 2>/dev/null || true
	@echo "�🚀 同步开发机镜像到 Kind 集群..."
	@for image in $(NOTEBOOK_IMAGES); do \
		if docker image inspect $$image >/dev/null 2>&1; then \
			echo "  加载 $$image..."; \
			kind load docker-image --name $(CLUSTER_NAME) $$image; \
			echo "  ✓ $$image 已加载"; \
		else \
			echo "  ⚠️  $$image 在本地 Docker 中不存在，跳过（可先执行: docker pull $$image）"; \
		fi; \
	done
	@echo "✅ 镜像同步完成"

## test: 将开发机镜像预加载到 Kind 集群，然后运行完整 E2E 测试套件
test: k8s-preload
	@echo "🧪 运行 E2E 测试套件..."
	cd hack/tests && npx playwright test

## db-migrate: 执行数据库初始化 SQL（依赖 MySQL 已启动）
## 用法: make db-migrate DSN="root:password@tcp(127.0.0.1:3306)/platform"
db-migrate:
	mysql -h 127.0.0.1 -u root -p platform < backend/manifest/sql/init.sql
	mysql -h 127.0.0.1 -u root -p platform < backend/manifest/sql/seed.sql

## help: 显示帮助信息
help:
	@grep -E '^##' Makefile | sed 's/## //'
