---
title: PostgreSQL使用postgis插件涉及权限问题
categories:
  - Persistence
tags:
  - Persistence
date: '2021-01-26 10:06:30'
top: false
comments: true
---
# 重要
最重要的事: PostgreSQL已安装postgis插件，给开发提供服务时，创建了数据库，并创建新的用户，用户只有关联数据库的所有权限。导致出现如下报错

```bash
登录 postgresql 客户端
psql -h "<PostgreSQL-Host|NoPort>" -U "<PostgreSQL-User>"  -d "<PostgreSQL-Database>"

# 查看支持的数据库类型, 未发现postgis支持的类型
> \dT
                                                     List of data types
 Schema |     Name      |                              Description                                                                       
--------+---------------+-----------------------------------------------------------------------------------------
 public | agg_count     | 
 public | box2df        | 
 public | gidx          | 
 public | spheroid      | 
 public | valid_detail  |

# 查看此数据库支持的插件
>\dx
                                     List of installed extensions
  Name   | Version |   Schema   |                             Description                             
---------+---------+------------+---------------------------------------------------------------------
 plpgsql | 1.0     | pg_catalog | PL/pgSQL procedural language
(1 rows)
# 执行建库命令，报错类型不支持
>DROP TABLE IF EXISTS "public"."test";
>CREATE TABLE "public"."test" (
  "id" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar(255) COLLATE "pg_catalog"."default",
  "geometry" "public"."geometry",
  "type" int4,
  "parent_id" varchar(50) COLLATE "pg_catalog"."default"
);

ERROR:  type "public.geometry" does not exist
LINE 4:   "geometry" "public"."geometry",

```

# 原因

因为数据库没有启用postgis插件，需要执行以下命令
```bash
CREATE EXTENSION postgis;
```
但由于启用插件需要全局管理员权限，因此需要用admin用户登录postgis, 并启用"<PostgreSQL-Database>"数据库的postgis插件
```bash
# 赋予超级管理员权限
alter role user_name superuser;
# 打开一个新的pgsql,执行命令`CREATE EXTENSION postgis;`
# 收回超级管理员权限
alter role user_name nosuperuser
```

# Reference

[StackOverflow-只能用superuser创建extension](https://stackoverflow.com/questions/16527806/cannot-create-extension-without-superuser-role)

[StackOverflow-ERROR: type "public.geometry" does not exist](https://stackoverflow.com/questions/40711832/error-type-public-geometry-does-not-exist)

