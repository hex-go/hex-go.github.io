---
title: 基于Jenkins、gitlab、docker、helm和Kubernetes的CI/CD
categories:
  - Devops
tags:
  - Devops
  - Jenkins
  - JenkinsFile
  - Gitlab
  - Kubernetes
  - Docker  
date: '2019-12-31 07:05:19'
top: false
comments: true
---
# 重要

# 提前说明
> 1. 开发人员提交代码到 Gitlab 代码仓库
> 2. 通过 Gitlab 配置的 Jenkins Webhook 触发 Pipeline 自动构建
> 3. Jenkins 触发构建构建任务，根据 Pipeline 脚本定义分步骤构建
> 4. 先进行代码静态分析，单元测试
> 5. 然后进行 Maven 构建（Java 项目）
> 6. 根据构建结果构建 Docker 镜像
> 7. 推送 Docker 镜像到 Harbor 仓库
> 8. 触发更新服务阶段，使用 Helm 安装/更新 Release
> 9. 查看服务是否更新成功。

# 部署Jenkins

chart地址: `https://github.com/helm/charts/tree/master/stable/jenkins`

```bash
helm install --name jenkins stable/jenkins
```


# 1.后端服务容器化

```dockerfile
FROM maven:3.6-alpine as BUILD

COPY src /usr/app/src
COPY pom.xml /usr/app

RUN mvn -f /usr/app/pom.xml clean package -Dmaven.test.skip=true


FROM openjdk:8-jdk-alpine

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TZ=Asia/Shanghai

RUN mkdir /app

WORKDIR /app

COPY --from=BUILD /usr/app/target/polls-0.0.1-SNAPSHOT.jar /app/polls.jar

EXPOSE 8080

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar","/app/polls.jar"]
```
> 1. 页面打包到一个jar文件`build-container-/usr/app/target/polls-0.0.1-SNAPSHOT.jar`
> 2. 将上面jar文件添加到 `jdk-container-/app/polls.jar`目录

# 2. 前段服务容器化

```dockerfile
FROM node:alpine as BUILD

WORKDIR /usr/src/app

RUN mkdir -p /usr/src/app

ADD . /usr/src/app

RUN npm install && \
    npm run build


FROM nginx:1.15.10-alpine

COPY --from=BUILD /usr/src/app/build /usr/share/nginx/html

ADD nginx.conf
/etc/nginx/conf.d/default.conf
```
> 1. 页面打包到一个build目录`build-container-/usr/src/app/build`
> 2. 将上面目录添加到 `nginx-container-/usr/share/nginx/html`目录

# 3. Jenkins task配置

在 Pipeline 中去自定义`Slave Pod`中所需要用到的容器模板，需要什么镜像只需要在`Slave Pod Template`中声明即可，不需要安装了所有工具的`Slave`镜像。
首先Jenkins 中 kubernetes 配置，Jenkins -> 系统管理 -> 系统设置 -> 云 -> Kubernetes区域

![jenkins-k8s-plugin](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/S6c1uM.jpg)

新建一个名为`polling-app-server`类型为`流水线(Pipeline)`的任务：

![jenkins-new-job](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/RXzpgt.jpg)

勾选`触发远程构建`的触发器，其中令牌我们可以随便写一个字符串，然后记住下面的 URL，将 JENKINS_URL 替换成 Jenkins 的地址,我们这里的地址就是：`http://jenkins.qikqiak.com/job/polling-app-server/build?token=server321`

![jenkins-trigger](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/p5Ocmb.jpg)

在下面的流水线区域，可以选择`Pipeline script`，测试流水线脚本。正常配置选择`Pipeline script from SCM`，就是从代码仓库中通过`Jenkinsfile`文件获取`Pipeline script`脚本定义，选择 SCM 来源为Git。配置仓库地址`http://git.qikqiak.com/course/polling-app-server.git`，由于是在一个 Slave Pod 中去进行构建，所以如果使用 SSH 的方式去访问 Gitlab 代码仓库的话就需要频繁的去更新 SSH-KEY，所以直接采用用户名和密码的形式来访问：

