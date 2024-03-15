---
title: Jenkins-Pipeline使用举例
categories:
  - Devops
tags:
  - Devops
  - Jenkins
  - Pipeline
date: '2020-01-07 08:48:13'
top: false
comments: true
---
# 重点
> 1. 能在DockerFile中做的，比如多阶段构建，就在Dockerfile中做。不能在Jenkinsfile中做太多特例化的事情，否则不好管理迁移。
> 2. 如果有时间，可以做一个简单的ui来配置生成Jenkinsfile，这样就可以省去开发人员学习JenkinsFile的成本。也可以增加限制，把控标准。

# JenkinsFile 文档目录

1. 拉代码
2. 代码构建
3. 构建+推送镜像
4. 推送初始化脚本
5. 推送chart


## 1 拉取代码
```groovy
    stage('Check out') {
        checkout scm
    }
```
### 1.1 镜像版本控制  --  {ver}
master  --> latest
release --> stable
TAG     --> 保持不变 

```groovy
name_list     = "$JOB_NAME".split('/')
def ver       = name_list[1]
def ver_map = ["master": "latest", "release": "stable"]
if(ver_map.containsKey(ver)){
    ver = ver_map.get(ver)
}
```
### 1.2 镜像版本控制  --  {ver}
举例：
```
  jenkins配置的job名为 'paas-devops-ui'  选择 master 分支构建
  $JOB_NAME         : paas-devops-ui/master
  name_list         : ['paas-devops-ui', 'master']
  ver               : 'master'
  job               : 'paas-devops-ui'
  job_list          : ['paas', 'devops', 'ui']
  project           : paas
  job_size          : 2
  img_list          : ['devops', 'ui']
  img               : devops-ui
  ver               : 'latest' (重赋值)
  tag               : "reg.service.com/paas/devops-ui:latest"
  script_dir        :  paas/devops-ui/latest
  slug_dir          : /tmp/paas/devops-ui/latest
  slug_file         : /tmp/paas/devops-ui/latest/slug.tgz
```

```groovy
    name_list     = "$JOB_NAME".split('/') 
    def ver       = name_list[1]           
    def job       = name_list[0]     
    job_list      = "$job".split('-')      
    def project   = job_list[0]         
    job_size      = job_list.size()-1
    img_list      = []
    for(x in (1..job_size)){
        img_list.add(job_list[x])
    }
    def img       = img_list.join('-')

    def ver_map   = ["master": "latest", "release": "stable"]
    if(ver_map.containsKey(ver)){
        ver       = ver_map.get(ver)
    }

    def tag       = "reg.service.com/'${ project }'/'${ img }':'${ ver }'"
    //  def tag   = "reg.service.com"+"/"+project+'/'+img+':'+ver
    def script_dir= project+'/'+img+'/'+ver
    def slug_dir  = "/tmp/'${script_dir}'"
    def slug_file = "'${slug_dir}'/slug.tgz"
```

## 2. 代码构建
### 2.1 mvn项目构建
```groovy
    def mvnHome   = tool 'maven_3_5_4'
    
    stage('Build') {
        withEnv(["PATH+MAVEN=${ mvnHome }/bin"]) {
            sh "mvn clean package -DskipTests=true"
        }
    }
```
### 2.2 Node项目构建
```groovy
    def nodeHome  = tool 'NodeJS_8.12'
    stage('Build') {
    
        withEnv(["PATH+NODE=${ nodeHome }/bin"]) {
            dir('devops_ui'){
                sh 'npm install'
                sh "${ng_cmd}"
            }
            dir('devops_ui/devops'){
                sh 'npm install'
            }
        }
    }
```

