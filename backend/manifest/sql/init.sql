-- ============================================================
-- AI 模型训练平台 — 开发机管理模块
-- 数据库初始化 DDL
-- MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS `platform` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `platform`;

-- ------------------------------------------------------------
-- 用户表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `id`            INT UNSIGNED     NOT NULL AUTO_INCREMENT         COMMENT '用户 ID',
  `username`      VARCHAR(64)      NOT NULL                        COMMENT '用户名（登录账号）',
  `password_hash` VARCHAR(256)     NOT NULL                        COMMENT 'bcrypt 哈希密码',
  `uid`           INT UNSIGNED     NOT NULL                        COMMENT '容器内 UID，= 10000 + id，注册后不可变',
  `email`         VARCHAR(128)     DEFAULT NULL                    COMMENT '邮箱',
  `is_admin`      TINYINT UNSIGNED NOT NULL DEFAULT 0              COMMENT '是否管理员：0=否 1=是',
  `status`        TINYINT UNSIGNED NOT NULL DEFAULT 1              COMMENT '账号状态：1=正常 0=禁用',
  `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at`    DATETIME         DEFAULT NULL                       COMMENT '软删除时间，非 NULL 时账号不可见且不可登录',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_uid`      (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- ------------------------------------------------------------
-- 规格套餐表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `specs` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT            COMMENT '套餐 ID',
  `name`          VARCHAR(64)  NOT NULL                           COMMENT '套餐名称，如: CPU-小, GPU-标准',
  `description`   VARCHAR(256) DEFAULT NULL                       COMMENT '套餐描述',
  `cpu`           VARCHAR(16)  NOT NULL                           COMMENT 'CPU 规格（K8S 格式），如: 4',
  `memory`        VARCHAR(16)  NOT NULL                           COMMENT '内存规格（K8S 格式），如: 16Gi',
  `gpu`           VARCHAR(8)   NOT NULL DEFAULT '0'               COMMENT 'GPU 数量，0 表示不使用 GPU',
  `gpu_type`      VARCHAR(64)  DEFAULT NULL                       COMMENT 'GPU 资源类型，如: nvidia.com/gpu',
  `node_selector` JSON         DEFAULT NULL                       COMMENT 'K8S nodeSelector，用于 GPU 节点亲和',
  `tolerations`   JSON         DEFAULT NULL                       COMMENT 'K8S tolerations 数组',
  `enabled`       TINYINT UNSIGNED NOT NULL DEFAULT 1             COMMENT '是否启用：1=启用 0=停用',
  `sort_order`    INT          NOT NULL DEFAULT 0                  COMMENT '排序权重，升序',
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_enabled_sort` (`enabled`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='开发机规格套餐';

-- ------------------------------------------------------------
-- 开发机实例表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `instances` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT            COMMENT '实例 ID',
  `user_id`        INT UNSIGNED NOT NULL                           COMMENT '所属用户 ID',
  `username`       VARCHAR(64)  NOT NULL                           COMMENT '冗余用户名，便于查询',
  `pod_name`       VARCHAR(128) NOT NULL                           COMMENT 'K8S Pod 名称，规则: jupyterlab-{username}',
  `spec_id`        INT UNSIGNED NOT NULL                           COMMENT '使用的规格套餐 ID',
  `image_key`      VARCHAR(128) NOT NULL                           COMMENT '镜像配置 key，对应配置文件中的镜像 key',
  `image`          VARCHAR(256) NOT NULL                           COMMENT '创建时快照的完整镜像地址，防止配置变更影响历史',
  `token`          VARCHAR(128) NOT NULL                           COMMENT 'JupyterLab 认证 token（guid.S() 生成），同时作为访问路由 key',
  `status`         VARCHAR(32)  NOT NULL DEFAULT 'creating'        COMMENT '实例状态: creating|running|stopping|stopped|failed',
  `pod_ip`         VARCHAR(64)  DEFAULT NULL                       COMMENT 'Pod IP，Running 后填入',
  `node_name`      VARCHAR(128) DEFAULT NULL                       COMMENT '调度到的 K8S 节点名',
  `last_active_at` DATETIME     DEFAULT NULL                       COMMENT '最近一次检测到活跃的时间',
  `idle_since`     DATETIME     DEFAULT NULL                       COMMENT '首次检测到闲置的时间，用于 48h 超时判断',
  `stopped_at`     DATETIME     DEFAULT NULL                       COMMENT '停止时间',
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_token`    (`token`),
  KEY `idx_user_id`        (`user_id`),
  KEY `idx_status`         (`status`),
  KEY `idx_username_status`(`username`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='开发机实例';
