-- 添加练习统计字段 total/right/wrong
ALTER TABLE kb_qa
    ADD COLUMN total INT NOT NULL DEFAULT 0 COMMENT '总练习次数',
    ADD COLUMN `right` INT NOT NULL DEFAULT 0 COMMENT '答对次数',
    ADD COLUMN wrong INT NOT NULL DEFAULT 0 COMMENT '答错次数';