## 3. Build+Push 镜像
```groovy
def script_dir= project+'/'+img+'/'+ver
def slug_dir  = "/tmp/'${script_dir}'"
def slug_file = "'${slug_dir}'/slug.tgz"
stage('Docker build') {
    // 创建存放代码slug包的目录
    sh("mkdir -p '${ slug_dir }'")
    // 在DevopsUI目录，将当前文件夹除去.git src 的所有内容打成 slug.tgz包
    // 目录结构为： /tmp/{project}/{img}/{ver}/slug.tgz
    dir('devops_ui'){
       sh("tar -z --exclude='.git' --exclude='src' -cf '${slug_file}' .")
    }
    // 将/tmp/{project}/{img}/{ver}/slug.tgz 拷贝到 Dockerfile 同级
    sh("cp ${slug_file} .")
    // docker构建
    sh("docker build -t ${tag} .")
    // 推送镜像
    sh("docker push ${tag}")
}
```

## 4. 推送初始化脚本
项目根目录下如果没有`/deploy/install.sh`, 那么说明该项目不需要初始化脚本，跳过。
```groovy
stage('Send script') {
    def exists = fileExists './deploy/install.sh'
    if (exists) {
        sh("tar -zcvf deploy.tgz deploy/")
        sh("curl -v -u username:password -X POST 'http://nexus.service.com/service/rest/v1/components?repository=paasinstall' -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'raw.directory=${script_dir}' -F 'raw.asset1=@deploy.tgz;type=application/x-compressed-tar' -F 'raw.asset1.filename=deploy.tgz'")
    } else {
        println "File doesn't exist"
    }
}
```

## 5. 推送chart
```groovy
stage('Send Helm') {
    def gitUrl = 'https://git.service.com/plugins/git/paas/charts.git'
    def gitCredentialsId = '4116a55e-8551-46b7-b864-xxxxxxxxxxxx'
    git credentialsId: "${ gitCredentialsId }", url: "${ gitUrl }"
    helm package ''
    curl -X POST "http://dop.service.com/service/rest/v1/components?repository=market" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "helm.asset=@monitor-1.2.1.tgz;type=application/x-compressed-tar"
}
```
## 6. 清理环境

```groovy
stage('Cleanup') {
    withEnv(["PATH+MAVEN=${ mvnHome }/bin"]) {
        sh "mvn -Dmaven.test.failure.ignore clean"
    }
    sh("docker rmi ${tag}")
    sh("rm -f ${slug_file}")
    sh "rm -rf *"
    sh "rm -rf .git"
}
```

# 项目个性化需求

## 前端命令

如果job名末尾为`-onlyapi` ng命令为 `ng build -c=onlyApi`
                否则     ng命令为 `ng build --prod`

```groovy
def nodeHome  = tool 'NodeJS_8.12'
def label = "$project".split('-')[-1]
def ng_cmd = "ng build --prod"

def ng_map = ["onlyapi": "ng build -c=onlyApi"]
if(ng_map.containsKey(label)){
    ng_cmd = ng_map.get(label)
}

withEnv(["PATH+NODE=${ nodeHome }/bin"]) {
    sh 'npm install'
    sh "${ng_cmd}"
}
```

## 在某个目录下执行命令
```groovy
//例 在 **.git/devops_ui 目录下 执行编译命令
dir('devops_ui/devops'){
    sh 'npm install'
}
```

