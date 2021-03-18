---
title: "Redis数据类型使用"
date: 2020-11-04T16:54:38+08:00
draft: false
---

Redis 知识点

- Redis 数据类

  - String 
    	- row （sds）
    	- embstr (sds)
    	- int 
  - List
    	- ziplist
    	- linkedList
  - Hash
    	- ziplist
    	- hashtable
  - Set
    	- hashtable
    	- inset
  - Sorted Set
    	- skiplist
    	- ziplist 

- Redis 的持久化化方式
	- RDB 
- AOF 
  
- 负载均衡
	- 一致性hash 
	-  普通hash 
	-  为什么需要一致性hash 

- Redis 分布式锁


- Redis 的事件模式
	- 为什么是单线程
	- I/O 模型
	- Rector 模型







  

  

  





# 参考 

http://redisbook.com/preview/object/hash.html