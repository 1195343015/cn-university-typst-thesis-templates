# cn-university-typst-thesis-templates 贡献指南

感谢贡献。

## 收录条件

仅收录同时满足以下条件的 GitHub 仓库：

- 面向中国内地高校
- 使用 Typst 实现
- 用于学位论文、毕业论文或毕业设计
- `Stars >= 10`
- 最近一次提交时间在 `2024-01-01` 及之后
- 仓库未归档

不收录课程报告、简历、幻灯片、通用文章模板，以及纯资料整理仓库。

## 数据文件

主要修改：

- `data/universities.json`
- `schema/universities.schema.json`

学校字段：

- `school_id`
- `school_name_zh`
- `templates`

模板字段：

- `repo`
- `degree_types`
- `github_metrics`

## 提交要求

- `school_id` 使用稳定的 ASCII 标识
- `repo` 使用 `owner/name` 格式
- `degree_types` 只使用：
  - `undergraduate`
  - `master`
  - `doctoral`

如果学校已存在，请直接在原条目中追加或替换模板，不要重复建学校。

## 同步

运行 `scripts/sync_github_metrics.ps1` 可自动刷新：

- `stars`
- `last_commit_at`
- `last_synced_at`

并同步更新 `README.md` 表格。
