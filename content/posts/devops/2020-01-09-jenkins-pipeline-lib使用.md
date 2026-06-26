---
title: Jenkins Pipeline 共享库使用说明
categories:
  - Devops
tags:
  - DevOps
date: 2020-02-23 00:00:00
top: false
comments: true
---

# 重要

Jenkins Pipeline 共享库用于复用流水线中的公共逻辑——避免每个项目的 Jenkinsfile 都复制同一段代码。

典型场景：

- 多个项目复用相同的构建、测试、部署步骤
- 统一 docker build/push 命令，项目只需声明镜像名
- 统一通知（企业微信、钉钉）逻辑

## 1.简介

Jenkins 共享库本质上是一个 Git 仓库，存放可重用的 Groovy 代码。每个 Pipeline 项目可以通过 `@Library` 注解引用，调用其中的方法或全局变量。

## 2.说明

### 2.1 共享库目录结构

```
(root)
+- src                     # Groovy 源文件
|   +- org
|       +- foo
|           +- Bar.groovy  # for org.foo.Bar class
+- vars                    # 全局变量
|   +- foo.groovy          # for global 'foo' variable
|   +- foo.txt             # help for 'foo' variable
+- resources               # 外部资源文件
|   +- org
|       +- foo
|           +- bar.json    # static helper data for org.foo.Bar
```

| 目录 | 作用 |
|------|------|
| `src` | Groovy 类，按 Java 包结构存放；Pipeline 执行时添加到 classpath |
| `vars` | 全局变量，文件名即变量名；`.groovy` 是代码，`.txt` 是该变量的帮助文档 |
| `resources` | 非 Groovy 资源文件，通过 `libraryResource` 加载 |

### 2.2 Jenkins 配置

#### 全局共享库

配置路径：`Manage Jenkins` → `Configure System` → `Global Pipeline Libraries`

需要 `Overall/RunScripts` 权限，权限较大，建议仅管理员配置。

![jenkins-add-lib](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/D5xXyc.jpg)

![global-pipeline-library-modern-scm](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/MPbG10.jpg)

### 2.3 Jenkinsfile 中引用

两种引用方式：

| 方式 | 配置 | 用法 |
|------|------|------|
| 隐式加载 | 勾选 `Load implicitly` | 直接调用共享库中的变量/方法 |
| 显式引用 | 不勾选 | 在 Jenkinsfile 文件头加 `@Library` |

![jenkins-global-pipeline-lib](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/5TNzoe.jpg)

显式引用语法：

```groovy
@Library('my-shared-library') _
@Library('my-shared-library@1.0') _
@Library(['my-shared-library', 'otherlib@abc1234']) _
```

| 语法 | 说明 |
|------|------|
| `@Library('name') _` | 引用默认分支 |
| `@Library('name@version') _` | 引用指定分支/tag |
| `@Library(['lib1', 'lib2@v1']) _` | 同时引用多个库 |

### 2.4 编写共享库代码

#### 方式一：src 目录（类方式）

共享库代码：

```groovy
// src/org/foo/Zot.groovy
package org.foo

def checkOutFrom(repo) {
  git url: "git@github.com:jenkinsci/${repo}"
}

return this
```

Jenkinsfile 中引用：

```groovy
def z = new org.foo.Zot()
z.checkOutFrom(repo)
```

#### 方式二：vars 目录（全局变量方式）

共享库代码：

```groovy
// vars/log.groovy
def info(message) {
    echo "INFO: ${message}"
}

def warning(message) {
    echo "WARNING: ${message}"
}
```

Jenkinsfile 中引用：

```groovy
@Library('utils') _

log.info 'Starting'
log.warning 'Nothing to do!'
```

#### 两种方式对比

| | src 类方式 | vars 全局变量 |
|------|-----------|--------------|
| 风格 | Groovy 类，new 实例化 | 全局函数，直接调用 |
| 适合 | 有状态的模块（如 git 操作封装） | 无状态的工具函数（如 log、notify） |
| 引用方式 | `new package.ClassName()` | 直接 `函数名.方法名()` |

### 2.5 最佳实践：完整流水线模板

一个典型的项目 CI/CD 流程包含：代码拉取 → 构建 → Docker 镜像构建 → Helm 部署。共享库的目标是让项目的 Jenkinsfile 只声明参数，不写重复逻辑。

#### 共享库仓库结构

```text
jenkins-shared-library/
├── vars/
│   ├── checkout.groovy      # 代码拉取
│   ├── build.groovy         # 构建（自动识别语言）
│   ├── docker.groovy         # Docker 镜像构建 & push
│   └── helm.groovy           # Helm 部署
│   └── pipeline.groovy       # 流水线模板（编排上面四个步骤）
└── resources/
    └── helm/
        └── values.yaml       # Helm 默认 values
```

#### 镜像命名规则

从 GitLab 仓库路径提取镜像名。

