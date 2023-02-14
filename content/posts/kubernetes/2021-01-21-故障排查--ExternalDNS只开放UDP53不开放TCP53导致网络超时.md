---
title: 故障排查--ExternalDNS只开放UDP53不开放TCP53导致网络超时
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-01-21 10:02:19'
top: false
comments: true
---

# 重要
记同事一次奇葩问题拍错过程。

# 环境说明
presto 服务部署在k8s集群内部，并与集成了集群外的kerbos认证。

*现象：*
    集群内部访问presto一切正常，但集群外部访问会阻塞5分钟，之后访问正常。
    
*排错过程：*
    抓包，抓client与kerbos之间包。发现客户端像`DNS-Server`发起了对域``的解析，返回的解析结果中包含36个主机IP,包大小超过了512字节，导致消息被截断，
    然后重新发起了TCP请求，但`DNS-Server`的TCP-53端口没有开放，客户端重试5分钟，超时。但presto还继续了后面正常的逻辑。

*造成问题原因：*
    1. 集群外部使用`DNS-Server`,安全组中中开放了`TCP-53`，未开放`UDP-53`端口。

*导致问题难以定位原因：*
    1. 之前主机较少，解析的包未超过512。集群内外状态皆正常。
    2. 集群内部使用的`CoreDNS`，`TCP-53`与`UDP-53`端口开放；但集群外部使用的外部的`DNS-Server`,安全组中只开放了`TCP-53`。
    3. 以为presto服务存在问题，只抓了客户端与presto之间的网路包。后期观察presto日志发现阻塞时，日志停留在与kerbos认证过程中。
    4. presto处理机制存在问题，即dns解析异常未做处理(比如抛错或退出)；未收到期望的解析结果仍走了后面正常逻辑，导致只是等待5分钟，但后续逻辑正常。

# Reference
抓取的包文件可从[此处获取](/images/files/presto-dns-53.cap)

包通过`wireshark`打开，如下：

<img src="/images/post-image/dns-TCP53-not-export.png" width="60%">

[DNS使用TCP和UDP的53端口](https://blog.csdn.net/ldw662523/article/details/79564884)
