---
title: FeatMap-UserStory地图服务配置和搭建
categories:
  - Devops
tags:
  - Devops
  - Featmap
  - Dockerfile
  - Chart
date: '2022-03-25 02:17:47'
top: false
comments: true
---

# 重要
[Featmap](https://github.com/amborle/featmap)是一个用户故事映射工具，用于构建，计划和传达产品积压。

[Featmap Picture](https://github.com/amborle/featmap/raw/master/screenshot.png)

# 环境说明
服务依赖 Postgresql
[个人部署记录](https://github.com/hex-py/featmap-deploy)

# 安装
目录结构
```
.
├── charts
│   └── featmap
│       ├── Chart.yaml
│       ├── config
│       │   └── conf.json           # 配置文件： chart部署时， 运行环境的真实配置
│       ├── templates               
│       │   ├── configmap.yaml
│       │   ├── deployment.yaml
│       │   ├── _helpers.tpl
│       │   ├── ingress.yaml
│       │   └── svc.yaml
│       └── values.yaml             # chart值配置文件
├── conf.json                       # 配置文件： 构建镜像时， 打进镜像的默认配置
├── Dockerfile
├── Makefile
└── README.md
```

## 1. 构建Docker镜像

### 1.1 Dockerfile 内容如下:
```Dockerfile
FROM self.registry.com/ubuntu:20.04

WORKDIR /opt/featmap

COPY conf.json .
ADD https://github.com/amborle/featmap/releases/download/v2.1.0/featmap-2.1.0-linux-amd64 /usr/local/bin/featmap
RUN chmod 775 /usr/local/bin/featmap

EXPOSE 5000
ENTRYPOINT ["featmap"]
```

其中配置文件内容`conf.json`如下:
> 不支持环境变量，只能通过此配置文件修改环境配置
```json
{
  "appSiteURL": "https://localhost:5000",
  "dbConnectionString": "postgresql://gitea:gitea@pgsql-host:5432/postgres?sslmode=disable",
  "jwtSecret": "ChangeMeForProductionXXX",
  "port": "5000",
  "emailFrom": "",
  "smtpServer": "",
  "smtpPort": "587",
  "smtpUser": "",
  "smtpPass": "",
  "environment": "development"
}
```


### 1.2 构建镜像 命令
> 镜像地址: self.registry.com/featmap:2.1.0

```makefile
TAG := 2.1.0
IMAGE_PATH := self.registry.com/featmap
IMAGE := $(IMAGE_PATH):$(TAG)

.PHONY: docker-clean
docker-clean:
	@echo ">>>>>>>>>docker clean<<<<<<<<<"
	for i in $$(docker ps -a  |grep $(IMAGE_PATH) |awk '{print$$1}') ; do docker rm  -f $$i ; done
	for i in $$(docker images |grep $(IMAGE_PATH) |awk '{print$$3}') ; do docker rmi -f $$i ; done

.PHONY: build
build: docker-clean
	@echo ">>>>>>>>>docker build<<<<<<<<"
	docker build -t $(IMAGE) .
```

## 2. 部署
安装命令
线上配置通过`charts/featmap/config/conf.json`修改

```makefile
TAG := 2.1.0
IMAGE_PATH := hub.icos.city/icos/icospaas/featmap
IMAGE := $(IMAGE_PATH):$(TAG)

INSTANCE := featmap
CHART := charts/featmap

NAMESPACE := default
KUBECONFIG := /home/hex/.kube/config

.PHONY: push
push: build
	@echo ">>>>>>>>>docker push <<<<<<<<"
	docker push $(IMAGE)

.PHONY: helm-uninstall
helm-uninstall:
	@echo ">>>>>>>>>helm uninstall<<<<<<"
	helm --kubeconfig=$(KUBECONFIG) -n $(NAMESPACE) uninstall $(INSTANCE)

.PHONY: helm-install
helm-install: push
	@echo ">>>>>>>>>helm install<<<<<<<<"
	helm --kubeconfig=$(KUBECONFIG) -n $(NAMESPACE) install $(INSTANCE) $(CHART)
	
```
