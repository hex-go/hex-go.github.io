---
title: Go-源码解读--grafana-v7.1.0
categories:
  - Golang
tags:
  - Go
date: '2020-07-24 10:08:57'
top: false
comments: true
---

# 重要
最近研究grafana与keycloak集成，能正常解决认证问题，但用户只会在grafana通过keycloak用户登录时，才会在grafana的数据库中创建用户。
需要研究如何通过API触发此操作，为后续在grafana中给此用户授权做准备。grafana本身无此API，相近的功能Openldap与grafana用户同步也是在企业版。
由此需要研究grafana源码，首选API实现，无法成功则研究API背后的逻辑，直接操作数据库实现。

# 环境说明
grafana: v7.1.0
keycloak: 10.0.2

# 安装

# 使用

# Reference