---
title: 'ChirpStack-ApplicationServer[源码]-oidc认证流程'
categories:
  - 源码阅读
tags:
  - Source Code
date: '2021-03-01 10:19:09'
top: false
comments: true
---

# 重要
ChirpStack是一个开源的lora设备管理平台，其中ApplicationServer是设备管理页面，
支持简单认证，也支持oauth2认证，但oauth2认证与正常的不太一样，可以简单总结为

1. 依靠sso做统一`认证`
2. 本地数据库存储用户信息进行`鉴权`

优点： 依靠本地鉴权管理体系，更好跟local模式兼容。
缺点： 无法统一在sso中进行权限分配。

![chirpstack oidc流程说明](https://tvax4.sinaimg.cn/large/006hT4w1ly1gw3817us8tj30ku0nmwgh.jpg)


# Reference