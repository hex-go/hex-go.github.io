TYPE:= bash

#  post模板名 := 目标文件夹
CONTENT_DIR:=content/posts
devops := $(CONTENT_DIR)/devops
go := $(CONTENT_DIR)/golang
k8s := $(CONTENT_DIR)/kubernetes
self := $(CONTENT_DIR)/个人工具
ps := $(CONTENT_DIR)/persistence
theory := $(CONTENT_DIR)/计算机原理
leetcode := $(CONTENT_DIR)/leetcode
bash := $(CONTENT_DIR)/bash

path := $($(TYPE))/$(TITLE)
BUILD_TIME=`date +%F`
FILE_NAME=$(BUILD_TIME)-$(TITLE).md
POST_PATH=source/_posts
DRAFT_PATH=source/_drafts

# ！！！！正则在makefile中状态不正常、未解决
# 由于Windows(dos)与linux(unix)文件系统之间的文件命名要求不同，因此只允许TITLE命名包含字母、数字、_、-、. k8s_
check-title:
	@if ! echo "$(TITLE)" | grep -E '^[a-zA-Z0-9_\.\-]+$$' &>/dev/null; then echo "Error: '$(TITLE)' contains invalid characters.";fi

types:
	@echo ">>>>>>>>>show types<<<<<<<<<"
	@echo Modles:  devops	go    k8s    self    ps    theory    leetcode    bash
	@echo Folders: $(devops) $(go) $(k8s) $(self) $(ps) $(theory) $(leetcode) $(bash)

list-drafts:
	@echo ">>>>>>>>>show drafts<<<<<<<<<"
	@hugo list drafts

clean-build:
	# hugo设计 只对现有文件进行覆盖，不删除public目录的多余文件（避免删除用户在public手动放置的静态文件）。 按需手动删除
	rm -rf public/
	hugo --minify --gc --cleanDestinationDir

build:
	hugo

server:
	hugo server

.PHONY: devops
devops:
	hugo new --kind devops $(devops)/$(FILE_NAME)
	git add $(devops)/$(FILE_NAME)
	typora $(POST_PATH)/$(devops)/$(FILE_NAME)

.PHONY: golang
golang:
	hugo new --kind golang $(go)/$(FILE_NAME)
	git add $(go)/$(FILE_NAME)
	typora $(go)/$(FILE_NAME)

.PHONY: k8s
k8s:
	hugo new --kind k8s $(k8s)/$(FILE_NAME)
	git add $(k8s)/$(FILE_NAME)
	typora $(k8s)/$(FILE_NAME)

.PHONY: self
self:
	hugo new --kind self $(self)/$(FILE_NAME)
	git add $(self)/$(FILE_NAME)
	typora $(self)/$(FILE_NAME)

.PHONY: ps
ps:
	hugo new --kind persistence $(ps)/$(FILE_NAME)
	git add $(ps)/$(FILE_NAME)
	typora $(ps)/$(FILE_NAME)

.PHONY: theory
theory:
	hugo new --kind theory $(theory)/$(FILE_NAME)
	git add $(theory)/$(FILE_NAME)
	typora $(theory)/$(FILE_NAME)

.PHONY: bash
bash:
	hugo new --kind bash $(bash)/$(FILE_NAME)
	git add $(bash)/$(FILE_NAME)
	typora $(bash)/$(FILE_NAME)

.PHONY: leetcode
leetcode:
	hugo new --kind leetcode $(leetcode)/$(FILE_NAME)
	git add $(leetcode)/$(FILE_NAME)
	typora $(leetcode)/$(FILE_NAME)

#.PHONY: draft
#draft:
#	hugo new draft $(TITLE)
#	git add $(DRAFT_PATH)/$(TITLE).md
#	git commit -m "feat($(TYPE)): add draft $(TITLE)"
#	git push origin
#
#.PHONY: publish
#publish:
#	hugo publish $(TYPE) $(TITLE)
#	mv $(POST_PATH)/*-$(TITLE).md $(POST_PATH)/$($(TYPE))/
#	git add $(POST_PATH)/$($(TYPE))/*-$(TITLE).md
#	git commit -m "feat($(TYPE)): add post $(TITLE)"
#	git push origin