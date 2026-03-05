#!/usr/bin/env bash
# setup-kind.sh — 一键初始化本地 Kind 测试环境
# 使用方法: bash hack/setup-kind.sh
set -euo pipefail

CLUSTER_NAME="kind-cluster"
NAMESPACE="jupyter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------------
# 工具检查
# -------------------------------------------------------
check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ 未找到 $1，请先安装: $2"
    exit 1
  fi
}

check_tool kind   "brew install kind"
check_tool kubectl "brew install kubectl"
check_tool helm   "brew install helm"

echo "✅ 依赖工具检查通过"

# -------------------------------------------------------
# Step 1: 创建 Kind 集群
# -------------------------------------------------------
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "⚠️  Kind 集群 '${CLUSTER_NAME}' 已存在，跳过创建"
else
  echo "🚀 创建 Kind 集群..."
  kind create cluster --config "${SCRIPT_DIR}/kind-cluster.yaml"
  echo "✅ Kind 集群创建完成"
fi

# -------------------------------------------------------
# Step 2: 安装 nginx Ingress Controller (for Kind)
# -------------------------------------------------------
echo "🚀 安装 nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ 等待 ingress-nginx 就绪（最多 90 秒）..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
echo "✅ nginx Ingress Controller 就绪"

# -------------------------------------------------------
# Step 3: 创建 namespace
# -------------------------------------------------------
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "✅ namespace '${NAMESPACE}' 就绪"

# -------------------------------------------------------
# Step 4: 部署集群内 NFS Server 并创建 PV/PVC
# -------------------------------------------------------
echo "🚀 部署 NFS Server 及存储资源..."
kubectl apply -f "${SCRIPT_DIR}/nfs-server.yaml"

echo "⏳ 等待 NFS Server 就绪（最多 60 秒）..."
kubectl wait -n "${NAMESPACE}" \
  --for=condition=ready pod \
  --selector=app=nfs-server \
  --timeout=60s

echo "⏳ 等待 PVC 绑定..."
for i in $(seq 1 30); do
  STATUS=$(kubectl get pvc pvc-jupyter-shared -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [ "$STATUS" = "Bound" ]; then
    echo "✅ PVC pvc-jupyter-shared 已绑定"
    break
  fi
  echo "  等待中... (${i}/30)"
  sleep 3
done

# -------------------------------------------------------
# Step 5: 初始化 /share 目录权限
# -------------------------------------------------------
echo "🚀 初始化 /share 目录..."
kubectl run nfs-init --restart=Never --rm -i \
  --image=busybox \
  --namespace="${NAMESPACE}" \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "nfs-init",
        "image": "busybox",
        "command": ["sh", "-c", "mkdir -p /data/share && chmod 1777 /data/share && echo done"],
        "volumeMounts": [{"name": "workspace", "mountPath": "/data"}]
      }],
      "volumes": [{"name": "workspace", "persistentVolumeClaim": {"claimName": "pvc-jupyter-shared"}}]
    }
  }' -- sh -c "mkdir -p /data/share && chmod 1777 /data/share && echo 'done'" 2>/dev/null || true
echo "✅ /share 目录初始化完成"

# -------------------------------------------------------
# Step 6: 配置本地 hosts
# -------------------------------------------------------
if grep -q "platform.internal" /etc/hosts 2>/dev/null; then
  echo "⚠️  /etc/hosts 中已有 platform.internal，跳过"
else
  echo "🚀 添加本地 hosts 记录（需要 sudo）..."
  echo "127.0.0.1  platform.internal" | sudo tee -a /etc/hosts
  echo "✅ hosts 配置完成"
fi

echo ""
echo "🎉 Kind 测试环境初始化完成！"
echo ""
echo "集群信息:"
kubectl get nodes
echo ""
echo "存储状态:"
kubectl get pvc -n "${NAMESPACE}"
echo ""
echo "访问地址: http://platform.internal"
