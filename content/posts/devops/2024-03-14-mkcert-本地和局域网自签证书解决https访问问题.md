---
title: mkcert-本地、局域网自签证书解决https访问问题
categories:
  - Devops
tags:
  - Devops
  - 证书
  - PKI
  - Mkcert
date: '2024-03-14 09:16:33'
top: false
comments: true
---

## 重要
开发或者局域网内部服务，有时候需要模拟 https 环境。使用来自真实证书颁发机构 (CA) 的证书进行开发存在私钥泄露的风险，而且不对公网暴露的服务，也没必要申请真实证书，增加成本。因此最好的解决方案是管理在自己的CA。

一般都是自签证书，然后在 http server 中使用自签证书。并且为了解决浏览器信任问题，需要将自签证书使用的 CA 证书添加到系统或浏览器的可信 CA 证书中。 上述过程需要操作繁琐的openssl命令实现自签证书，且需要手动信任CA。对本地开发和局域网不那么友好。本文将介绍`mkcert`，可简化这一过程。

## mkcert简介

`mkcert`是一个go语言编写的小工具，可自动在系统根存储中创建和安装本地 CA，并生成本地信任的证书。可跨平台，配置简单。

## 安装
自行下载，选择合适安装包进行安装 https://github.com/FiloSottile/mkcert/releases/latest

## 使用
> 建议以管理员运行`mkcert`

1. 生成本地CA、并导入系统根存储
```
mkcert --install

```
mkcert 支持以下根存储：
- macOS 系统存储
- Windows 系统存储
- Linux
    - `update-ca-trust` （Fedora、RHEL、CentOS）
    - `update-ca-certificates` （Ubuntu、Debian、OpenSUSE、SLES）
    - `trust`（Arch）
- 火狐浏览器（仅限 macOS 和 Linux）
- Chrome 和 Chromium
- Java（需要设置JAVA_HOME）

默认导入所有支持的根存储，也可以通过环境变量`TRUST_STORES`，指定只导入指定的root store。选项包括"system"、"java "和 "nss"
```bash
export TRUST_STORES=system,java,nss
```

导入已有CA,而不重新生成CA
```bash
export CAROOT=/xxx/rootCA.pem

mkcert -install
```

2. 根据



### 本地开发使用


###

### 局域网
> 主机（mac/linux/windows） + k8s_ingress

1. 根CA生成与管理
> 建议公司只生成一个根CA，并由公司QA进行管理，尤其是`rootCA-key.pem`不可泄露

执行命令


2. 将生成的根CA证书提供给cert-manager，

### 搭配cert-manager



# Reference

[概念说明](https://www.cnblogs.com/guogangj/p/4118605.html)
[生成证书](https://blog.csdn.net/xiangyuecn/article/details/79179684)
