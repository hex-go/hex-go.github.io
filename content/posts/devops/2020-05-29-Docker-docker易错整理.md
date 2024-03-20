---
title: Docker-Dockerfile的最佳实践
categories:
  - Devops
tags:
  - Devops
  - Docker
  - Dockerfile
date: '2020-05-29 09:36:32'
top: false

draft: true
comments: true
---

# 重要

# 1. 概念说明

- 构建`Context`说明
  执行`docker build`命令时，当前工作目录称为构建上下文。默认情况下，`dockerfile`也在当前目录，但可以使用文件标志（-f）指定不同的位置。 无论`dockerfile`实际在哪里，执行构建命令的当前目录中的文件和目录的所有递归内容都将作为`Context`发送到`Docker Daemon`程序。


