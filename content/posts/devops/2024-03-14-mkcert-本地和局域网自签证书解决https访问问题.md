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
series:
  - PKI相关
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
mkcert -install

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


2. 生成证书

```bash
mkcert example.com "*.example.com" example.test localhost 127.0.0.1 ::1
```

### 本地开发使用
1. 创建CA及CA私钥文件，并安装至本机

```bash
mkcert -install
```
 
2. 按需生成服务证书（域名、IP、通配符）
> 此命令执行后，返回会显示所生成证书的存储路径
```bash
mkcert example.com "*.example.com" example.test localhost 127.0.0.1 ::1
```

3. 将第二步生成的证书与私钥配置给服务，tls
此处只需要**第2步**生成的服务证书文件+服务证书私钥。

此时本机访问服务将不会出现问题，如需要解决其他机器此服务，证书不合法问题，再执行第四步

4. 解决其他主机访问证书不合法问题

```bash
# 1. 将第一步生成的ca文件（rootCA.pem）拷贝至当前需要配置的机器
# 注意只需要rootCA.pem文件，一定不能将私钥随意拷贝

# 2. 声明变量，
export CAROOT=/xxx/rootCA.pem
# 3. 执行命令，本机证书导入rootStore
mkcert -install
```

### 局域网
> 主机（mac/linux/windows） + k8s_ingress

1. 根CA生成与管理
> 建议公司只生成一个根CA，并由公司QA进行管理，尤其是`rootCA-key.pem`不可泄露

执行命令
```
mkcert install
```

2. 将生成的根CA证书提供给cert-manager

- 通过`mkcert -CAROOT`命令打印CA证书`rootCA.pem`的目录
- 根据证书及其私钥，创建ClusterIssuer(CertManager的CR)

3. k8s集群可通过挂载cert-manager生成的证书，从而实现以下能力
    - k8s对外暴露ingress tls加密
    - 服务之间加密通信
    - 服务之间，基于证书签名、验签机制实现服务认证。

4. 开发、测试、演示机器配置免密访问
将ca文件`rootCA.pem`拷贝至需要配置的机器，执行以下命令实现配置
```bash
# 声明变量，
export CAROOT=/xxx/rootCA.pem
# 执行命令，本机证书导入rootStore
mkcert -install
```


## 其他场景

### a. 关于CA

#### a.1 生成CA的存储路径
可通过`mkcert -CAROOT`命令打印CA证书`rootCA.pem`与私钥`rootCA-key.pem`的目录，注意私钥妥善保存

#### a.2 导入已有CA,而不重新生成CA
> 通过`mkcert -CAROOT`命令查找`rootCA.pem`文件
> 复制到需要配置的机器
> 将设置`CAROOT`指向证书文件
> 执行`mkcert -install`

将ca文件（rootCA.pem）拷贝至当前需要配置的机器，执行下面命令
```bash
export CAROOT=/xxx/rootCA.pem

mkcert -install
```
输出
```
Created a new local CA 💥
The local CA is now installed in the system trust store! ⚡️
The local CA is now installed in the Firefox trust store (requires browser restart)! 🦊
```

#### a.3 只导入指定的rootStore

默认导入所有支持的根存储，也可以通过环境变量`TRUST_STORES`，指定只导入指定的root store。选项包括"system"、"java "和 "nss"

```bash
export TRUST_STORES=system,java,nss
mkcert -install
```

### b. 关于证书

### b.1 根据CSR文件生成证书
> mkcert通过创建csr的能力，但提供根据csr创建证书的能力。这样可以避免服务私钥与CA私钥共同持有的安全隐患。

使用 OpenSSL 创建证书签名请求
```bash
openssl req -out example.csr -new -newkey rsa:4096 -nodes -keyout example.pem -subj "/C=US/ST=College Station/L=Texas/O=Home/OU=lab/CN=*.apps.svc.com"
```
上面命令会创建以下文件:
1. example.csr - 证书签名请求csr文件.
2. example.pem - 此csr相关的私钥文件.
   利用mkcert, 根据csr文件提供的信息，创建相应证书
```bash
mkcert -csr example.csr
```
输出为
```
Created a new certificate valid for the following names 
 - "*.apps.svc.com"
Reminder: X.569 wildcards only go one level deep，so this won't match a.b.apps.svc.com 
The _ certificate is at "./_wildcard.apps.svc.com.pem"
It will expire on 19 January 2026 
```

#### b.2 生成pk12格式证书

-pkcs12命令可以产生PKCS12格式的证书。java 程序通常不支持PEM格式的证书，但是支持PKCS12格式的证书。

```bash
mkcert -pkcs12 localhost 127.0.0.1 
```
输出示例，默认密码为
```
Note: the local CA is not installed in the Java trust store. 
Run “mkcert -install" for certificates to be trusted automtically  

Created a new certificate valid for the following names 
 - "Localhost" 
 - "127.0.0.1" 

The PKCS#12 bundle is at "./localhost+1.p12" 
The legacy PKCS#12 encryption password is the often hardcoded default "changeit" 

It will expire on 15 April 2026
```

### c. 关于证书信任

### c.1 设置nodejs证书信任

Node 不使用系统根存储，因此不会自动信任`mkcert`证书。必须设置 NODE_EXTRA_CA_CERTS 环境变量。
```bash
export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"
```

# Reference

[概念说明](https://www.cnblogs.com/guogangj/p/4118605.html)
[生成证书](https://blog.csdn.net/xiangyuecn/article/details/79179684)
