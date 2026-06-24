---
title: PyCharm 配置 SFTP 远程开发
categories:
  - 个人工具
tags:
  - Python
  - PyCharm
  - 个人工具
date: '2019-12-13 08:49:00'
top: false
comments: true
draft: true
---

# 重要

PyCharm 的 SFTP 部署功能可以将本地代码自动同步到远程 Docker 容器，配合远程解释器实现本地编辑、远程运行。

## 1.简介

本地开发环境受限（如依赖特定 OS 包、需要 GPU）时，在远程容器中运行代码，本地 PyCharm 编辑并自动同步。

## 2.说明

### 2.1 容器侧配置

启动容器时映射 SSH 端口：

```bash
docker run --name dev -d -p 8022:22 -p 5556:5555 reg.example.com/dev:latest
```

进入容器安装并配置 SSH：

```bash
apt install openssh-server
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
service ssh restart
passwd
```

### 2.2 PyCharm 配置 SFTP

`Tools` → `Deployment` → `Configuration` → 添加 SFTP Server。

![picture_sftp_setting_connect](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/LuEFMK.jpg)

![picture_sftp_setting_mapping](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/8am7PP.jpg)

| 字段 | 值 |
|------|-----|
| Host | 容器所在宿主机 IP |
| Port | 8022（映射的 SSH 端口） |
| Root Path | 容器内项目路径（如 `/app`） |
| Mapping | 本地目录 ↔ 远程目录 |

### 2.3 配置远程解释器

`File` → `Settings` → `Project` → `Project Interpreter` → 添加 SSH Interpreter。

![picture_project_interpreter_use_sftp](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/cFekKv.jpg)

配置完成后，PyCharm 自动使用容器内的 Python 解释器运行和调试代码。

## 3.参考

- [PyCharm SFTP 远程开发](https://zhuanlan.zhihu.com/p/52827335)
