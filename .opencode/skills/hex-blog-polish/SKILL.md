---
name: hex-blog-polish
description: Use when editing, polishing, planning, or restructuring the Hex Hugo personal blog, especially Kubernetes, Golang, DevOps, HTTPS/RSA posts, resume-facing blog quality work, author writing style preservation, and avoiding AI-like writing.
---

# Hex Blog Polish

## Scope

Use this skill for this repository's Hugo + zzo personal blog work:

- polishing existing technical posts
- writing or restructuring Kubernetes, Golang, DevOps, computer fundamentals posts
- improving resume-facing blog quality
- managing draft visibility
- preserving the author's writing style
- tracking the 2-week job-search blog improvement plan

Do not use this skill for unrelated application code.

## Goal

The blog is being prepared for job hunting. The blog URL appears on the resume, so quality and first impression matter more than article count.

Priorities:

1. Show strong Kubernetes/cloud-native experience
2. Show Golang backend capability
3. Show DevOps engineering practice
4. Show basic computer fundamentals where useful for interviews
5. Hide drafts and low-quality unfinished content
6. Preserve the author's real style and avoid AI-like writing

## Author Style

Overall style: technical memo style, structured, practical, direct.

Keywords:

- structured
- practical
- direct
- root-cause oriented
- table-heavy
- version-aware
- command-heavy
- troubleshooting-oriented
- concise
- memo-like

Keep:

- direct opening, no marketing intro
- objective technical tone
- real environment, versions, commands, errors
- clear judgments: “需要”, “可以”, “建议”, “不建议”, “必须”
- tables for comparisons and parameters
- numbered sections
- code blocks with language identifiers

Avoid:

- “在本文中，我们将...”
- “让我们一起来...”
- “首先...然后...最后...” as a template
- “通过本文你将学会...”
- “希望本文对你有所帮助”
- generic AI summaries
 - over-polished promotional tone
 - `--` / `——` in titles（显得割裂，且在 TOC 中容易换行导致格式混乱）

### Title Formatting

- 表达精确度第一，但如果能做到，尽量让 TOC 中的标题不换行
- 避免 `--` 和 `——`，用中文冒号替代
Preferred wording:

- “由于生产环境...”
- “需要注意的是...”
- “举例说明...”
- “配置如下”
- “操作如下”
- “问题原因...”
- “解决方案...”

## Article Structure

Common structure:

```markdown
---
title: XXX
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Go
date: 2024-01-01T00:00:00+08:00
toc: true
draft: false
---

# 重要

一句话说明核心结论、问题背景或注意事项。

# 环境说明

- 操作系统：Ubuntu 22.04
- Kubernetes：v1.19.8
- Go：go1.20

## 1.简介

背景、概念、适用场景。

## 2.说明

### 2.1 子主题

具体说明。

### 2.2 子主题

命令、配置、代码示例。

## 3.总结

结论、经验、建议。

## 4.参考

- 参考链接
```

Rules:

- Use `# 重要` and `# 环境说明` when useful.
- Use `## 1.简介`, `## 2.说明`, `## 3.总结`, `## 4.参考` for main body.
- Use `### 2.1`, `### 2.2` for subsections.
- Code fences must include language identifiers.
- Tables are preferred for comparison and parameters.

## Hugo Shortcodes

项目 `layouts/shortcodes/` 提供两个自定义短代码，用于文章中的视觉增强：

### `diagram` —— 流程图 / 时序图 / 树状图

用于展示网络数据包流程、组件调用链、分类树等 ASCII 结构图。替换无信息的 ```text 代码块。

语法：

```markdown
{{</* diagram */>}}
  流程图内容（等宽字体渲染）
{{</* /diagram */>}}
```

使用场景：
- 网络数据包流向（如容器 A → docker0 → 宿主机 → 物理网络）
- CNI 调用链（如 Kubelet → CNI Plugin → Pod）
- 分类树（如 CNI 解决的两件事 ├── IPAM └── 连通性）
- 跨主机通信路径对比

不使用场景：
- bash 命令输出（用 ```bash 或 ```text）
- 代码块（用 ```go、```yaml 等）
- 抓包数据（用 ```text）

### `keypoint` —— 核心结论 / 关键判断

用于突出核心洞察、重要结论、关键警告。替换普通加粗或引用块。

语法：

