---
title: DevOps-trivy-镜像扫描汇总
categories:
  - Devops
tags:
  - Devops
date: '2020-11-06 06:26:40'
top: false
comments: true
---

# 重要
trivy用来扫描镜像的安全漏洞。如果用于生产环境，需要将漏洞库离线，安全人员将镜像的基础镜像或者buildpack的stack进行升级。之后再升级安全漏洞。

将安全漏洞修复变成可计划，分期实施的过程。如果一直使用在线库，则不能采取存在漏洞立即删除的策略。

# 环境说明
trivy version 0.4.4

# 安装

# 使用
扫描镜像的命令

## 采用`server-client`模式启动服务
trivy采取`server-client`模式，server端将漏洞库离线打在镜像内

### 1. 获取离线漏洞库

在trivy版本Release时，会发布漏洞库
[下载连接](https://github.com/aquasecurity/trivy-db/releases)
[参考issue](https://github.com/aquasecurity/trivy/issues/423)

或者选择执行命令下载
```bash
trivy --download-db-only
```

### 2. 启动server端
server端命令如下
> --token用于客户端与server连接时，认证使用。
> --skip-update 跳过漏洞库更新

```bash
trivy server -d --listen 0.0.0.0:4954 --skip-update --token mail2Uyu
```

### 3. 启动client端
client端命令如下
> --cache-dir 声明缓存的路径
> --severity  扫描的漏洞安全级别
> --vuln-type 扫描的漏洞类型
> --format    声明报告格式
> --output    输出的日志位置
> --ignore-unfixed 忽略未修复的漏洞

```bash
trivy client --remote http://10.15.6.105:32449 --token mail2Uyu \
             --cache-dir /root/.cache/trivy \
             --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL \
             --vuln-type os \
             --ignore-unfixed \
             --format json \
             --output /root/.cache/reports/scan_report_984890059.json \
             ubuntu:20.04
```

## 使用 trivy 直接扫描
```bash
trivy  --cache-dir /root/.cache/trivy \
       --severity CRITICAL \
       --vuln-type os \
       --format json \
       --output /root/.cache/reports/18.04.json \
       centos:centos7.8.2003
```

## trivy 跳过 误报漏洞
在trivy命令执行的同级目录下， 创建`.trivyignore`文件。以类似下面内容配置忽略的漏洞
```bash
$ cat .trivyignore
# Accept the risk
CVE-2018-14618

# No impact in our settings
CVE-2019-1543
```

# Reference
[获取trivy漏洞库](https://github.com/aquasecurity/trivy/issues/423)
[忽略特定的漏洞](https://github.com/aquasecurity/trivy#ignore-the-specified-vulnerabilities)

[trivy支持的os](https://github.com/aquasecurity/trivy#os-packages)

[bug-使用厂商(比如. Redhat)提供的危险等级](https://github.com/aquasecurity/trivy/issues/310)
[issue-不能使用非官方源装包(包括自制的包or国内源装包)](https://github.com/aquasecurity/trivy/issues/403)
