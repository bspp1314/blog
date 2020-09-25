---
title: "在Xorm中使用Join和Extends标记"
date: 2020-08-19T15:03:01+08:00
draft: true
categories: ["golang"]
tags: ["xorm"]
---

Xorm的基本操作都是比较简单的，可能大家也都比较熟悉了。这个文章主要讲解extends标记和join的使用。<!--more-->

一般我们会针对数据库中的每一个表，建立一个对应的结构体。比如：

```go
//用户表
type UserDao struct {
  Id    	 int64  `json:"id" xorm:"autoincr"`
  UserName string `json:"user_name"`
  ClassId  int64  `json:"class_id"`
}

func (d *UserDao) TableName() string {
	return "user"
}

//班级表
type ClassDao struct {
	Id        int64  `json:"id" xorm:"autoincr"`
	Name      string `json:"name"`
}

func (d *ClassDao) TableName() string {
	return "class"
}
```



Ok，这时候有一个简单的需求，需要查询所有User的信息，包括其班级信息。当然这是一个很简单的需要，一个简单left join 就可以解决。



```go
session := engine.Table(new(UserDao)).Alias("u").
		Join("LEFT",fmt.Sprintf("%s as c",new(ClassDao)),"w.class_id = c.id")
```



这时候我们需要一个结构体来存放这些列表，xorm提供了extends关键字来支持链表查询后的数据存放问题，具体看如下代码

```go
type UserClass struct {
  UserDao *UserDao 		 `xorm:extends`
  ClassDao *ClassDao   `xorm:"extends"`
}
```

```go
users := make([]*UserClass,0)
total,err := session.FindAndCount(&users)
```



