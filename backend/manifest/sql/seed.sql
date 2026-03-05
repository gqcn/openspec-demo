-- ============================================================
-- 初始化种子数据
-- ============================================================
USE `platform`;

-- ------------------------------------------------------------
-- 默认规格套餐
-- ------------------------------------------------------------
INSERT INTO `specs` (`name`, `description`, `cpu`, `memory`, `gpu`, `gpu_type`, `node_selector`, `tolerations`, `enabled`, `sort_order`) VALUES
(
  'CPU-小',
  '适合数据探索、轻量训练',
  '2',
  '4Gi',
  '0',
  NULL,
  NULL,
  NULL,
  1,
  10
),
(
  'CPU-大',
  '适合数据预处理、中等规模计算',
  '8',
  '32Gi',
  '0',
  NULL,
  NULL,
  NULL,
  1,
  20
),
(
  'GPU-标准',
  '携带 1 块 GPU，适合模型训练与推理',
  '8',
  '32Gi',
  '1',
  'nvidia.com/gpu',
  '{"gpu-type": "gpu"}',
  '[{"key": "nvidia.com/gpu", "operator": "Exists", "effect": "NoSchedule"}]',
  1,
  30
);

-- ------------------------------------------------------------
-- 默认管理员账号
-- 密码: Admin@123456
-- bcrypt hash（cost=10）：请在生产环境中重置密码
-- ------------------------------------------------------------
-- 注意：uid = 10000 + id，管理员 id=1 时 uid=10001
-- 以下 hash 对应密码 "Admin@123456"，仅供开发测试使用
INSERT INTO `users` (`username`, `password_hash`, `uid`, `email`, `is_admin`, `status`) VALUES
(
  'admin',
  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
  10001,
  'admin@platform.internal',
  1,
  1
);
