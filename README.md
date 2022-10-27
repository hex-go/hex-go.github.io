# BUILD

## 环境准备
- 0. install nvm
```bash
# refrence (https://hackernoon.com/how-to-install-node-js-on-ubuntu-16-04-18-04-using-nvm-node-version-manager-668a7166b854)
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
bash install_nvm.sh
source ~/.profile
nvm --version
nvm ls-remote
```

- 1. install nodejs
```bash
nvm install 10.15
nvm use 10.15
node -v
npm -v
```

- 2. isntall+set yarn

```bash
npm i -g npm --registry https://registry.npm.taobao.org
npm i -g yarn --registry https://registry.npm.taobao.org
# set yarn use taobao proxy
yarn config set registry https://registry.npm.taobao.org
```

- 3. isntall hexo
```bash
# install pkg
yarn install

# 安装包
npm install hexo-generator-searchdb --save
npm install -g hexo-cli
npm install -g hexo@3.9.0
```

## 本地调试
```bash
# local start
hexo g
## 启动服务
hexo s

## 清理
hexo clean
```

# write 
```bash
# 创建博客（不能带空格，不能加特殊字符）
make k8s TITLE='解析k8s-yaml成client-go中的data-structs'
#make ps TITLE='Registry配置keycloak作为认证服务'
#make self TITLE='Gland使用技巧'
#make golang TITLE='Go-Modules版本控制和依赖管理'
#make devops TITLE='Docker-理解容器中的uid和gid'
#make bash TITLE='shell基础之EOF的用法'
#make leetcode TITLE='算法的时间和空间复杂度说明'
#make theory TITLE='RSA算法原理'

# 创建草稿
hexo new draft hexo常用命令备忘录
# 本机预览草稿
hexo S --draft
# 将草稿发布为正式文章
hexo P hexo常用命令备忘录
```

# 配置文件

- `./_config.yml`

- `./themes/next/_config.yml`

- `./source/_data/next.yml`


# 放图片或文件下载
- 本网站挂载
hexo在构建成静态页面时，会将目录`./source/images/`下的内容全部拷贝至`./public/images/`目录。而`public`目录为网站根目录。

所以需要以下操作：
1. 将文件或照片放至`./source/images/`目录下
2. 在md文件中，图片通过`![例子](/images/<相对source/images目录的路径>)`或`<img src="/images/<相对source/images目录的路径>" width="80%">`
   文件通过`[例子-文件](/images/<相对source/images目录的路径>)`
> hexo构建后的静态网页会将source目录下的文件夹(除`_data/`, `_drafts`, `posts`)放至 根目录下，所以可以通过绝对路径索引。

- 第三方工具挂载

1. 使用chrome插件`微博图床`工具上传图片
2. 将url放至md文件中例如`![xxx图片](https://tvax4.sinaimg.cn/large/006hT4w1ly1gaqf0wt3l1j31ac0u0dka.jpg)`

# local-search设置


# CDN加速

# 国内字体

