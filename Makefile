.PHONY: kind-setup kind-teardown kind-status k8s-load

CLUSTER_NAME := kind-cluster
NAMESPACE    := jupyter

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