```text
Harbor 仓库：harbor.example.com/<父目录>/<仓库名>:<版本号>
                       ↑            ↑
                  gitGroup        repoName
```

实现：

```groovy
// 示例路径: git@gitlab.com:backend/user-service.git
// git rev-parse --show-prefix → backend/
// basename $(git rev-parse --show-toplevel) → user-service
// 最终镜像: harbor.example.com/backend/user-service:v1.0.0
```

#### vars/checkout.groovy

```groovy
def call(Map config) {
    def branch = config.branch ?: 'master'
    checkout([
        $class: 'GitSCM',
        branches: [[name: "*/${branch}"]],
        userRemoteConfigs: [[url: config.repoUrl]]
    ])
}
```

#### vars/build.groovy

```groovy
def call(Map config) {
    def buildCmd = config.buildCmd ?: './gradlew build'
    sh buildCmd
}
```

#### vars/docker.groovy

```groovy
def call(Map config) {
    def registry = config.registry ?: 'harbor.example.com'
    def gitPath = sh(script: 'git rev-parse --show-prefix', returnStdout: true).trim()
    def gitGroup = gitPath ? gitPath.replaceAll('/', '') : 'default'
    def repoName = sh(script: 'basename $(git rev-parse --show-toplevel)', returnStdout: true).trim()
    def tag = config.tag ?: sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    def image = "${registry}/${gitGroup}/${repoName}:${tag}"

    sh """
        docker build -t ${image} .
        docker push ${image}
    """
    return image
}
```

| 变量 | 来源 | 示例 |
|------|------|------|
| `registry` | 参数传入 | `harbor.example.com` |
| `gitGroup` | `git rev-parse --show-prefix` | `backend/` → `backend` |
| `repoName` | `basename $(git rev-parse --show-toplevel)` | `user-service` |
| `tag` | 参数或 `git rev-parse --short HEAD` | `a3f8b2c` |
| `image` | 拼接结果 | `harbor.example.com/backend/user-service:a3f8b2c` |

#### vars/helm.groovy

```groovy
def call(Map config) {
    def namespace = config.namespace ?: 'default'
    def chartPath = config.chartPath ?: './chart'
    def releaseName = config.releaseName ?: sh(script: 'basename $(git rev-parse --show-toplevel)', returnStdout: true).trim()

    sh """
        helm upgrade --install ${releaseName} ${chartPath} \
          --namespace ${namespace} \
          --set image.tag=${config.tag}
    """
}
```

#### vars/pipeline.groovy — 流水线模板

```groovy
def call(Map config) {
    def repoUrl = config.repoUrl
    def branch = config.branch ?: 'master'
    def buildCmd = config.buildCmd ?: './gradlew build'
    def namespace = config.namespace ?: 'default'
    def tag = config.tag ?: ''

    pipeline {
        agent any
        stages {
            stage('Checkout') {
                steps {
                    script { checkout(repoUrl: repoUrl, branch: branch) }
                }
            }
            stage('Build') {
                steps {
                    script { build(buildCmd: buildCmd) }
                }
            }
            stage('Docker Build & Push') {
                steps {
                    script {
                        env.DOCKER_IMAGE = docker(tag: tag)
                    }
                }
            }
            stage('Helm Deploy') {
                steps {
                    script { helm(namespace: namespace, tag: tag) }
                }
            }
        }
    }
}
```

#### 项目 Jenkinsfile

放在每个项目的 Git 仓库根目录，只需声明参数：

```groovy
@Library('jenkins-shared-library@v1') _

pipeline(
    repoUrl: 'git@gitlab.com:backend/user-service.git',
    branch: 'develop',
    buildCmd: './gradlew build',
    namespace: 'backend',
    tag: 'v1.0.0'
)
```

{{< keypoint >}}
项目 Jenkinsfile 只声明自身参数，不包含任何流程控制代码。流程由共享库 `pipeline.groovy` 统一管理，变更只需升级共享库版本。
{{< /keypoint >}}

### 2.6 父-子流水线调用

复杂场景下，父流水线需要调起多个子流水线并行执行（如多模块并行构建），并通过 `build` 步骤传递和接收参数。

父流水线 → 子流水线的传参方向：

```text
父流水线
  ├── build(job: 'child-a', parameters: [...])  →  子流水线 A
  ├── build(job: 'child-b', parameters: [...])  →  子流水线 B
  └── 收集 childResult.buildVariables           ←  子流水线返回
```

**关键限制**：`buildVariables` 必须在 `script {}` 块下才能访问，声明式 `steps {}` 内直接取会报空。

#### 子流水线（child-pipeline.groovy）

放在共享库 `vars/` 下，供父流水线调用：

