# BUILD

## 环境准备
- 0. install hugo
> hugo版本： hugo v0.92.2+extended linux/amd64

```bash
sudo apt install hugo
```

- sync theme
```bash
# 使用代理
source  /mnt/d/AppData/wsl/set-proxy.sh

# 拉取主题
git submodule update --init
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

# 目录说明
```text
hex-go.github.io
├── archetypes/      # 博客模板目录
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


# 编写博客
```bash
# 创建博客（1. 不能带空格、冒号等特殊字符；2. `_`可作为系列前缀，会在title中被替换为 `: `）
make k8s TITLE='解析k8s-yaml成client-go中的data-structs'
#make ps TITLE='Registry配置keycloak作为认证服务'
#make self TITLE='Gland使用技巧'
#make golang TITLE='Golang_Modules版本控制和依赖管理'
#make devops TITLE='Docker_理解容器中的uid和gid'
#make bash TITLE='shell基础之EOF的用法'
# make bash TITLE='Linux查漏补缺-4_安装包管理-deb'
#make leetcode TITLE='算法的时间和空间复杂度说明'
#make theory TITLE='RSA算法原理'

# make 创建博客
make devops TITLE='容器常见：Dockerfile的ENTRYPOINT中不能使用环境变量'

# 本机预览
make server

# 发布博客
git push origin

```

> 也可以将未完成的博客暂存, 添加`draft: true`标识，并推送

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

3. 如何更新子模块内容
   要将 Git 子模块（Git Submodule）中的内容更新到最新提交，你可以使用以下命令：

3.1. 首先，进入包含子模块的父仓库的根目录。
3.2 使用以下命令来更新子模块内容：
   ```bash
   git submodule update --remote
   ```
   这会将子模块更新为其最新提交。如果你希望同时初始化未初始化的子模块，可以添加 `--init` 选项：
   ```bash
   git submodule update --remote --init
   ```
   这将确保子模块已经被初始化并更新到最新提交。
3.3. 如果你只希望更新一个特定的子模块，可以进入子模块目录，然后运行 `git pull` 或 `git fetch` 命令，如下所示：
   ```bash
   cd path/to/submodule
   git pull origin master  # 或者使用子模块所在分支的名称
   ```
   这将使子模块更新到其最新提交。请替换 `path/to/submodule` 为你的子模块的实际路径，以及使用正确的分支名称。
3.4. 最后，返回到父仓库的根目录，并提交任何子模块更新的变更：

   ```bash
   git add path/to/submodule  # 将子模块的路径添加到父仓库的暂存区
   git commit -m "Update submodule to latest commit"
   ```
   这将在父仓库中记录子模块的更新。
请注意，如果你的子模块包含在主仓库的特定提交中，父仓库中的该提交将包含子模块的特定提交引用。因此，要更新子模块，你需要切换到主仓库中包含最新子模块引用的提交，然后执行上述更新步骤。

4. 从linux环境迁移至window环境，由于之前没有注意跨平台文件格式支持问题，导致`git error：invalid path`问题
> 文件命名注意：1. windows不区分大小写（避免文件名相同，但大小写不同）；2. 文件名不要带`:`；3. 文件名尽量不要带中文
- `core.protectNTFS` git配置 Windows系统下默认值是true，不符合NTFS策略的文件不会被checkout，设置为false后可以关闭保护机制。

```bash
# 设置git大小写敏感，但文件命名时要尽量创建避免文件名相同，但大小写不同的文件
git config core.ignorecase false

# 关闭 NTFS 保护
git config core.protectNTFS false
```
