---
title: GitHub-drone-dockercompose
categories:
  - Devops
tags:
  - Devops
  - Drone
  - CI/CD
  - Deployment
  - Docker
date: '2020-01-06 02:20:58'
top: false
comments: true
---

# 申请Github OAuth Application
> Github OAuth Application是为了授权`Drone Server`读取`Github`信息。
[参考连接](https://blog.yiranzai.cn/posts/26845/)

# 部署drone+mysql+nginx

部署的组件
+ Drone-server (中央Drone服务器)
+ Drone-agent  (接受来自中央Drone服务器的指令以执行构建Pipeline)
+ Mysql        (`Drone`默认的数据存储是`sqlite3`, 本次部署改用mysql)
+ Nginx        (使用`Nginx`来做对外服务代理)

Reference:
+ [Drone安装官方文档](https://docs.drone.io/installation/overview/)
+ [Drone集成GitHub官方文档](https://docs.drone.io/installation/providers/github/)
+ [DockerHub Mysql](https://hub.docker.com/_/mysql)
```yaml
version: "3.7"
services:
  nginx:
    image: nginx:alpine
    container_name: drone_nginx
    ports:
      - "80:80"
    restart: always
    networks:
      - dronenet
  mysql:
    image: mysql:5.7
    restart: always
    container_name: drone_mysql
    environment:
      - MYSQL_ROOT_PASSWORD=root_password
      - MYSQL_DATABASE=drone
      - MYSQL_USER=drone
      - MYSQL_PASSWORD=drone_password
    networks:
      - dronenet
    volumes:
      - /path/to/conf/my.cnf:/etc/mysql/my.cnf:rw
      - /path/to/data:/var/lib/mysql/:rw
      - /path/to/logs:/var/log/mysql/:rw
  drone-server:
    image: drone/drone:1.0.0-rc.5 #不要用latest,latest并非稳定版本
    container_name: drone-server
    networks: 
      - dronenet
    volumes:
      - ${DRONE_DATA}:/var/lib/drone/:rw
      - /var/run/docker.sock:/var/run/docker.sock:rw
    restart: always
    environment:
      - DRONE_DEBUG=true
      - DRONE_DATABASE_DATASOURCE=drone:drone_password@tcp(drone_mysql:3306)/drone?parseTime=true  #mysql配置，要与上边mysql容器中的配置一致
      - DRONE_DATABASE_DRIVER=mysql
      - DRONE_GITHUB_SERVER=https://github.com
      - DRONE_GITHUB_CLIENT_ID=${Your-Github-Client-Id}                                            #Github Client ID
      - DRONE_GITHUB_CLIENT_SECRET=${Your-Github-Client-Secret}                                    #Github Client Secret
      - DRONE_RUNNER_CAPACITY=2
      - DRONE_RPC_SECRET=YOU_KEY_ALQU2M0KdptXUdTPKcEw                                              #RPC秘钥
      - DRONE_SERVER_PROTO=http			                                                           #这个配置决定了你激活时仓库中的webhook地址的proto
      - DRONE_SERVER_HOST=dronetest.qloud.com
      - DRONE_USER_CREATE=username:hex,admin:true                                                  #管理员账号，一般是你github用户名
  drone-agent:
    image: drone/agent:1.0.0-rc.5
    container_name: dronetest_agent
    restart: always
    networks: 
      - dronenet
    depends_on:
      - drone-server                                                                               #依赖drone_server，并在其后启动
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
    environment:
      - DRONE_RPC_SERVER=http://drone-server:8000	                                               #drone用的http请求包，url一定要写上协议才能支持
      - DRONE_RPC_SECRET=YOU_KEY_ALQU2M0KdptXUdTPKcEw                                              #RPC秘钥，与drone_server中的一致
      - DRONE_DEBUG=true
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
# 使用

+ 1. 创建仓库，并保证仓库中存在`.drone.yml`文件;
+ 2. 访问drone服务， 并刷新。找到刷新出的新项目,点击active;
+ 3. 查看webhook中是否多出drone的webhook记录；
+ 4. 手动出发，看是否出发Drone构建过程。
> 注意： 
    1. 如果文件名要自定义，需要再drone active的设置里修改成自定义的名字， 负责会发生正常事件触发drone时失败，返回状态码与信息均为`N/A`
    2. Drone 的编写总体符合yaml格式, 但要注意，第一个构建步骤之前是不能加注释的, 否则会报错

举例
```yaml
pipeline:
  restore-cache:
    image: drillster/drone-volume-cache
    restore: true
    mount:
    - ./node_modules
    volumes:
    # Mount the cache volume, needs "Trusted" | https://docs.drone.io/administration/user/admins/
    # DRONE_USER_CREATE=username:{alicfeng},admin:true
    # source path {/tmp/cache/composer need to mkdir on server}
    - /tmp/cache/node_modules:/cache


  build-tests:
    image: node:latest
    commands:
    - node -v && npm -v
    - npm install -g cnpm --registry=https://registry.npm.taobao.org
    - cnpm install
    - npm run build


  rebuild-cache:
    image: drillster/drone-volume-cache
    rebuild: true
    mount:
    - ./node_modules
    volumes:
    - /tmp/cache/node_modules:/cache


  sit-deploy:
    image: appleboy/drone-ssh
    host: $host
    username: $username
    password: $password
    port: $port
    command_timeout: 300s
    script:
    # sit env deploy shell script list
      - cd /www/code.samego.com/
      - git pull
      - git pull
      - cnpm install -ddd
      - npm run build -ddd

  prod-deploy:
    image: appleboy/drone-ssh
    host: $host
    username: $username
    password: $password
    port: $port
    command_timeout: 300s
    script:
      # prod env deploy shell script list
      # todo awaiting extend to deploy | main scp
      - node -v && npm -v
      - cd /www/code.samego.com/
      - git pull
      - cnpm install -ddd
      - npm run build -ddd
    when:
      event:
        - push
      branch:
        - prod


  mail-notify:
    image: drillster/drone-email
    from: $from
    host: smtp.163.com
    username: $username
    password: $password
    port: 465
    subject: CICD fail notify
    recipients:
    - a@test.com
    when:
      status: [ failure ]
```

# Reference
[Drone CI for GitHub](https://juejin.im/post/5c81f54c5188257e826a9dc7)
[DrONE CD for k8s](https://juejin.im/entry/5bcd760e6fb9a05d382819fa)