```groovy
def call(Map config) {
    pipeline {
        agent any
        parameters {
            string(name: 'MODULE_NAME', defaultValue: '', description: '模块名')
            string(name: 'BASE_IMAGE', defaultValue: 'openjdk:11', description: '基础镜像')
        }
        stages {
            stage('Build') {
                steps {
                    script {
                        sh "./gradlew :${params.MODULE_NAME}:build"
                    }
                }
            }
        }
        post {
            success {
                script {
                    // 返回镜像名给父流水线
                    def imageTag = "${params.MODULE_NAME}:${env.BUILD_ID}"
                    buildVariables.put('IMAGE_TAG', imageTag)
                    buildVariables.put('STATUS', 'SUCCESS')
                }
            }
            failure {
                script {
                    buildVariables.put('STATUS', 'FAILED')
                }
            }
        }
    }
}
```

| 特性 | 说明 |
|------|------|
| `parameters {}` | 子流水线接收父流水线传入的参数 |
| `buildVariables.put()` | 子流水线向父流水线返回变量，写在 `script {}` 下 |
| post 阶段 | 无论成败都返回 `STATUS`，父流水线据此决定是否继续 |

#### 父流水线（parent-pipeline.groovy）

```groovy
def call(Map config) {
    def modules = config.modules ?: ['module-a', 'module-b']
    def imageMap = [:]

    pipeline {
        agent any
        stages {
            stage('Parallel Build') {
                steps {
                    script {
                        def builds = [:]
                        modules.each { module ->
                            builds[module] = {
                                def childJob = build(
                                    job: 'shared-lib/child-pipeline',
                                    parameters: [
                                        string(name: 'MODULE_NAME', value: module),
                                        string(name: 'BASE_IMAGE', value: config.baseImage)
                                    ],
                                    propagate: false,
                                    wait: true
                                )

                                // buildVariables 必须在 script {} 下访问
                                def status = childJob.buildVariables.STATUS
                                def imageTag = childJob.buildVariables.IMAGE_TAG

                                if (status == 'SUCCESS') {
                                    imageMap[module] = imageTag
                                    echo "${module} 构建成功，镜像: ${imageTag}"
                                } else {
                                    error "${module} 构建失败"
                                }
                            }
                        }
                        parallel builds
                    }
                }
            }
        }
    }
}
```

| 参数 | 说明 |
|------|------|
| `job` | 子流水线的完整路径名 |
| `parameters` | 父 → 子的传参，类型必须是 `string()` / `booleanParam()` 等 |
| `propagate: false` | 子流水线失败时不立即终止父流水线，由父代码自行处理 |
| `wait: true` | 父流水线等待子流水线执行完毕 |
| `childJob.buildVariables.XXX` | 子 → 父的返回值，**必须在 `script {}` 下** |

{{< keypoint >}}
`childJob.buildVariables` 必须在 `script {}` 块中访问，声明式 Pipeline 的 `steps {}` 直接取会是 null。
{{< /keypoint >}}

原因：Jenkins Pipeline 有两套执行引擎。

| 执行模式 | 入口 | 运行时 | 变量范围 |
|----------|------|--------|----------|
| 声明式 | `steps {}` | 受限的 CPS 运行时，只支持预定义的步骤指令 | 只认 Pipeline DSL 内置变量 |
| 脚本式 | `script {}` | 完整 Groovy CPS 运行时 | 可访问 `build()` 返回的 `RunWrapper` 对象 |

`build()` 方法返回一个 `RunWrapper` 对象，其 `buildVariables` 属性来自 Groovy 的动态元编程，不是 Pipeline DSL 的内置步骤。声明式 `steps {}` 只解析预定义的步骤指令（`sh`、`checkout`、`echo` 等），不解析 Groovy 对象属性链——`childJob.buildVariables.STATUS` 在声明式解析阶段直接返回 null。

所以正确的写法是：

```groovy
steps {
    script {
        // ✅ 在 script {} 内，完整 Groovy 运行时可以解析 buildVariables
        def status = childJob.buildVariables.STATUS
    }
}
```

而不是：

```groovy
steps {
    // ❌ 声明式 steps 内，buildVariables 不可用
    script { def childJob = build(job: '...') }
    echo childJob.buildVariables.STATUS   // null
}
```

{{< keypoint >}}
一句话：`steps {}` 只解析 Pipeline 步骤，`script {}` 解析 Groovy 代码。`buildVariables` 是 Groovy 运行时属性，不是 Pipeline 步骤，所以必须在 `script {}` 下。
{{< /keypoint >}}

## 3.总结

1. 共享库将重复的 Pipeline 逻辑抽取到独立 Git 仓库，Jenkinsfile 只声明项目特有参数；
2. 全局共享库配置权限大，建议仅管理员操作；
3. `src` 目录适合有状态模块，`vars` 目录适合无状态工具函数；
4. `@Library` 支持指定版本（分支/tag），有助于灰度上线新版本共享库。

## 4.参考

- [Jenkins 共享库官方文档](https://jenkins.io/zh/doc/book/pipeline/shared-libraries/)
