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

  

- 负载均衡
	- 一致性hash 
	-  普通hash 
	-  为什么需要一致性hash 

- Redis 分布式锁


- Redis 的事件模式
	- 为什么是单线程
	- I/O 模型
	- Rector 模型
- Redis 持久化机制

  - AOF 
  - RDB
    - fok 子进程
    - CopyOnWrite 技术
    - save 和 bgsabe
- Redis 淘汰策略
  	- noeviction 
  	- allkeys-lru 从所有key中使用LRU算法进行淘汰
  	- volatile-lru 从设置了过期时间的key中使用LRU算法进行淘汰
  	- allkeys-random 从所有key中随机淘汰数据
  	-  volatile-random 从设置了过期时间的key中随机淘汰
  	- volidate-ttl 在设置了过期时间的key中，根据key的过期时间进行淘汰，越早过期的越优先被淘汰 
  	- volatile-lfu：在设置了过期时间的key中使用LFU算法淘汰key
  - allkeys-lfu：在所有的key中使用LFU算法淘汰数据







  

  

  





# 参考 

http://redisbook.com/preview/object/hash.html