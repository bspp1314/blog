---
title: "Git Config 的配置说明"
date: 2020-08-17T00:10:51+08:00
draft: false
categories: ["Git"]
---

## config 的配置指令

```
git config 
```
**git的配置一共有三个级别：**    

- system级别:整个系统的配置。   
- global级别：该用户下的配置。  
- local级别:当前仓库下的配置。  

<font color=#DC143C size=3 face="黑体">查看System配置</font>

```
git config --system --list 
```
<font color=#DC143C size=3 face="黑体">查看global配置</font>
```
git config --global --list
```
<font color=#DC143C size=3 face="黑体">查看local配置</font>
```
git config --local --list
```

在使用git的过程中，配置user.name和user.email时候以前经常就是使用global级别的配置，网上关于user.name和user.email的配置大部分都是在global的配置。最近因为工作需要在不同的仓库之下配置不同的user.name和user.email,就查找了一下文档，随便就记录一下。  

修该本地仓库下的user.name和user.email

```
 git config user.name "用户名"
 git config user.email "邮箱"
```

修改全局仓库的用户名和邮箱

```
git config --global user.name  “用户名”
git config --global user.email   “邮箱”
```