     1|-- ============================================================
     2|-- Migration: rename kb_category.qa_count → count
     3|-- Date: 2026-05-25
     4|-- Database: frances-allen
     5|-- ============================================================
     6|
     7|ALTER TABLE `kb_category` 
     8|    CHANGE `qa_count` `count` int NOT NULL DEFAULT 0 COMMENT '问答条目数';
     9|
    10|-- 验证
    11|SELECT COUNT(*) AS total_rows FROM kb_category;
    12|SELECT id, name, `count` FROM kb_category LIMIT 5;
    13|