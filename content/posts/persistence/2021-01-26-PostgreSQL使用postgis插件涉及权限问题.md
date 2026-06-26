---
title: PostgreSQL 使用 PostGIS 插件涉及权限问题
categories:
  - Persistence
tags:
  - Persistence
  - PostgreSQL
  - PostGIS
date: 2020-08-15 00:00:00
top: false
comments: true
---

# 重要

PostgreSQL 启用 PostGIS 插件需要 superuser 权限。普通用户即使拥有数据库的所有权限，也无法执行 `CREATE EXTENSION postgis`。

## 1.简介

PostgreSQL 已安装 PostGIS 插件后，创建新库并赋权给普通用户。开发在库中建表时报 `type "public.geometry" does not exist`。

## 2.说明

### 2.1 排错过程

```text
登录数据库，查看已安装插件：

\dT  → 没有 geometry 等 PostGIS 类型
\dx  → 只有 plpgsql，没有 postgis
```

建表时报错：

```text
ERROR:  type "public.geometry" does not exist
LINE 4:   "geometry" "public"."geometry",
```

PostGIS 的 geometry 类型不可用 → 数据库未启用 PostGIS 扩展。

### 2.2 原因

即使插件已在 PostgreSQL 服务器安装，仍需逐个数据库启用：

```bash
CREATE EXTENSION postgis;
```

但这个命令需要 superuser 权限，普通用户（即使有数据库所有权限）无权执行。

### 2.3 处理

```bash
# 由管理员赋予临时 superuser 权限
ALTER ROLE user_name SUPERUSER;

# 以该用户登录后启用扩展
CREATE EXTENSION postgis;

# 收回 superuser 权限
ALTER ROLE user_name NOSUPERUSER;
```

## 3.参考

- [Cannot create extension without superuser role](https://stackoverflow.com/questions/16527806/cannot-create-extension-without-superuser-role)
- [ERROR: type "public.geometry" does not exist](https://stackoverflow.com/questions/40711832/error-type-public-geometry-does-not-exist)