# 完整示例
## node 项目
jenkinsFile:
```groovy
node {
    currentBuild.result = "SUCCESS"

    def ng_cmd = "ng build --prod"
    def nodeHome  = tool 'NodeJS_8.12'
    def ng_map = ["onlyapi": "ng build -c=onlyApi"]
    if(ng_map.containsKey(label)){
        ng_cmd = ng_map.get(label)
    }

    name_list     = "$JOB_NAME".split('/') //eg : 'devops-api/master' --> ['devops-api', 'master']
    def ver       = name_list[1]           //eg : 'master'
    def job       = name_list[0]           //eg : 'devops-api'
    job_list      = "$job".split('-')      //eg : 'devops-api' --> ['devops', 'api']
    def project   = job_list[0]            //eg : 'devops'
    job_size      = job_list.size()-1
    img_list      = []
    for(x in (1..job_size)){
    img_list.add(job_list[x])
    }
    def img       = img_list.join('-')

    def ver_map = ["master": "latest", "release": "stable"]
    if(ver_map.containsKey(ver)){
        ver = ver_map.get(ver)
    }

    def tag = "reg.service.com/'${ project }'/'${ img }':'${ ver }'"
    //  def tag = "reg.service.com"+"/"+project+'/'+img+':'+ver
    def script_dir= project+'/'+img+'/'+ver
    def slug_dir  = "/tmp/'${script_dir}'"
    def slug_file = "'${slug_dir}'/slug.tgz"

    try {
        stage('Check out') {
            checkout scm
        }
        stage('Cleanup-before') {

            withEnv(["PATH+NODE=${ nodeHome }/bin"]) {
                // sh 'npm prune'
                 sh "rm -rf devops_ui/node_modules"
                 sh "rm -rf devops_ui/package-lock.json"
                 sh "rm -rf devops_ui/devops/node_modules"
                 sh "rm -rf devops_ui/devops/package-lock.json"
            }

        }
        stage('Build') {

            withEnv(["PATH+NODE=${ nodeHome }/bin"]) {
                dir('devops_ui'){
                    sh 'npm install'
                    sh "${ng_cmd}"
            }
                dir('devops_ui/devops'){
                    sh 'npm install'
            }
            }

        }
        stage('Docker build') {
            sh("mkdir -p '${ slug_dir }'")
            dir('devops_ui'){
                sh("tar -z --exclude='.git' --exclude='src' -cf '${slug_file}' .")
            }
            sh("cp ${slug_file} .")
            sh("docker build -t ${tag} .")
            sh("docker push ${tag}")
        }
        stage('Send script') {
            def exists = fileExists './deploy/install.sh'
            if (exists) {
                sh("tar -zcvf deploy.tgz deploy/")
                sh("curl -v -u username:password -X POST 'http://nexus.service.com/service/rest/v1/components?repository=paasinstall' -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'raw.directory=${script_dir}' -F 'raw.asset1=@deploy.tgz;type=application/x-compressed-tar' -F 'raw.asset1.filename=deploy.tgz'")

            } else {
                println "File doesn't exist"
            }

        }
        stage('Send Helm') {
            def gitUrl           = 'https://git.service.com/plugins/git/paas/devops-api.git'
            def gitCredentialsId = '4116a55e-8551-46b7-b864-xxxxxxxxxxxx'
            git credentialsId: "${ gitCredentialsId }", url: "${ gitUrl }"
            curl -X POST "http://dop.service.com/service/rest/v1/components?repository=market" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "helm.asset=@monitor-1.2.1.tgz;type=application/x-compressed-tar"
        }

        stage('Cleanup') {
            withEnv(["PATH+MAVEN=${ mvnHome }/bin"]) {
                sh "mvn -Dmaven.test.failure.ignore clean"
                sh("docker rmi ${tag}")
                sh("rm -f ${slug_file}")
                sh "rm -rf *"
                sh "rm -rf .git"
            }
        }
    } catch (err) {
        currentBuild.result = "FAILURE"
        throw err
    }
}
```
DockerFile:
```dockerfile
FROM reg.service.com/paas/node:8.12
# Create app directory
RUN mkdir -p /usr/src/app
# Bundle app source

ADD ./devops_ui/slug.tgz /usr/src/app
WORKDIR /usr/src/app/devops_ui
ENV NODE_ENV dev
CMD ["/usr/src/app/devops_ui/start.sh"]
EXPOSE 8080
# Build image
# docker build -t devops-api:v1 .
#image save
#docker save d38ea8888a73   -o ~/work/thirdCode/paas/devops-api.tar
#docker images|grep none|awk '{print "docker rmi -f " $3}'|sh
# docker rm -f $(docker ps -q -a)
#tar zcvf devops.tgz devops
# Run docker
# docker run -e SYSTEMCONFIG='{"port":"8080","url":"http://49.4.93.173:32090"}' -p 8080:8080  devops_ui:v1
#数据格式 http://localhost:8080/api/products/seed
#{
#  "port":"8080",
#  "url":"http://49.4.93.173:32090"
#}
```
## maven 项目
jenkinsFile:
```groovy
node {
    currentBuild.result = "SUCCESS"
    def mvnHome   = tool 'maven_3_5_4'

    name_list     = "$JOB_NAME".split('/') //eg : 'devops-api/master' --> ['devops-api', 'master']
    def ver       = name_list[1]           //eg : 'master'
    def job       = name_list[0]           //eg : 'devops-api'
    job_list      = "$job".split('-')      //eg : 'devops-api' --> ['devops', 'api']
    def project   = job_list[0]            //eg : 'devops'
    job_size      = job_list.size()-1
    img_list      = []
    for(x in (1..job_size)){
    img_list.add(job_list[x])
    }
    def img       = img_list.join('-')

    def ver_map = ["master": "latest", "release": "stable"]
    if(ver_map.containsKey(ver)){
        ver = ver_map.get(ver)
    }

    def tag = "reg.service.com/'${ project }'/'${ img }':'${ ver }'"
    //  def tag = "reg.service.com"+"/"+project+'/'+img+':'+ver
    def script_dir= project+'/'+img+'/'+ver
    def slug_dir  = "/tmp/'${script_dir}'"
    def slug_file = "'${slug_dir}'/slug.tgz"

    try {
        stage('Check out') {
            checkout scm
        }

        stage('Build') {
            withEnv(["PATH+MAVEN=${ mvnHome }/bin"]) {
                sh "mvn clean package -DskipTests=true"        //执行mvn命令
            }
        }

        stage('Docker build') {
            sh("mkdir -p '${ slug_dir }'")
            sh("tar -z --exclude='.git' --exclude='src' -cf '${slug_file}' .")
            sh("cp ${slug_file} .")
            sh("docker build -t ${tag} .")
            sh("docker push ${tag}")
        }

        stage('Send script') {
            def exists = fileExists './deploy/install.sh'
            if (exists) {
                sh("tar -zcvf deploy.tgz deploy/")
                sh("curl -v -u admin:admin123 -X POST 'http://nexus.service.com/service/rest/v1/components?repository=paasinstall' -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'raw.directory=${script_dir}' -F 'raw.asset1=@deploy.tgz;type=application/x-compressed-tar' -F 'raw.asset1.filename=deploy.tgz'")

            } else {
                println "File doesn't exist"
            }

        }
        stage('Send Helm') {
            def gitUrl           = 'https://git.service.com/plugins/git/paas/charts.git'
            def gitCredentialsId = '4116a55e-8551-46b7-b864-xxxxxxxxxxxx'
            git credentialsId: "${ gitCredentialsId }", url: "${ gitUrl }"
            curl -X POST "http://dop.service.com/service/rest/v1/components?repository=market" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "helm.asset=@monitor-1.2.1.tgz;type=application/x-compressed-tar"
        }

        stage('Cleanup') {
            withEnv(["PATH+MAVEN=${ mvnHome }/bin"]) {
                sh "mvn -Dmaven.test.failure.ignore clean"
            }
            sh("docker rmi ${tag}")
            sh("rm -f ${slug_file}")
            sh "rm -rf *"
            sh "rm -rf .git"
        }
    } catch (err) {
        currentBuild.result = "FAILURE"
        throw err
    }
}

```
DockerFile:
```dockerfile
FROM reg.service.com/paas/jrunner:1.0.0
ENV LANG C.UTF-8
RUN set -x; \
    { \
        echo [program:customer-profile]; \
        echo command=/runner/init start web; \
        autorestart=true; \
    } > /etc/supervisor/conf.d/customer-profile.conf
```