```markdown
{{</* keypoint */>}}
核心结论内容（支持 Markdown）
{{</* /keypoint */>}}
```

使用场景：
- 一句话总结核心原理（如"IP 地址端到端一致性"）
- 关键性能判断（如"性能最高，等于裸机网络，零封装开销"）
- 重要警告（如"UDP 模式仅用于演示，生产环境绝对不要用"）
- 技术选型建议（如"如果必须用 Overlay，优先选 IPIP"）

不使用场景：
- 普通说明性文字
- 表格
- 代码块

### 规则

1. 流程类 ASCII 图使用 `diagram`，不直接用 ```text
2. 核心结论、关键警告使用 `keypoint`，不用普通加粗
3. 保持节制——每篇文章 `keypoint` 不超过 5 个，`diagram` 用于真正有流程结构的场景
4. `diagram` 仅用于技术过程的图示，不是装饰性标记

## Current State

P0 emergency fixes completed:

- Fixed double suffix file: `content/posts/persistence/2021-01-27-Nexus-搭建go私仓内网使用.md.md` -> `.md`
- Fixed its title and added `Nexus`, `Go` tags
- Fixed Windows local image path in RPC post using ASCII flow diagram
- Moved WSL networking post from `content/posts/golang/` to `content/posts/个人工具/`
- Optimized `content/page/about.md` for K8s, Go, DevOps, job search
- Verified Hugo build passes without drafts

Draft state:

- About 61 posts are `draft: true`
- Keep drafts hidden. Do not publish drafts just to increase article count.

## Recommended Display Posts

### Golang

- `content/posts/golang/2020-09-02-Go-Strings-字符串操作汇总.md`
- `content/posts/golang/2020-09-22-Go-Path-文件路径操作汇总.md`
- `content/posts/golang/2022-08-04-golangci-lint常见报错说明及修复建议.md`
- `content/posts/golang/2020-09-03-Go-Defer说明.md`
- `content/posts/golang/2020-07-23-Go-Module实现go语言的插件机制.md`

### Kubernetes

- `content/posts/kubernetes/2020-05-28-k8S-使用client-go操作集群.md`
- `content/posts/kubernetes/2021-02-18-Kubernetes[PodSecurityPolicy]-使用说明.md`
- `content/posts/kubernetes/2023-09-01-k8s网络CNI-Calico详细说明.md`
- `content/posts/kubernetes/2023-08-31-k8s网络CNI-Flannel详细说明.md`
- `content/posts/kubernetes/2023-08-30-k8s网络CNI-概念与介绍.md`

### DevOps

- `content/posts/devops/2020-01-07-Jenkins-Pipeline使用举例.md`
- `content/posts/devops/2020-05-29-Docker-dockerfile的最佳实践.md`
- `content/posts/devops/2020-01-07-Drone-Pipeline使用举例.md`
- `content/posts/devops/2021-01-25-Keycloak-配置gatekeeper保护没有认证授权的应用功能.md`

## Current Plan

P1:

- Polish `content/posts/计算机原理/2021-11-05-Https流程说明.md`
- Polish `content/posts/计算机原理/2021-11-09-RSA算法原理.md`
- Set 14 high-quality posts as pinned

P2:

- Add series navigation and `series` front matter for K8s CNI posts
- Refine client-go post with error handling, Informer, practical cases
- Expand short Go posts: fmt, Slice, design patterns

## HTTPS Post Workflow

When working on `content/posts/计算机原理/2021-11-05-Https流程说明.md`:

1. Do not directly generate a large article.
2. First clarify concepts with the user.
3. Record fuzzy points as private learning notes.
4. Only write blog sections after concepts are clear.
5. Keep the final public post concise, structured, practical, and non-AI-like.

Private note path:

- `.project-context/https-learning-notes.md`

Private note should record:

- original unclear point
- explanation
- user's corrected understanding
- interview-ready wording
- notes valuable for review but not suitable for public blog body

## Verification Commands

Build:

```bash
hugo --buildDrafts=false --minify
```

or:

```bash
make clean-build
```

Preview:

```bash
make server
```

## Working Rules

- Do not commit unless explicitly requested.
- Read original article before editing.
- Do not mass rewrite into AI style.
- Preserve existing expressions where possible.
- Prefer structure and accuracy fixes over cosmetic rewriting.
- Ensure the user understands technical concepts before writing them into the blog.
- Job-search display quality is more important than article count.
