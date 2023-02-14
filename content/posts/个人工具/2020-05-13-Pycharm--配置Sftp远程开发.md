---
title: Pycharm配置Sftp远程开发
categories:
  - 个人工具
tags:
  - Python
  - Pycharm
  - 个人工具
date: '2019-12-13 08:49:00'
sticky: 0
comments: true
---

# 配置pycharm 同步代码至docker容器
[参考连接](https://zhuanlan.zhihu.com/p/52827335)
## 容器配置
1. 22端口暴露：
    ```bash
    docker run --name chartbackend -d -p 5556:5555 -p8022:22 reg.qloudhub.com/qloudpaas/chartbackend:latest4
    ```
2. 安装配置ssh服务
    ```bash
    # Ubuntu 16.04
    apt install openssh-server
    
    sed -i's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    # sed 's@sessions*requireds*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
    # echo "export VISIBLE=now" >> /etc/profile
    service ssh restart
    ```
3. 设置容器用户名密码
    ```bash
    passwd
    # 查看用户
    whoami
    ```

## pycharm配置

1. add sftp server
> PyCharm  Tools > Deployment > Configuration

![picture_sftp_setting_connect](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/LuEFMK.jpg)

![picture_sftp_setting_mapping](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/8am7PP.jpg)

2. set project interpreter use sftp's
> 点击 PyCharm 的 File > Setting > Project > Project Interpreter 右边的设置按钮新建一个项目的远程解释器：

![picture_project_interpreter_use_sftp](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/cFekKv.jpg)