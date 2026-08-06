# IPChronicle Workspace

这个仓库是 IPChronicle 的本地开发工作区入口，负责保存项目背景、跨仓库协作规则和已经确认的长期决策。产品代码放在独立 Git 仓库中，不提交到 workspace 仓库。

开始任何设计或开发前，先阅读 [项目背景](docs/project-background.md)。

## 当前状态

- IPChronicle 是一个准备从头设计和实现的独立项目。
- 旧项目 `Komari-ip-history` 只作为需求、交互和工程问题的参考库。
- 技术栈、功能范围、系统架构、数据模型、部署方式和仓库边界尚未决定。
- `server`、`web`、`agent`、`deploy` 仓库目前只是预留位置，不代表最终必须采用这种拆分。
- workspace 暂不提供 bootstrap、统一检查、commit lock 或开发环境脚本；真正出现重复流程后再决定是否需要自动化。

## 本地目录约定

```text
ipchronicle-workspace/
├── AGENTS.md
├── README.md
├── docs/
│   ├── project-background.md
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

新开发机会话可以根据最终架构合并、改名、停用或增加仓库，不应为了填充这些空仓库而提前做架构决定。
