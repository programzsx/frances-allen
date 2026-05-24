     1|-- ============================================================
     2|-- Migration: rename kb_qa.kb_category_id → category_id
     3|-- Date: 2026-05-25
     4|-- Database: frances-allen
     5|-- ============================================================
     6|
     7|-- 重命名列
     8|ALTER TABLE `kb_qa` 
     9|    CHANGE `kb_category_id` `category_id` varchar(64) NOT NULL COMMENT '所属知识分类ID（FK → kb_category.id）';
    10|
    11|-- 重建相关索引（MySQL CHANGE 会保留索引，但显式重建确保一致性）
    12|-- DROP INDEX + ADD INDEX 以防万一
    13|
    14|-- 删除旧索引名（如果存在）
    15|-- 注意：idx_kb_qa_category 和 idx_kb_qa_category_score 在 CHANGE 后仍指向新列名
    16|-- 这里显式重建以确保索引名与列名一致
    17|
    18|ALTER TABLE `kb_qa` 
    19|    DROP INDEX `idx_kb_qa_category`,
    20|    DROP INDEX `idx_kb_qa_category_score`,
    21|    ADD INDEX `idx_kb_qa_category` (`category_id`),
    22|    ADD INDEX `idx_kb_qa_category_score` (`category_id`, `score`);
    23|
    24|-- 同时修正 kb_category.count 统计相关（kb_tag 表也引用了 kb_qa 的相关逻辑）
    25|-- 注意：kb_tag.kb_category_id 保持不变，本次只改 kb_qa 表
    26|
    27|-- 验证
    28|SELECT COUNT(*) AS total_rows FROM kb_qa;
    29|SELECT id, question, category_id, score FROM kb_qa LIMIT 3;
    30|