---
title: 故障排查--ExternalDNS只开放UDP53不开放TCP53导致网络超时
categories:
  - Kubernetes
tags:
  - Kubernetes
  - DNS
  - 故障排查
date: '2021-01-21 10:02:19'
top: false
comments: true
---

# 重要

DNS 协议在响应包超过 512 字节时，会自动切换到 TCP 传输。如果 DNS Server 只开放 UDP 53 端口，部分解析请求会被截断，客户端重试 TCP 超时后才会 fallback。

# 环境说明

- Presto 服务部署在 K8s 集群内，集成集群外部 Kerberos 认证
- K8s 内部使用 CoreDNS（UDP/TCP 53 均开放），集群外部使用独立 DNS Server

## 1.简介

集群外部访问 Presto 时，请求阻塞约 5 分钟后恢复正常。

## 2.说明

### 2.1 现象

| 访问来源 | 现象 |
|----------|------|
| 集群内部 | 正常 |
| 集群外部 | 阻塞约 5 分钟后正常 |

### 2.2 排错过程

1. 抓客户端与 Kerberos 之间的包，发现客户端向 DNS Server 发起域名解析；
2. 解析结果包含 36 个主机 IP，响应包超过 512 字节；
3. UDP 响应被截断，客户端发起 TCP 重试；
4. 外部 DNS Server 的 TCP 53 端口未开放；
5. 客户端 TCP 重试超时（约 5 分钟），之后走后续逻辑；
6. Presto 未对 DNS 解析异常做错误处理，超时后继续执行。

### 2.3 根因

```text
DNS 响应 > 512 字节
   → UDP 响应被截断
   → 客户端切换 TCP 53 重试
   → 外部 DNS Server TCP 53 未开
   → TCP 连接超时（~5min）
   → 超时后客户端继续后续流程
```

### 2.4 为什么之前没暴露

| 因素 | 说明 |
|------|------|
| 之前主机较少 | 响应包未超过 512 字节，UDP 即可完成 |
| 集群内外部 DNS 不同 | 内部 CoreDNS TCP/UDP 均开放；外部 DNS 只开了 UDP |

### 2.5 为什么难定位

| 混淆点 | 说明 |
|--------|------|
| 表现是 Presto 慢 | 实际是 DNS 超时 |
| 只抓了 Presto 业务包 | 没抓 DNS 包 |
| 超时后正常 | Presto 没有 DNS 错误处理，超时后继续走 |

## 3.总结

1. DNS 512 字节截断不是协议 bug，是标准行为——UDP 包超过 512 字节时客户端必须切 TCP；
2. 部署 DNS Server 必须同时开放 UDP 53 和 TCP 53；
3. 排查跨系统问题时抓包范围要覆盖所有通信对（不只是业务服务）。

## 4.参考

- [DNS使用TCP和UDP的53端口](https://blog.csdn.net/ldw662523/article/details/79564884)
