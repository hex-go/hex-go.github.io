TITLE := test
#  post模板名 := 目标文件夹
devops := devops
go := golang
k8s := kubernetes
self := 个人工具
ps := persistence
theory := 计算机原理

bash := bash

path := $($(type))/$(title)
BUILD_TIME=`date +%F`
FILE_NAME=$(BUILD_TIME)-$(TITLE).md
POST_PATH=source/_posts

test:
	@echo ">>>>>>>>>generate test<<<<<<<<<"
	@echo $(TYPE)
	@echo $(TITLE)
	@echo $(path)

post:
	@echo $(type)
	@echo $(title)
	@echo $(path)
    #hexo new --path $(path) $(type) $(title)

gen:
	hexo clean
	hexo generate

local: gen
	hexo s

publish: gen
	git commit -m "add some blog"

.PHONY: devops
devops:
	hexo new devops --path $(devops)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(devops)/$(FILE_NAME)

.PHONY: golang
golang:
	hexo new golang --path $(go)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(go)/$(FILE_NAME)

.PHONY: k8s
k8s:
	hexo new k8s --path $(k8s)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(k8s)/$(FILE_NAME)

.PHONY: self
self:
	hexo new self --path $(self)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(self)/$(FILE_NAME)

.PHONY: ps
ps:
	hexo new ps --path $(ps)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(ps)/$(FILE_NAME)

.PHONY: theory
theory:
	hexo new theory --path $(theory)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(theory)/$(FILE_NAME)

.PHONY: bash
bash:
	hexo new bash --path $(bash)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(bash)/$(FILE_NAME)
