---
title: 密码管理工具 Bitwarden 使用
categories:
  - 个人工具
tags:
  - 个人工具
  - Bitwarden
date: '2022-07-28 07:07:32'
top: false
comments: true
---

# 重要

Bitwarden 开源、跨平台，支持自建服务端。LastPass 迁移只需导出 CSV 再导入。

## 1. LastPass 迁移

LastPass 导出：

- Web 端：`Advanced Options` → `Export`
- 浏览器插件：`Account Options` → `Advanced` → `Export` → `LastPass CSV File`

Bitwarden 导入：`Tools` → `Import Data` → 选择 `LastPass CSV` → 导入。

## 2. 浏览器自动填充

快捷键：`Ctrl + Shift + L`（Windows/Linux）/ `Cmd + Shift + L`（macOS）。

页面加载时自动填充：浏览器插件 → `Settings` → `Options` → `Enable Auto-fill on Page Load`。

## 3. URI 匹配

默认匹配规则按子域名区分。多个域名共用同一凭据时使用正则：

```text
URI 规则: ^(http|https)://((gitlab|zentao|jenkins)\.example\.com)
可匹配:
  - https://gitlab.example.com
  - https://zentao.example.com
  - https://jenkins.example.com
```

匹配规则间是**且**关系，正则可以实现"或"匹配。

## 4. 其他设置

| 操作 | 路径 |
|------|------|
| 中文界面 | 账号设置 → 偏好设置 → 语言 |
| 多层级文件夹 | 创建 `个人`，再创建 `个人/生活` |
| 手动同步 | 插件 → Settings → Sync |

## 参考

- [Bitwarden 官方文档](https://bitwarden.com/help/)
- [URI 匹配说明](https://bitwarden.com/help/uri-match-detection/)
