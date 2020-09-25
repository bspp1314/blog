---
title: "Centos安装Vim8"
date: 2020-08-20T12:47:39+08:00
draft: false
categories: ["vim"]
---



# 说明

vim 8.0正式发布到现在已经很久了，很多新的vim插件对7.x版本的支持已经不是很好了，比如vim-go插件，而centos默认的又是vim7.x。这就导致在使用插件的使用出现一些冲突，所以需要将vim7.x 升级到vim8.0 <!--more-->

# 删除旧的Vim

```
yum remove -y vim 
```



# 安装依赖

```shell
yum install -y gcc make ncurses ncurses-devel

yum install ctags git tcl-devel \
    ruby ruby-devel \
    lua lua-devel \
    luajit luajit-devel \
    python python-devel \
    perl perl-devel \
    perl-ExtUtils-ParseXS \
    perl-ExtUtils-XSpp \
    perl-ExtUtils-CBuilder \
    perl-ExtUtils-Embed
```



# 构建 Vim 8

```shell
git clone --depth=1 https://github.com/vim/vim.git

./configure --with-features=huge \
--enable-multibyte \
--enable-rubyinterp \
--enable-pythoninterp \
--enable-perlinterp \
--enable-luainterp \
--enable-gui=no

make 
make install 
```



# 确认是否安装成功

```shell
vim --version | head -1
VIM - Vi IMproved 8.2 (2019 Dec 12, compiled Aug 20 2020 12:10:43)
```



