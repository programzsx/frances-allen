-- Frances Allen 数据库初始化脚本
-- 数据库: frances-allen
-- 字符集: utf8mb4

CREATE DATABASE IF NOT EXISTS `frances-allen` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `frances-allen`;

-- 题库表
CREATE TABLE IF NOT EXISTS `kb_bank` (
    `id`          VARCHAR(64)   NOT NULL COMMENT '雪花ID',
    `create_time` VARCHAR(32)   NOT NULL COMMENT '创建时间',
    `update_time` VARCHAR(32)   NOT NULL COMMENT '更新时间',
    `name`        VARCHAR(128)  NOT NULL COMMENT '题库名称',
    `parent_id`   VARCHAR(64)   DEFAULT NULL COMMENT '父题库ID，自关联',
    PRIMARY KEY (`id`),
    KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='题库表';

-- 标签表
CREATE TABLE IF NOT EXISTS `kb_tag` (
    `id`          VARCHAR(64)   NOT NULL COMMENT '雪花ID',
    `create_time` VARCHAR(32)   NOT NULL COMMENT '创建时间',
    `update_time` VARCHAR(32)   NOT NULL COMMENT '更新时间',
    `name`        VARCHAR(128)  NOT NULL COMMENT '标签名称',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='标签表';

-- 问答对表
CREATE TABLE IF NOT EXISTS `kb_qa` (
    `id`          VARCHAR(64)   NOT NULL COMMENT '雪花ID',
    `create_time` VARCHAR(32)   NOT NULL COMMENT '创建时间',
    `update_time` VARCHAR(32)   NOT NULL COMMENT '更新时间',
    `question`    TEXT          NOT NULL COMMENT '问题题目，___表示填空',
    `answer`      TEXT          NOT NULL COMMENT '答案JSON数组',
    `image_url`   VARCHAR(512)  DEFAULT NULL COMMENT '关联图片的OSS URL',
    `total`       INT           NOT NULL DEFAULT 0 COMMENT '总答题次数',
    `right`       INT           NOT NULL DEFAULT 0 COMMENT '答对次数',
    `wrong`       INT           NOT NULL DEFAULT 0 COMMENT '答错次数',
    `random_int`  INT           NOT NULL COMMENT '自增整数，用于随机排序',
    `bank_id`     VARCHAR(64)   DEFAULT NULL COMMENT '所属题库ID',
    `tag_id`      TEXT          DEFAULT NULL COMMENT '标签ID的JSON数组',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_random_int` (`random_int`),
    KEY `idx_bank_id` (`bank_id`),
    KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='问答对表';
