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

- IPChronicle 是一个从头实现的独立项目，首个稳定版 `v0.1.0` 已于 2026-09-03 发布。
- 旧项目 `Komari-ip-history` 只作为需求、交互和工程问题的参考库。
- 首版产品范围、主要系统边界、技术栈、部署方式和单仓库边界已经形成确认记录，并落实到稳定版本。
- 产品源码、部署资产和发布工具位于单一的 [`ipchronicle/ipchronicle`](https://github.com/ipchronicle/ipchronicle) 仓库中。
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

## GitHub 仓库边界

- [`ipchronicle/ipchronicle`](https://github.com/ipchronicle/ipchronicle)：完整产品源码、部署资产、测试和版本发布。
- [`ipchronicle/workspace`](https://github.com/ipchronicle/workspace)：产品背景、架构决策和跨项目工程约束。
- [`ipchronicle/.github`](https://github.com/ipchronicle/.github)：组织首页和公共协作文件。

Center、Web、Agent 和部署资产属于同一产品源码边界。只有出现独立产品、
团队、权限、许可证或发布生命周期，并形成新的 ADR 后，才重新评估拆分。

除第三方材料另有说明外，本仓库内容采用
[`AGPL-3.0-only`](LICENSE) 许可证。