![pipeline-scm](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/5jwRju.jpg)

在Credentials区域点击添加按钮添加我们访问 Gitlab 的用户名和密码：

![credentials](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/WCeT1i.jpg)

配置用于构建的分支，如果所有的分支需要进行构建，将`Branch Specifier`区域留空即可，一般情况下，只有不同的环境对应的分支才需要构建，比如 master、develop、test 等，平时开发的 feature 或者 bugfix 的分支没必要频繁构建，下图只配置 master 和 develop 两个分支用户构建：

![git-branch](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/xKquxA.jpg)

然后前往 Gitlab 中配置项目polling-app-server Webhook，settings -> Integrations，填写上面得到的 trigger 地址：

![jenkins-webhook](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/SDwnae.jpg)

保存后，可以直接点击`Test` -> `Push Event`测试是否可以正常访问 Webhook 地址，这里需要注意的是我们需要配置下 Jenkins 的安全配置，否则这里的触发器没权限访问 Jenkins，系统管理 -> 全局安全配置：取消`防止跨站点请求伪造`，勾选上`匿名用户具有可读权限`：

![jenkins-webhook-security-config](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/gRNfUd.jpg)

如果测试出现了`Hook executed successfully: HTTP 201`则证明 Webhook 配置成功了，否则就需要检查下 Jenkins 的安全配置是否正确了。

# 4. JenkinsFile

Clone 代码 -> 代码静态分析 -> 单元测试 -> Maven 打包 -> Docker 镜像构建/推送 -> Helm 更新服务
```groovy
def label = "slave-${UUID.randomUUID().toString()}"

podTemplate(label: label, containers: [
  containerTemplate(name: 'maven', image: 'maven:3.6-alpine', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'docker', image: 'docker', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'kubectl', image: 'hex/kubectl', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'helm', image: 'hex/helm', command: 'cat', ttyEnabled: true)
], volumes: [
  hostPathVolume(mountPath: '/root/.m2', hostPath: '/var/run/m2'),
  hostPathVolume(mountPath: '/home/jenkins/.kube', hostPath: '/root/.kube'),
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')
]) {
  node(label) {
    def myRepo = checkout scm
    def gitCommit = myRepo.GIT_COMMIT
    def gitBranch = myRepo.GIT_BRANCH

    stage('单元测试') {
      echo "测试阶段"
    }
    stage('代码编译打包') {
      container('maven') {
        echo "打码编译打包阶段"
      }
    }
    stage('构建 Docker 镜像') {
      container('docker') {
        echo "构建 Docker 镜像阶段"
      }
    }
    stage('运行 Kubectl') {
      container('kubectl') {
        echo "查看 K8S 集群 Pod 列表"
        sh "kubectl get pods"
      }
    }
    stage('运行 Helm') {
      container('helm') {
        echo "查看 Helm Release 列表"
        sh "helm list"
      }
    }
  }
}
```
> 1. `/root/.m2` 挂载为了`maven`构建添加缓存，否则每次构建重新下载依赖，太慢。
> 2. `~/.kube` 挂载为了让`kubectl`和`helm`访问 `Kubernetes` 集群。
> 3. `/var/run/docker.sock` 挂载为了`docker`客户端与`Docker Daemon`通信，构建镜像。
> 4. `label标签的定义` 使用 、`UUID`生成随机字符串，让`Slave Pod`每次的名称不一样，不会被固定在一个`Pod`上面了，而且有多个构建任务的时候就不会存在等待的情况.

# Reference
[k8s-deploy jenkins 动态slaves](https://www.qikqiak.com/post/kubernetes-jenkins1/)
[jenkins pipeline 部署k8s应用](https://www.qikqiak.com/post/kubernetes-jenkins2/)
[jenkin Blue Ocean 使用](https://www.qikqiak.com/post/kubernetes-jenkins3/)
[jenkins-pipeline to k8s](https://www.qikqiak.com/post/complete-cicd-demonstrate-1/)