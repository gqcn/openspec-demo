export const statusMap: Record<
  string,
  { color: string; label: string }
> = {
  creating: { label: '创建中', color: 'processing' },
  running: { label: '运行中', color: 'success' },
  stopping: { label: '停止中', color: 'warning' },
  stopped: { label: '已停止', color: 'default' },
  failed: { label: '异常', color: 'error' },
};

export const columns = [
  { title: 'ID', dataIndex: 'id', width: 60 },
  { title: '用户名', dataIndex: 'username', width: 120 },
  { title: '规格', dataIndex: 'specName', width: 160 },
  {
    title: '镜像',
    dataIndex: 'image',
    ellipsis: true,
  },
  {
    title: '状态',
    dataIndex: 'status',
    width: 100,
    key: 'status',
  },
  { title: '节点', dataIndex: 'nodeName', width: 120, ellipsis: true },
  { title: 'IP', dataIndex: 'podIp', width: 130 },
  { title: '创建时间', dataIndex: 'createdAt', width: 180 },
  {
    title: '操作',
    key: 'action',
    width: 220,
    fixed: 'right' as const,
  },
];
