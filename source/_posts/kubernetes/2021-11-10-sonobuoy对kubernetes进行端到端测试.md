---
title: sonobuoy对kubernetes进行端到端测试
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-11-10 08:21:32'
top: false
comments: true
---

# 重要

# 环境说明

# 安装

# 使用

## 
`sonobuoy images`      : list 相关的镜像列表
`sonobuoy images pull` : 
`sonobuoy images push` : 推送镜像至私有仓库
    --e2e-repo-config
`sonobuoy gen default-image-config`: 生成默认镜像仓库配置
`sonobuoy run`         : 启动测试
--systemd-logs-image     #指定日志采集镜像
--sonobuoy-image         # 指定Sonobuoy镜像
--e2e-repo-config        # 指定Sonobuoy用例镜像配置

`sonobuoy run \
--mode=certified-conformance \
--sonobuoy-image=xxx.yyy.zzz/library/sonobuoy:v0.53.2 \
--kubernetes-version=v1.18.16 \
--systemd-logs-image=xxx.yyy.zzz/library/systemd-logs:v0.3 \
--e2e-repo-config=./conformance-image-config.yaml`

`sonobuoy delete`      : 清理环境 
# Reference