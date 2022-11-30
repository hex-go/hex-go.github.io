TYPE:= bash
TITLE := test

#  post模板名 := 目标文件夹
devops := devops
go := golang
k8s := kubernetes
self := 个人工具
ps := persistence
theory := 计算机原理
leetcode := leetcode
bash := bash

path := $($(TYPE))/$(TITLE)
BUILD_TIME=`date +%F`
FILE_NAME=$(BUILD_TIME)-$(TITLE).md
POST_PATH=source/_posts
DRAFT_PATH=source/_drafts

types:
	@echo ">>>>>>>>>show types<<<<<<<<<"
	@echo Modles:  devops	go    k8s    self    ps    theory    leetcode    bash
	@echo Folders: $(devops) $(go) $(k8s) $(self) $(ps) $(theory) $(leetcode) $(bash)

show-drafts:
	@echo ">>>>>>>>>show drafts<<<<<<<<<"
	ls -1 $(DRAFT_PATH)/*.md |cut -d \/ -f 3 |cut -d . -f 1

post:
	@echo $(TYPE)
	@echo $(TITLE)
	@echo $(path)
    #hexo new --path $(path) $(type) $(title)

tool:
	npm i -g npm --registry https://registry.npm.taobao.org
	npm i -g yarn --registry https://registry.npm.taobao.org
	yarn config set registry https://registry.npm.taobao.org
	yarn install
	npm audit fix --force
	npm install hexo-generator-searchdb --save
	npm install -g hexo-cli@^3.1.0
	npm install -g hexo@3.9.0

gen:
	hexo clean
	hexo generate

local: gen
	hexo s

#publish: gen
#	git commit -m "add some blog"

.PHONY: devops
devops:
	hexo new devops --path $(devops)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(devops)/$(FILE_NAME)
	typora $(POST_PATH)/$(devops)/$(FILE_NAME)

.PHONY: golang
golang:
	hexo new golang --path $(go)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(go)/$(FILE_NAME)
	typora $(POST_PATH)/$(golang)/$(FILE_NAME)

.PHONY: k8s
k8s:
	hexo new k8s --path $(k8s)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(k8s)/$(FILE_NAME)
	typora $(POST_PATH)/$(k8s)/$(FILE_NAME)

.PHONY: self
self:
	hexo new self --path $(self)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(self)/$(FILE_NAME)

	typora $(POST_PATH)/$(self)/$(FILE_NAME)

.PHONY: ps
ps:
	hexo new ps --path $(ps)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(ps)/$(FILE_NAME)
	typora $(POST_PATH)/$(ps)/$(FILE_NAME)

.PHONY: theory
theory:
	hexo new theory --path $(theory)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(theory)/$(FILE_NAME)
	typora $(POST_PATH)/$(theory)/$(FILE_NAME)

.PHONY: bash
bash:
	hexo new bash --path $(bash)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(bash)/$(FILE_NAME)
	typora $(POST_PATH)/$(bash)/$(FILE_NAME)

.PHONY: leetcode
leetcode:
	hexo new leetcode --path $(leetcode)/$(FILE_NAME) $(TITLE)
	git add $(POST_PATH)/$(leetcode)/$(FILE_NAME)
	typora $(POST_PATH)/$(leetcode)/$(FILE_NAME)

.PHONY: draft
draft:
	hexo new draft $(TITLE)
	git add $(DRAFT_PATH)/$(TITLE).md
	git commit -m "feat($(TYPE)): add draft $(TITLE)"
	git push origin

.PHONY: publish
publish:
	hexo publish $(TYPE) $(TITLE)
	mv $(POST_PATH)/*-$(TITLE).md $(POST_PATH)/$($(TYPE))/
	git add $(POST_PATH)/$($(TYPE))/*-$(TITLE).md
	git commit -m "feat($(TYPE)): add post $(TITLE)"
	git push origin