---
title: Jenkins-Pipeline脚本易错汇总
categories:
  - Devops
tags:
  - Devops
  - Jenkins
  - Pipeline
date: '2024-09-10 09:16:33'
top: false
comments: true
---

## 问题

脚本中无法使用重定向，报错`Bash: Syntax error: redirection unexpected`。是因为ubuntu系统默认的shell为dash而非bash, dash不支持`<<<`重定向。
需要声明解释器`#!/bin/bash`，或者将命令放到脚本中，在脚本头部声明解释器。

### 在Pipeline脚本中执行复杂的bash命令
> 默认，将运行系统默认shell。 在 Shell 步骤中，可以接受多行。 因此，可以声明解释器选择器，如 `#!/bin/bash` 或 `#!/usr/bin/perl`。
> 注意：`#!/bin/bash`必须放在第一行，且前面不允许存在空格，否则会被忽略。

正确写法如下：
```groovy
stage('Setting the variables values') {
    steps {
         sh '''#!/bin/bash
                 echo "hello world" 
         '''
    }
}
```
错误写法举例:
```groovy
stage('Setting the variables values') {
    steps {
         sh '''
            #!/bin/bash
            echo "hello world"
         '''
    }
}
```

### 流水线之间参数传递

> 注意：参数的赋值与取值，必须要在`script{}`块内才能生效。

父流水线
```groovy
pipeline {
    agent {
        node { label 'linux' }
    }
    parameters {
        choice(
            name: 'choiceP',
            choices: ['A', 'B'],
            description: '<strong style="color:green;">A,B</strong>')
        listGitBranches(
            name: 'gitbranchP',
            defaultValue: 'master',
            credentialsId: 'gitlab-cred',
            remoteURL: 'https://github.com/example.git',
            description: '<strong style="color:green;">git分支选择,默认选择master分支</strong>',
            type: 'PT_BRANCH_TAG',
            tagFilter: '*',
            branchFilter: 'refs/heads/(.*)',
            quickFilterEnabled: true,
            selectedValue: 'NONE',
            sortMode: 'NONE')
    }
    environment {
        srcDir = 'example'
        timestamp = new Date().format('yyyyMMddHHmmss')
        TIMESTAMP_D = sh(script: "TZ=UTC-8 date +'%Y%m%d'", returnStdout: true).trim()
    }
    stages {
        stage('清理空间') {
            steps {
                cleanWs()
            }
        }
        stage('克隆代码') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "$gitbranchP"]],
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "$srcDir"]],
                    userRemoteConfigs: [[credentialsId: 'gitlab-cred', url: 'https://github.com/example.git']]])
            }
        }
        stage('并发构建') {
            parallel {
                stage('打包-A') {
                    steps {
                        script {
                            jobA = build(
                                job: 'job-group/a-job',
                                parameters: [
                                    gitParameter(name: 'Branch', value: "${Branch}"),
                                    string(name: 'ParamsB', value: "${ParamsB}")]
                            )
                            a_fullpath = jobA.buildVariables.fullpath
                            a_filename = jobA.buildVariables.filename
                        }
                    }
                }
                stage('打包-B') {
                    steps {
                        script {
                            jobB = build(
                                job: 'job-group/b-job',
                                parameters: [
                                    gitParameter(name: 'Branch', value: "${Branch}"),
                                    string(name: 'ParamsB', value: "${ParamsB}")]
                            )
                            b_fullpath = jobB.buildVariables.fullpath
                            b_filename = jobB.buildVariables.filename
                        }
                    }
                }
            }
        }
    }
}
              
```

子流水线
```groovy
pipeline {
    agent {
        kubernetes {
            cloud 'k8s'
            defaultContainer 'build'
            yaml '''\
        apiVersion: v1
        kind: Pod
        spec:
          containers:
          - name: build
            image: devops/job-a:1.0.0
            imagePullPolicy: "Always"
            tty: true
        nodeSelector:
          kubernetes.io/os: linux
        '''.stripIndent()
        }
    }

    options {
        timeout(time:20, unit:'MINUTES')
    }

    parameters {
        choice(
            name: 'ParamsB',
            choices: ['1', '2', '3'],
            description: '<strong style="color:green;">参数</strong>')
        listGitBranches(
            name: 'Branch',
            defaultValue: 'master',
            credentialsId: 'gitlab-cred',
            remoteURL: 'https://github.com/A.git',
            description: '<strong style="color:green;">git分支选择,默认选择master分支</strong>',
            type: 'PT_BRANCH_TAG',
            tagFilter: '*',
            branchFilter: 'refs/heads/(.*)',
            quickFilterEnabled: true,
            selectedValue: 'NONE',
            sortMode: 'NONE')
    }

    environment {
        srcDir = 'A'
    }
    stages {
      stage('克隆代码') {
            steps {
                script {
                    sh""" git clone -b "$Branch" https://github.com/A.git $srcDir """
                }
            }
        }
      stage('构建打包') {
            steps {
                script {
                    dir("$srcDir") {
                        env.commit_hash = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                        env.commit_time = sh(script: 'git show --pretty=format:"%ct" | head -1', returnStdout: true).trim()
                        env.filename = "A_${env.commit_hash}.tar.gz"
                        env.file_path = '/s3/bucketA/'
                        env.fullpath = "${env.file_path}/${env.filename}"
                    }
                }
            }
      }
    }
}
```

