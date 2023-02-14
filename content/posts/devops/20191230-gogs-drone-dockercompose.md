---
title: gogs-drone-dockercompose
categories:
  - Devops
tags:
  - Devops
  - CI/CD
  - Drone
  - Gogs
  - Docker
date: '2019-12-30 11:44:00'
top: false
comments: true
---
# 重要
> 1. `Drone`登录的账号需要在`Gogs`设置为管理员，他俩兄弟的账密是互通的
> 2. `Gogs`的仓库会自动同步到`Drone`上，此时，需要在`Drone`开启激活该项目才能正常运行，激活后能在Gogs仓库WeHooks多一个记录。
> 3. Drone默认读取的配置文件名为项目根下`.drone.yml`，如果仓库内文件名不是。需要再Drone-setting中做修改。

# 正文
`CI / CD`( 持续集成 / 持续部署  )方案是DevOps中不可或缺的流程之一，本文简单介绍选择 `Gogs` + `Drone` 通过`docker compose`部署。

|主机名        | gitLab + jenkins                                                                                      | Gogs + Drone              |NUM|
|-------------|-------------------------------------------------------------------------------------------------------|---------------------------|---|
| 成熟度       | GitLab是一个非常成熟的git工具之一，同时Jenkins也是非常成熟的CICD组件，功能非常强大。                           | 性能高，并且简单易用         | 1 |
| 语言技术栈   | `GitLab`是使用`Ruby`编写的，`Jenkins`更是了不起，使用`Java`来编写的，项目整体比较膨大，同时它们对硬件、CPU等开销比较高 | `Drone`、`Gogs`皆是使用`Go`语言来编写构建，在整体的语言性能与内存开销算是有一定的优势 | 2 |

> Drone是一种基于容器技术的持续交付系统。Drone使用简单的YAML配置文件（docker-compose的超集）来定义和执行Docker容器中的Pipelines。Drone与流行的源代码管理系统无缝集成，包括GitHub，GitHub Enterprise，Gogs，Bitbucket等。


## 镜像说明

`drone`升级使用`1.0.0-rc6`版本，此版本并非稳定版本，推荐使用`1`版本甚至是`0.8.6`更稳定的版本。`1.0`后的版本较之前而言，配置更加灵活、优化版本，同时界面也变化了。[drone](https://drone.io/)


## 环境准备

使用的前提，必须符合以下条件
- 系统安装了`Docker`，同时要安装了`Docker`编排工具`docker-compose`
- 主流的`x64`位系统，`Linux`、`Mac`、`Window`等
- 安装了`git`版本控制工具


## 安装
安装非常简单，拉取`docker-compose.yml`编排文件，基于`Docker`环境自动构建即可！

docker-compose: `https://github.com/alicfeng/gogs-drone-docker.git/deployment/`
```yaml
version: "2"
services:
  gogs:
    container_name: gogs
    image: gogs/gogs:0.11.91
    ports:
      - 3000:3000
      - 10022:22
    volumes:
      - ./data/gogs/data:/data
    environment:
      - TZ=Asia/Shanghai
    restart: always
    networks:
      - dronenet

  drone-server:
    image: drone/drone:1.6.1
    container_name: drone-server
    ports:
      - 8000:80
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data/drone/:/var/lib/drone
    environment:
      - DRONE_OPEN=true
      - DRONE_SERVER_HOST=drone-server:8000
      - DRONE_DEBUG=true
      - DRONE_GIT_ALWAYS_AUTH=false
      - DRONE_GOGS=true
      - DRONE_GOGS_SKIP_VERIFY=false
      - DRONE_GOGS_SERVER={http://gogs:3000}
      - DRONE_PROVIDER=gogs
      - DRONE_SERVER_PROTO=http
      - DRONE_RPC_SECRET=7b4eb5caee376cf81a2fcf7181e66175
      - DRONE_USER_CREATE=username:alic,admin:true
      - DRONE_DATABASE_DATASOURCE=/var/lib/drone/drone.sqlite
      - DRONE_DATABASE_DRIVER=sqlite3
      - TZ=Asia/Shanghai
    restart: always
    networks:
      - dronenet

  drone-agent:
    image: drone/agent:1.6.1
    container_name: drone-agent
    depends_on:
      - drone-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_RPC_SERVER={docker-server:8000}
      - DRONE_RPC_SECRET=7b4eb5caee376cf81a2fcf7181e66175
      - DRONE_RUNNER_CAPACITY=2
      - DRONE_DEBUG=true
      - TZ=Asia/Shanghai
    restart: always

  nginx:
    image: nginx:alpine
    container_name: drone_nginx
    ports:
      - "80:80"
    restart: always
    networks:
      - dronenet
networks:
  dronenet:
```

执行以下命令，创建容器、网络
```bash
docker-compose up -d
```
修改Nginx配置
```bash
docker exec -it nginx ash
```
容器内执行以下命令
```bash
vim /etc/nginx/conf.d/drone.conf

server {
    listen       80;
    server_name drone.qloud.com;
    location / {
        proxy_pass http://drone-server:8000;
        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
    }
}

nginx -s reload
```

运行 `docker-runner`
```bash
docker run -d \
           -v /var/run/docker.sock:/var/run/docker.sock \
           -e DRONE_RPC_PROTO=http \
           -e DRONE_RPC_HOST=10.8.3.206:8000 \
           -e DRONE_RPC_SECRET=7b4eb5caee376cf81a2fcf7181e66175 \
           -e DRONE_RUNNER_CAPACITY=2 \
           -e DRONE_RUNNER_NAME=${HOSTNAME} \
           -p 3002:3000 \
           --restart always \
           --name docker-runner \
           drone/drone-runner-docker:1
```

## 使用
每当分支的代码更新的时候，Gogs会动过钩子同步通知Drone，而Drone收到通知后根据`.drone.yml`配置执行命令。
 - 通过git `clone`分支代码到容器里面
 - 单元测试, 代码静态检查
 - 编译代码，构建可执行文件
 - build image镜像，发布到`Registry`
 - 部署至生产环境
 - 发送邮件等通知信息，这里还有很多插件，比如微信、钉钉、电报等


**[价值源于技术，技术源于分享](https://github.com/hex-go)**

# Reference
[Nginx代理](https://www.jianshu.com/p/5d36ccb5af88)