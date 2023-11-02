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
> 1. 能在DockerFile中做的，比如多阶段构建，就在dockerfile中做。不能再jenkinsfile中做太多特例化的事情，否则不好管理迁移。
> 2. 如果有时间，可以做一个简单的ui来配置生成jenkinsfile，这样就可以省去开发学习jenkinsFile的成本。也可以限制住，把控标准。

# JenkinsFile 文档目录

1. 拉代码
2. 代码构建
3. 构建+推送镜像
4. 推送初始化脚本
5. 推送chart


## 1 拉带码
```groovy
    stage('Check out') {
        checkout scm
    }
```
### 1.1 镜像版本控制  --  {ver}
master  --> latest
release --> stable
TAG       --> 保持不便 

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
  jenkins配置的job名为 'qloudobp-customer-profiles'  选择 master 分支构建
  $JOB_NAME         : qloudobp-customer-profiles/master
  name_list         : ['qloudobp-customer-profiles', 'master']
  ver               : 'master'
  job               : 'qloudobp-customer-profiles'
  job_list          : ['qloudobp', 'customer', 'profiles']
  project           : qloudobp
  job_size          : 2
  img_list          : ['customer', 'profiles']
  img               : customer-profiles
  ver               : 'latest' (重赋值)
  tag               : "reg.qloud.com/qloudobp/customer-profiles:latest"
  script_dir        :  qloudobp/customer-profiles/latest
  slug_dir          : /tmp/qloudobp/customer-profiles/latest
  slug_file         : /tmp/qloudobp/customer-profiles/latest/slug.tgz
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

    def tag       = "reg.qloud.com/'${ project }'/'${ img }':'${ ver }'"
    //  def tag   = "reg.qloud.com"+"/"+project+'/'+img+':'+ver
    def script_dir= project+'/'+img+'/'+ver
    def slug_dir  = "/tmp/'${script_dir}'"
    def slug_file = "'${slug_dir}'/qloudmart.tgz"
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
            dir('QloudMartUI'){
                sh 'npm install'
                sh "${ng_cmd}"
            }
            dir('QloudMartUI/qloudmart'){
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
    // 在QloudMartUI目录，将当前文件夹除去.git src 的所有内容打成 slug.tgz包
    // 目录结构为： /tmp/{project}/{img}/{ver}/slug.tgz
    dir('QloudMartUI'){
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
项目根目录下如果没有/deploy/install.sh 那么说明该项目不需要初始化脚本，paas
```groovy
stage('Send script') {
    def exists = fileExists './deploy/install.sh'
    if (exists) {
        sh("tar -zcvf deploy.tgz deploy/")
        sh("curl -v -u qloudinstall:qloudinstall123 -X POST 'http://qloudnexus.mart.service.sd/service/rest/v1/components?repository=qloudinstall' -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'raw.directory=${script_dir}' -F 'raw.asset1=@deploy.tgz;type=application/x-compressed-tar' -F 'raw.asset1.filename=deploy.tgz'")
    } else {
        println "File doesn't exist"
    }
}
```

## 5. 推送chart
```groovy
stage('Send Helm') {
    def gitUrl = 'https://192.168.11.21/plugins/git/qloudlet/charts.git'
    def gitCredentialsId = '4116a55e-8551-46b7-b864-d182d6e16657'
    git credentialsId: "${ gitCredentialsId }", url: "${ gitUrl }"
    helm package ''
    curl -X POST "http://192.168.11.130:8081/service/rest/v1/components?repository=market" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "helm.asset=@qloudmonitor-1.2.1.tgz;type=application/x-compressed-tar"
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
//例 在 **.git/QloudMartUI 目录下 执行编译命令
dir('QloudMartUI/qloudmart'){
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

    name_list     = "$JOB_NAME".split('/') //eg : 'qloudservice-qloudapi/master' --> ['qloudservice-qloudapi', 'master']
    def ver       = name_list[1]           //eg : 'master'
    def job       = name_list[0]           //eg : 'qloudservice-qloudapi'
    job_list      = "$job".split('-')      //eg : 'qloudservice-qloudapi' --> ['qloudservice', 'qloudapi']
    def project   = job_list[0]            //eg : 'qloudservice'
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

    def tag = "reg.qloud.com/'${ project }'/'${ img }':'${ ver }'"
    //  def tag = "reg.qloud.com"+"/"+project+'/'+img+':'+ver
    def script_dir= project+'/'+img+'/'+ver
    def slug_dir  = "/tmp/'${script_dir}'"
    def slug_file = "'${slug_dir}'/qloudmart.tgz"

    try {
        stage('Check out') {
            checkout scm
        }
        stage('Cleanup-before') {

            withEnv(["PATH+NODE=${ nodeHome }/bin"]) {
                // sh 'npm prune'
                 sh "rm -rf QloudMartUI/node_modules"
                 sh "rm -rf QloudMartUI/package-lock.json"
                 sh "rm -rf QloudMartUI/qloudmart/node_modules"
                 sh "rm -rf QloudMartUI/qloudmart/package-lock.json"
            }

        }
        stage('Build') {

            withEnv(["PATH+NODE=${ nodeHome }/bin"]) {
                dir('QloudMartUI'){
                    sh 'npm install'
                    sh "${ng_cmd}"
            }
                dir('QloudMartUI/qloudmart'){
                    sh 'npm install'
            }
            }

        }
        stage('Docker build') {
            sh("mkdir -p '${ slug_dir }'")
            dir('QloudMartUI'){
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
                sh("curl -v -u admin:admin123 -X POST 'http://qloudnexus.mart.service.sd/service/rest/v1/components?repository=qloudinstall' -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'raw.directory=${script_dir}' -F 'raw.asset1=@deploy.tgz;type=application/x-compressed-tar' -F 'raw.asset1.filename=deploy.tgz'")

            } else {
                println "File doesn't exist"
            }

        }
        stage('Send Helm') {
            def gitUrl           = 'https://192.168.11.21/plugins/git/qloudmart/market-service.git'
            def gitCredentialsId = '4116a55e-8551-46b7-b864-d182d6e16657'
            git credentialsId: "${ gitCredentialsId }", url: "${ gitUrl }"
            curl -X POST "http://192.168.11.130:8081/service/rest/v1/components?repository=market" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "helm.asset=@qloudmonitor-1.2.1.tgz;type=application/x-compressed-tar"
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
FROM reg.qloud.com/qloudpaas/node:8.12
# Create app directory
RUN mkdir -p /usr/src/app
# Bundle app source

ADD ./QloudMartUI/qloudmart.tgz /usr/src/app
WORKDIR /usr/src/app/qloudmart
ENV NODE_ENV dev
CMD ["/usr/src/app/qloudmart/start.sh"]
EXPOSE 8080
# Build image
# docker build -t qloud_market:v1 .
#image save
#docker save d38ea8888a73   -o ~/work/thirdCode/QloudMarket/QloudMarket.tar
#docker images|grep none|awk '{print "docker rmi -f " $3}'|sh
# docker rm -f $(docker ps -q -a)
#tar zcvf qloudmart.tgz qloudmart
# Run docker
# docker run -e SYSTEMCONFIG='{"port":"8080","url":"http://49.4.93.173:32090"}' -p 8080:8080  qloud_market:v1
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

    name_list     = "$JOB_NAME".split('/') //eg : 'qloudservice-qloudapi/master' --> ['qloudservice-qloudapi', 'master']
    def ver       = name_list[1]           //eg : 'master'
    def job       = name_list[0]           //eg : 'qloudservice-qloudapi'
    job_list      = "$job".split('-')      //eg : 'qloudservice-qloudapi' --> ['qloudservice', 'qloudapi']
    def project   = job_list[0]            //eg : 'qloudservice'
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

    def tag = "reg.qloud.com/'${ project }'/'${ img }':'${ ver }'"
    //  def tag = "reg.qloud.com"+"/"+project+'/'+img+':'+ver
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
                sh("curl -v -u admin:admin123 -X POST 'http://qloudnexus.mart.service.sd/service/rest/v1/components?repository=qloudinstall' -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'raw.directory=${script_dir}' -F 'raw.asset1=@deploy.tgz;type=application/x-compressed-tar' -F 'raw.asset1.filename=deploy.tgz'")

            } else {
                println "File doesn't exist"
            }

        }
        stage('Send Helm') {
            def gitUrl           = 'https://192.168.11.21/plugins/git/qloudlet/charts.git'
            def gitCredentialsId = '4116a55e-8551-46b7-b864-d182d6e16657'
            git credentialsId: "${ gitCredentialsId }", url: "${ gitUrl }"
            curl -X POST "http://192.168.11.130:8081/service/rest/v1/components?repository=market" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "helm.asset=@qloudmonitor-1.2.1.tgz;type=application/x-compressed-tar"
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
FROM reg.qloud.com/qloudpaas/jrunner:1.0.0
ENV LANG C.UTF-8
RUN set -x; \
    { \
        echo [program:customer-profile]; \
        echo command=/runner/init start web; \
        autorestart=true; \
    } > /etc/supervisor/conf.d/customer-profile.conf
```