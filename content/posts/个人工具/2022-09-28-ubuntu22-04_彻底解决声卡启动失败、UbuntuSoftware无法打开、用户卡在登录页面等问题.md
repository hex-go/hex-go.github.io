---
title: Ubuntu22.04：彻底解决声卡启动失败、UbuntuSoftware无法打开、用户卡在登录页面等问题
categories:
  - 个人工具
tags:
  - 个人工具
  - Ubuntu
date: '2022-09-30 07:26:26'
top: false
comments: true
draft: true
---

# 1.简介
> 最开始没有定位到根本原因，通过在`~/.profile`中声明XDG_RUNTIME_DIR环境变量的方式解决，结果导致用户登录卡在登录页面无法登入问题；后通过延迟微信容器启动的方式彻底解决。
问题描述：
- `systemctl --user status` 命令执行失败，报错为`process org.freedesktop.systemd1 exited with status 1`
- 开机后声卡驱动down导致无法音频输入输出
- 点击software无法打开(习惯性通过这个卸载和更新软件)
- 用户登录，输入正确的用户名密码，但仍卡在登录页面。将profile中设置的`export XDG_RUNTIME_DIR=/run/user/$(id -u)`注释则正常登入。

直接原因：
XDG_RUNTIME_DIR=/run/user/1000 环境变量未设置，导致systemctl --user 执行失败，表现为声卡驱动无法启动、ubuntu software无法打开、用户登录卡在登录页面无法登录。

根本原因：
docker run 的微信容器，其中存在挂卷` -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native`, 
并且设置的开机自启动，导致文件系统`/run/user/$(id -u)`被占用，*登录会话被打破，那么系统上的另一个系统（非用户）服务Docker正在创建此目录* 导致环境变量`XDG_RUNTIME_DIR`设置失败。


# 4.参考

[Runtime directory '/run/user/1000' is not owned by UID 1000, as it should](https://wiki.archlinux.org/title/systemd/User)
