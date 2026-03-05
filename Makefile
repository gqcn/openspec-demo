.PHONY: kind-setup kind-teardown kind-status k8s-load dev stop status

CLUSTER_NAME  := kind-cluster
NAMESPACE     := jupyter
BACKEND_DIR   := backend
FRONTEND_DIR  := frontend
BACKEND_BIN   := $(BACKEND_DIR)/bin/platform
PID_DIR       := /tmp/platform-pids
BACKEND_PID   := $(PID_DIR)/backend.pid
FRONTEND_PID  := $(PID_DIR)/frontend.pid
FRONTEND_PORT := 3002
BACKEND_PORT  := 8080

## dev: 启动前后端开发服务器，并打印访问地址
dev:
	@mkdir -p $(PID_DIR)
	@# ── 停掉旧进程 ──────────────────────────────────────────────
	@if [ -f $(BACKEND_PID) ]; then kill $$(cat $(BACKEND_PID)) 2>/dev/null || true; fi
	@if [ -f $(FRONTEND_PID) ]; then kill $$(cat $(FRONTEND_PID)) 2>/dev/null || true; fi
	@# ── 启动后端 ────────────────────────────────────────────────
	@cd $(BACKEND_DIR) && ./bin/platform >> /tmp/backend.log 2>&1 & echo $$! > $(BACKEND_PID)
	@sleep 1
	@# ── 启动前端 ────────────────────────────────────────────────
	@cd $(FRONTEND_DIR) && npx vite --port $(FRONTEND_PORT) --strictPort >> /tmp/frontend.log 2>&1 & echo $$! > $(FRONTEND_PID)
	@sleep 2
	@echo ""
	@echo "╔══════════════════════════════════════════════╗"
	@echo "║         AI Training Platform - Dev           ║"
	@echo "╠══════════════════════════════════════════════╣"
	@echo "║  前端地址:  http://localhost:$(FRONTEND_PORT)           ║"
	@echo "║  后端地址:  http://localhost:$(BACKEND_PORT)           ║"
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
		echo "║  后端: ✓ 运行中  http://localhost:$(BACKEND_PORT)      ║"; \
	else \
		echo "║  后端: ✗ 未运行  (端口 $(BACKEND_PORT))                ║"; \
	fi
	@if lsof -ti :$(FRONTEND_PORT) >/dev/null 2>&1; then \
		echo "║  前端: ✓ 运行中  http://localhost:$(FRONTEND_PORT)     ║"; \
	else \
		echo "║  前端: ✗ 未运行  (端口 $(FRONTEND_PORT))               ║"; \
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

## db-migrate: 执行数据库初始化 SQL（依赖 MySQL 已启动）
## 用法: make db-migrate DSN="root:password@tcp(127.0.0.1:3306)/platform"
db-migrate:
	mysql -h 127.0.0.1 -u root -p platform < backend/manifest/sql/init.sql
	mysql -h 127.0.0.1 -u root -p platform < backend/manifest/sql/seed.sql

## help: 显示帮助信息
help:
	@grep -E '^##' Makefile | sed 's/## //'
