---
title: MongoDB-sharded集群搭建及维护使用
categories:
  - Persistence
tags:
  - Persistence
  - Mongodb
date: '2020-11-13 04:02:02'
top: false
comments: true
---
# 重要
mongodb的搭建主要分`sharded-cluster`,`ha`, `single-node`, 一个`ha`可以包含primary(1),secondary(0~2),ab

1. mongodb使用偶数版本(稳定版本)。比如4.4.1， 而非奇数版本(开发版本)，比如4.3.0。具体详见[mongodb versioning](https://docs.mongodb.com/manual/reference/versioning/#mongodb-versioning)

2. mongodb关于bitnami的sharded部署，普通用户的创建不能使用。因为

# 1.简介

# 2.环境准备

# 3.部署

# 4.使用

# Reference
官方文档

[mongodb官方文档-sharding](https://docs.mongodb.com/manual/sharding/)

[mongodb官方文档-sharding部署](https://docs.mongodb.com/manual/tutorial/deploy-shard-cluster/)

[mongodb官方文档-sharded-Cluster管理员文档](https://docs.mongodb.com/manual/administration/sharded-cluster-administration/)

[mongodb官方文档-sharded-Cluster管理员文档v3版本](https://docs.mongodb.com/v3.0/administration/sharded-clusters/)

[mongodb官方文档-版本说明](https://docs.mongodb.com/manual/reference/versioning/#mongodb-versioning)

[mongodb官方文档-Release Notes](https://docs.mongodb.com/manual/release-notes/4.4/)

部署chart(注意，helm/charts下的mongodb和mongodb-replicaset已不再维护)

[mongodb-部署chart-Mongodb-sharded](https://github.com/bitnami/charts/tree/master/bitnami/mongodb-sharded)

[数据库初始化，需要等集群正确分片后执行](https://github.com/bitnami/charts/issues/1655#issuecomment-704064736)
[(bitnami/mongodb-sharded)custom用户和数据库变量被忽略](https://github.com/bitnami/charts/issues/1655)

扫盲博客

[博客--mongodb部署了解mongodb-sharded](https://www.cnblogs.com/xybaby/p/6832296.html#_label_0)

其他
[阿里云mongodb-sharding 注意事项](https://help.aliyun.com/document_detail/64561.html)

[Performance Best Practices: Sharding](https://www.mongodb.com/blog/post/performance-best-practices-sharding)

[What is MongoDB Sharding and the Best Practices?](https://geekflare.com/mongodb-sharding-best-practices/)

[The Basics of Sharding in MongoDB](https://orangematter.solarwinds.com/2017/09/06/the-basics-of-sharding-in-mongodb/)




