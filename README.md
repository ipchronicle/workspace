# IPChronicle Workspace

这个仓库是 IPChronicle 的本地开发工作区入口，负责保存项目背景、跨仓库协作规则和已经确认的长期决策。产品代码放在独立 Git 仓库中，不提交到 workspace 仓库。

开始任何设计或开发前，先阅读 [项目背景](docs/project-background.md)。

当前讨论中已经确认的产品边界记录在
[产品定义](docs/product-definition.md)，跨仓库长期技术决定记录在
[架构决策](docs/decisions/) 中；已确认边界的整体视图见
[系统架构概览](docs/system-architecture.md)，落地顺序见
[首版实现顺序](docs/implementation-sequence.md)。本轮基线检查结果见
[架构一致性审查](docs/architecture-baseline-review.md)。面向未来产品仓库的
代码与验证约束见[产品工程准则](docs/product-engineering-guidelines.md)，已确认
的页面职责见 [UI 信息架构](docs/ui-information-architecture.md)。

## 当前状态

- IPChronicle 是一个准备从头设计和实现的独立项目。
- 旧项目 `Komari-ip-history` 只作为需求、交互和工程问题的参考库。
- 首版产品范围、主要系统边界、技术栈、部署方式和单仓库边界已经形成确认记录，产品实现尚未开始。
- 全部架构记录已经完成一次基线一致性审查；后续从首个产品仓库切片开始选择窄实现参数。
- 产品源码计划放在单一的 `ipchronicle/ipchronicle` 仓库中；现有 `server`、`web`、`agent`、`deploy` 预留仓库不参与既定架构。
- workspace 暂不提供 bootstrap、统一检查、commit lock 或开发环境脚本；真正出现重复流程后再决定是否需要自动化。

## 本地目录约定

```text
ipchronicle-workspace/
├── AGENTS.md
├── README.md
├── docs/
│   ├── project-background.md
│   ├── product-definition.md
│   ├── system-architecture.md
│   ├── architecture-baseline-review.md
│   ├── product-engineering-guidelines.md
│   ├── ui-information-architecture.md
│   ├── implementation-sequence.md
│   └── decisions/
├── repos/          # ignored，放独立的新项目仓库
└── references/     # ignored，放旧项目等参考仓库
```

GitHub 组织中目前预留了以下仓库：

- `ipchronicle/workspace`
- `ipchronicle/server`
- `ipchronicle/web`
- `ipchronicle/agent`
- `ipchronicle/deploy`

这些预留仓库不参与首版实现，不应为了填充名称而写入产品代码。未来只有在出现独立产品、团队、权限、许可证或发布边界并形成新 ADR 后，才重新评估拆分。
