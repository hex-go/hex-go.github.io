---
title: Buildpacks--研究、使用
categories:
  - Devops
tags:
  - Devops
date: '2020-08-14 06:13:39'
top: false
comments: true
draft: true
---

# 介绍

Buildpacks 是针对构建包的工具，可用于为项目快速创建 Docker 镜像，而无需编写单独的 Dockerfile。这意味着你可以高效地对多个项目进行 Docker 化，而无需为每个项目编写 Dockerfile。Buildpacks 可自动检测项目的编程语言和必要的依赖项，如 pom.xml、build.gradle 或 requirements.txt 文件。您只需为每个项目运行一个简单的命令，就能轻松集成到您的 CI/CD 管道中，自动创建 Docker 镜像。


# 环境说明

# 安装

# 与Dockerfile相比的利与弊

在容器化的世界里，效率、速度和简便性是最重要的，Buildpacks 已成为一种强大的工具，可以彻底改变为项目创建 Docker 映像的过程。与需要费力创建和维护 Dockerfile 的传统方法不同，Buildpacks 提供了一种简化的自动化解决方案。有了 Buildpacks，无论你要处理多少项目，都可以毫不费力地构建 Docker 镜像，而且无需 Dockerfile。让我们来探讨一下 Buildpacks 如何通过自动检测编程语言和项目结构来简化容器化，从而使你能够将 Docker 镜像创建无缝集成到你的 CI/CD 管道中。

## 缺点

- **与Docker版本的兼容问题的**：我在构建机器上使用 19.03.5 版 Docker，在尝试使用 Buildpacks 时遇到了一个问题。出现了以下错误（请记住，您需要 Docker 版本大于 20 才能使用较新版本的 builder-jammy-base 镜像生成器）：

- **无法指定Maven的次要版本**：Buildpack paketo-buildpacks/maven 不支持更改 Maven 的次要版本。例如，如果你的项目无法使用 Maven 3 的最新次版本编译，就需要使用 Maven Wrapper。使用 Maven 封装程序非常简单，只需运行以下命令即可为项目初始化 Maven 封装程序
```bash
$ mvn wrapper:wrapper -Dmaven=3.6.3
$ ./mvnw clean package
```

- **构建包环境变量不可变**：默认情况下，构建包会在构建容器中设置一些默认环境变量。在某些情况下，可能需要修改或删除这些变量。不过，你只能修改它们，而不能删除它们。例如，我在尝试从构建包的构建容器中移除 NODE_ENV 环境变量时无法删除，及时能删除也会导致许多问题。

- 多语言项目使用 Buildpacks 会比较复杂：多语言项目最好不要使用 Buildpacks。虽然 Buildpacks 确实支持多语言项目，但定制它们可能很费时间。例如，为一个后端使用 Spring 框架、前端使用 Vue.js 的项目创建一个 Docker 镜像。这两个部分都在一个git仓库中，就必须指定以下参数，以告知 Buildpacks 这是一个多语言项目： 
  BP_JVM_VERSION: 描述项目的 Java 版本 。
  BP_NODE_VERSION: 为构建项目指定所需的 Node.js 版本。
  BP_JAVA_INSTALL_NODE: 要求 Buildpacks 在构建容器上安装 Node。
  BP_NODE_PROJECT_PATH: Vue.js 文件在项目中的位置。
  定制过程可能相当复杂，尤其是对于多语言项目。
  ```markdown
   pack build test \
    --env 'BP_JVM_VERSION=8' \
    --env 'BP_MAVEN_BUILD_ARGUMENTS=clean package install -U' \
    --env 'BP_NODE_VERSION=16.20.0' \
    --env 'BP_JAVA_INSTALL_NODE=true' \
    --env 'BP_NODE_PROJECT_PATH=src/main/frontend'
    --builder=buildpacks/builder-jammy-base:0.1.0
  ```

- 离线的情况下运行：buildpack 高度依赖互联网。如果构建环境是离线环境（出于安全原因），则需要更改其下载源。


## 总结

在容器化已成为软件开发基石的时代，Buildpacks 成为了改变游戏规则的工具，它可以简化为项目制作 Docker 镜像的过程。通过消除传统 Dockerfile 创建和维护的复杂性，Buildpacks 提供了一种自动化的高效方法。由于能够毫不费力地构建 Docker 镜像，而且无需 Dockerfile，它们使开发人员能够无缝地处理多个项目。Buildpacks 擅长识别项目的编程语言和结构，允许自动创建 Docker 映像，并可无缝集成到 CI/CD 管道中。





# Reference
[Buildpack脚本说明](https://docs.pivotal.io/pivotalcf/2-6/buildpacks/understand-buildpacks.html)
[Buildpacks.io--应用开发者使用说明](https://buildpacks.io/docs/app-developer-guide/)
[Buildpacks.io--buildpack开发说明](https://buildpacks.io/docs/buildpack-author-guide/)
[Buildpacks.io--builder开发说明](https://buildpacks.io/docs/operator-guide/)

[heroku-buildpacks](https://devcenter.heroku.com/articles/buildpacks)
[heroku-Getting Started with Java](https://devcenter.heroku.com/articles/getting-started-with-java#deploy-the-app)
[heroku-Using a Custom Maven Settings File](https://devcenter.heroku.com/articles/using-a-custom-maven-settings-xml)
[heroku-buildpack for java(include mvn ops set)](https://github.com/heroku/heroku-buildpack-java)

[flynn-gitreceive](https://github.com/flynn/flynn/tree/master/gitreceive)
[flynn-sluggerBuilder](https://github.com/flynn/flynn/tree/master/slugbuilder)
