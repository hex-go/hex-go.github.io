# BUILD

## 环境准备
- 0. install hugo
> hugo版本： hugo v0.92.2+extended linux/amd64

```bash
sudo apt install hugo
```

## 编译
```bash
# 在博客根目录，执行命令 hugo 会编译博客，并将编译后的文件保存至默认目录 ./public 下
make build

# hugo设计 只对现有文件进行覆盖，不删除public目录的多余文件（避免删除用户在public手动放置的静态文件）。 按需手动删除

# - minify:              minify any supported output format (HTML, XML etc.)
# - gc:                  enable to run some cleanup tasks (remove unused cache files) after the build
# - cleanDestinationDir: remove files from destination not found in static directories

make clean-build
```

## 本地调试
```bash
# local start
make server
```

## 目录说明
> ./source/ 与 ./scaffolds/为hexo迁移后的遗留文件，彻底完成迁移并验证后进行删除
```text
hex-go.github.io
├── archetypes/      # hugo new content 命令
│   └── default.md
├── config/          # 配置文件
├── content/         # 博客主要内容
├── public/          # 默认存放hugo构建后的编译文件(gitignore)
├── resources/       # 缓存一些文件以加快生成速度(gitignore)
├── static/          # 静态文件
├── themes/          # 主题（git add submodule）
├── .gitignore       # 不进行版本控制的文件和目录
├── .gitmodules      # 记录主题submodule信息
├── Makefile         # make 命令
└── README.md        # 本文档
```


## 编写博客
```bash
# 创建博客（不能带空格，不能加特殊字符）
make k8s TITLE='解析k8s-yaml成client-go中的data-structs'
#make ps TITLE='Registry配置keycloak作为认证服务'
#make self TITLE='Gland使用技巧'
#make golang TITLE='Go-Modules版本控制和依赖管理'
#make devops TITLE='Docker-理解容器中的uid和gid'
#make bash TITLE='shell基础之EOF的用法'
# make bash TITLE='Linux查漏补缺-4_安装包管理-deb'
#make leetcode TITLE='算法的时间和空间复杂度说明'
#make theory TITLE='RSA算法原理'

# 创建草稿
hugo new draft hexo常用命令备忘录

# make 创建草稿
make draft TITLE='容器常见：Dockerfile的ENTRYPOINT中不能使用环境变量'

# 本机预览草稿
hugo server --buildDrafts

# 将草稿发布为正式文章
hexo P hexo常用命令备忘录
# 或者 将草稿 以 bash 的布局发布(不支持--path参数知道目录，文件会保存在_post目录下，只能手动移动到相应子文件夹下)
hexo publish bash hexo常用命令备忘录 

make publish TYPE='bash' TITLE='hexo常用命令备忘录'
```

## 编写最佳实践
# 建议使用顺序
> 尽量避免使用 make new 直接创建正式博客，除非有大块的时间将博客能一步到位写完。
> make types 命令查看所有类型，
1. make draft来创建文章草稿并推送远端
```bash
# TITLE 禁止包含空格、/、.等特殊字符
make draft TITLE='容器常见：Dockerfile的ENTRYPOINT中不能使用环境变量'
```
2. 将草稿修改内容每天推送远端

3. 草稿完成后 make publish 发布为正式博客，并推送github
> make show-drafts 命令查看所有草稿文件名(不包含父目录和后缀)
```bash
make publish TYPE='bash' TITLE='hexo常用命令备忘录'
```

# 配置文件

```text
./config/
└── _default
    ├── config.toml
    ├── menus.toml
    └── params.toml
```


# 放图片或文件下载
- 本网站挂载
  hugo在构建成静态页面时，会将目录`./static/`下的内容全部拷贝至`./public/`目录。而`public`目录为网站根目录。

所以需要以下操作：
1. 将文件或照片放至`./static/`目录下
2. 在md文件中，图片通过`![例子-图片](/<相对于static目录的相对路径>)`或`<img src="/<相对于static目录的相对路径>" width="80%">`
   文件通过`[例子-文件](/images/<相对于static目录的相对路径>)`
> hugo构建后的静态网页会将`./static`目录下的文件夹放至 网站根目录下，所以可以通过绝对路径索引。

- 第三方工具挂载

1. typora配置阿里云对象存储，自动上传图片
2. 将url放至md文件中例如`![xxx图片](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/yNuAgl.jpg)`

# local-search设置


# CDN加速

# 国内字体

## 常见问题

1. 文档说明，之前博客由hexo迁移至hugo

2. 本地环境搭建

- hugo工具安装

sudo apt install hugo

- 博客选用了`themes/zzo`主题，通过add submodule的方式添加
  主库根目录（与themes同级目录）下，执行下面命令进行初始化
```bash
git submodule update --init
```

> git submodule update时报错`fatal: Need a single revision \n Unable to find current revision in submodule path themes/zzo`, 通过删除`themes/zzo`目录，并执行上面命令解决

3. 从linux环境迁移至window环境，由于之前没有注意跨平台文件格式支持问题，导致`git error：invalid path`问题
> 文件命名注意：1. windows不区分大小写（避免文件名相同，但大小写不同）；2. 文件名不要带`:`；3. 文件名尽量不要带中文
- `core.protectNTFS` git配置 Windows系统下默认值是true，不符合NTFS策略的文件不会被checkout，设置为false后可以关闭保护机制。

```bash
# 设置git大小写敏感，但文件命名时要尽量创建避免文件名相同，但大小写不同的文件
git config core.ignorecase false

# 关闭 NTFS 保护
git config core.protectNTFS false
```
