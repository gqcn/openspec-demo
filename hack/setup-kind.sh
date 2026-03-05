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
# 先部署 Deployment + Service（不含 PV/PVC）
kubectl apply -f "${SCRIPT_DIR}/nfs-server.yaml"

echo "⏳ 等待 NFS Server 就绪（最多 90 秒）..."
kubectl wait -n "${NAMESPACE}" \
  --for=condition=ready pod \
  --selector=app=nfs-server \
  --timeout=90s

# 获取 NFS Server Pod IP（kubelet 挂载 NFS 需直接用 Pod IP，集群内 DNS 在节点网络不可用）
echo "🔍 获取 NFS Server Pod IP..."
NFS_SERVER_IP=""
for i in $(seq 1 30); do
  NFS_SERVER_IP=$(kubectl get pod -n "${NAMESPACE}" -l app=nfs-server \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")
  if [[ -n "${NFS_SERVER_IP}" ]]; then
    echo "✅ NFS Server IP: ${NFS_SERVER_IP}"
    break
  fi
  echo "  等待 IP 分配... (${i}/30)"
  sleep 2
done

if [[ -z "${NFS_SERVER_IP}" ]]; then
  echo "❌ 无法获取 NFS Server Pod IP，请检查 NFS 部署状态"
  exit 1
fi

# 创建 PV/PVC（用实际 Pod IP 替换占位符）
echo "🚀 创建 PVC（NFS server: ${NFS_SERVER_IP}）..."
kubectl delete pvc pvc-jupyter-shared -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
kubectl delete pv jupyter-pv --ignore-not-found 2>/dev/null
sed "s/NFS_SERVER_IP/${NFS_SERVER_IP}/g" "${SCRIPT_DIR}/nfs-server.yaml" | \
  kubectl apply -f - 2>/dev/null || true

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
# Step 5: 预加载 busybox 镜像到 Kind 节点（离线环境）
# -------------------------------------------------------
echo "🚀 预加载 busybox:1.36 到 Kind 节点..."
if ! docker image inspect busybox:1.36 &>/dev/null; then
  docker pull busybox:1.36
fi
BUSYBOX_TAR=$(mktemp /tmp/busybox-XXXXXX.tar)
docker save busybox:1.36 -o "${BUSYBOX_TAR}"
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
  docker cp "${BUSYBOX_TAR}" "${node}":/busybox.tar 2>/dev/null
  docker exec "${node}" ctr --namespace=k8s.io images import --platform linux/arm64 /busybox.tar 2>/dev/null || true
  echo "  已加载到节点: ${node}"
done
rm -f "${BUSYBOX_TAR}"
echo "✅ busybox 预加载完成"

# -------------------------------------------------------
# Step 6: 初始化 /share 目录权限
# -------------------------------------------------------
echo "🚀 初始化 /share 目录..."
cat <<'PODEOF' | kubectl apply -n "${NAMESPACE}" -f -
apiVersion: v1
kind: Pod
metadata:
  name: nfs-share-init
  namespace: jupyter
spec:
  restartPolicy: Never
  containers:
  - name: init
    image: busybox:1.36
    imagePullPolicy: Never
    command: ["sh", "-c"]
    args:
    - mkdir -p /data/share && chmod 2777 /data/share && echo "share init done"
    volumeMounts:
    - name: workspace
      mountPath: /data
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: pvc-jupyter-shared
PODEOF
kubectl wait -n "${NAMESPACE}" --for=condition=ready pod/nfs-share-init --timeout=60s 2>/dev/null || true
kubectl logs -n "${NAMESPACE}" nfs-share-init 2>/dev/null || true
kubectl delete pod nfs-share-init -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
echo "✅ /share 目录初始化完成"
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
