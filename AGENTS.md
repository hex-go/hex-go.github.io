# Hex Blog 项目上下文

## 项目目标

当前仓库是个人技术博客，基于 Hugo + zzo 主题。近期目标是在 2 周内提升博客质量，用于求职简历展示。

核心展示方向：
- Kubernetes 与云原生
- Golang 后端开发
- DevOps 工程化
- 计算机基础原理

优先保证：
- 文风一致，杜绝 AI 味
- 只展示质量较高、结构清晰的内容
- 草稿和未完成内容不影响求职展示
- 后续任务、进度、写作规范不能丢失

## 作者文风

整体风格：技术备忘录式的结构化实战文档。

关键词：
- 结构化
- 实战型
- 直给型
- 追根溯源
- 表格控
- 版本控
- 注释详细
- 备忘录风
- 问题排查导向
- 少废话

### 语言特点

应保持：
- 开门见山，直接进入问题或核心观点
- 语气务实，技术判断明确
- 少用第一人称，更多使用客观陈述和操作说明
- 使用“需要”“可以”“建议”“不建议”“必须”等明确表达
- 保留真实环境、真实版本、真实命令、真实错误信息
- 用表格、列表、命令块提升信息密度

避免：
- “在本文中，我们将...”
- “让我们一起来...”
- “首先...然后...最后...”的模板化口吻
- “通过本文你将学会...”
- 空泛总结和宣传式表达
- 过度润色导致失去个人备忘录风格

### 典型表达

推荐：
- “由于生产环境...”
- “需要注意的是...”
- “举例说明...”
- “配置如下”
- “操作如下”
- “不建议...”
- “问题原因...”
- “解决方案...”

不推荐：
- “本文旨在深入探讨...”
- “接下来我们一起看看...”
- “希望本文对你有所帮助”

## 文章结构规范

常用结构：

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

标题层级习惯：
- `# 重要` / `# 环境说明` 可作为置顶说明
- `## 1.简介`、`## 2.说明`、`## 3.总结`、`## 4.参考` 为主体结构
- `### 2.1`、`### 2.2` 用于子章节
- 代码块必须带语言标识
- 参数和方案对比优先使用表格

## 博客当前状态

已完成 P0 紧急修复：
- 修复双后缀文件：`content/posts/persistence/2021-01-27-Nexus-搭建go私仓内网使用.md.md` 已改为 `.md`
- 修复该文章 title 中的 `.md` 后缀，并补充 Nexus、Go 标签
- 修复 RPC 文章中的 Windows 本地图片路径，改为 ASCII 流程图
- 将 WSL 网络文章从 `content/posts/golang/` 移到 `content/posts/个人工具/`
- 优化 `content/page/about.md`，突出 K8s、Go、DevOps 和求职状态
- 验证 Hugo 构建通过，不包含草稿

草稿状态：
- 当前约 61 篇 `draft: true`
- 草稿应保持隐藏，不要为了数量贸然发布

## 推荐展示文章

### Golang

- `content/posts/golang/2020-09-02-Go-Strings-字符串操作汇总.md`
- `content/posts/golang/2020-09-22-Go-Path-文件路径操作汇总.md`
- `content/posts/golang/2022-08-04-golangci-lint常见报错说明及修复建议.md`
- `content/posts/golang/2020-09-03-Go-Defer说明.md`
- `content/posts/golang/2020-07-23-Go-Module实现go语言的插件机制.md`

### Kubernetes

- `content/posts/kubernetes/2020-05-28-k8S-使用client-go操作集群.md`
- `content/posts/kubernetes/2021-02-18-Kubernetes[PodSecurityPolicy]-使用说明.md`
- `content/posts/kubernetes/2023-09-01-k8s网络-Calico详细说明.md`
- `content/posts/kubernetes/2023-08-31-k8s网络-Flannel详细说明.md`
- `content/posts/kubernetes/2023-08-30-k8s网络-概念与介绍.md`

### DevOps

- `content/posts/devops/2020-01-07-Jenkins-Pipeline使用举例.md`
- `content/posts/devops/2020-05-29-Docker-dockerfile的最佳实践.md`
- `content/posts/devops/2020-01-07-Drone-Pipeline使用举例.md`
- `content/posts/devops/2021-01-25-Keycloak-配置gatekeeper保护没有认证授权的应用功能.md`

## 当前待办计划

P1：
- 打磨 `content/posts/计算机原理/2021-11-05-Https流程说明.md`
- 打磨 `content/posts/计算机原理/2021-11-09-RSA算法原理.md`
- 设置 14 篇高质量文章 pinned

P2：
- 为 K8s CNI 系列增加系列导航和统一 series 标记
- 精修 client-go 文章，补充错误处理、Informer、实战案例
- 扩充 Go fmt、Slice、设计模式等较短文章

## HTTPS 文章打磨方式

处理 `content/posts/计算机原理/2021-11-05-Https流程说明.md` 时，采用交互式流程：

1. 先梳理概念，不直接生成大段文章
2. 记录用户理解模糊的点
3. 将模糊点沉淀为私有学习笔记，不作为博客正文
4. 理解清楚后再逐章节改写博客
5. 最终文章保持作者文风：直给、结构化、备忘录、少 AI 味

建议新增私有笔记：
- `.project-context/https-learning-notes.md`

该笔记记录：
- 用户原始疑惑
- 解释后的理解
- 面试可复述版本
- 不写入博客但对复习有价值的点

## 验证命令

构建：

```bash
hugo --buildDrafts=false --minify
```

或：

```bash
make clean-build
```

本地预览：

```bash
make server
```

## 工作原则

- 不主动 commit，除非用户明确要求
- 编辑文章前先读取原文
- 不批量重写成 AI 风格
- 优先保留作者已有表达，再做结构和准确性修正
- 任何技术解释都要先确保用户理解，再落到博客正文
- 求职展示优先级高于文章数量
