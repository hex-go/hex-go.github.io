---
title: 基于 Jenkins + GitLab + Docker + Helm + Kubernetes 的 CI/CD
categories:
  - Devops
tags:
  - Devops
  - Jenkins
  - JenkinsFile
  - Kubernetes
  - Docker
date: 2020-02-20 00:00:00
top: false
comments: true
---

# 重要

Pipeline 流程：代码推送 → GitLab Webhook → Jenkins 触发构建 → Maven 编译 → Docker 镜像构建/推送 → Helm 部署。

## 1. 部署 Jenkins

```bash
helm install jenkins stable/jenkins
```

## 2. Dockerfile

后端（Maven 多阶段构建）：

```dockerfile
FROM maven:3.6-alpine as BUILD
COPY src /usr/app/src
COPY pom.xml /usr/app
RUN mvn -f /usr/app/pom.xml clean package -Dmaven.test.skip=true

FROM openjdk:8-jdk-alpine
COPY --from=BUILD /usr/app/target/*.jar /app/app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

前端（Node + Nginx 多阶段构建）：

```dockerfile
FROM node:alpine as BUILD
WORKDIR /usr/src/app
ADD . /usr/src/app
RUN npm install && npm run build

FROM nginx:1.15.10-alpine
COPY --from=BUILD /usr/src/app/build /usr/share/nginx/html
```

## 3. Jenkinsfile（K8s Slave Pod）

```groovy
def label = "slave-${UUID.randomUUID().toString()}"

podTemplate(label: label, containers: [
  containerTemplate(name: 'maven',  image: 'maven:3.6-alpine', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'docker', image: 'docker',          command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'kubectl',image: 'hex/kubectl',     command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'helm',   image: 'hex/helm',        command: 'cat', ttyEnabled: true),
], volumes: [
  hostPathVolume(mountPath: '/root/.m2',                hostPath: '/var/run/m2'),
  hostPathVolume(mountPath: '/home/jenkins/.kube',      hostPath: '/root/.kube'),
  hostPathVolume(mountPath: '/var/run/docker.sock',     hostPath: '/var/run/docker.sock'),
]) {
  node(label) {
    def myRepo = checkout scm

    stage('单元测试')   { container('maven')  { echo "单元测试" } }
    stage('编译打包')   { container('maven')  { echo "编译打包" } }
    stage('Docker 镜像'){ container('docker') { echo "构建镜像" } }
    stage('Helm 部署')  { container('helm')   { sh "helm list" } }
  }
}
```

| Volume 挂载 | 用途 |
|------------|------|
| `/root/.m2` | Maven 依赖缓存，避免每次重新下载 |
| `~/.kube` | kubectl/helm 访问 K8s 集群 |
| `/var/run/docker.sock` | Docker 客户端与 Daemon 通信 |

`UUID.randomUUID()` 让每次构建的 Slave Pod 名称不同，避免多任务并发时阻塞在同一 Pod。

## 参考

- [Jenkins 动态 Slave 部署](https://www.qikqiak.com/post/kubernetes-jenkins1/)
- [Jenkins Pipeline 部署 K8s 应用](https://www.qikqiak.com/post/kubernetes-jenkins2/)
