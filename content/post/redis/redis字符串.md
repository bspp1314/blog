---
title: "Redis字符串"
date: 2020-10-10T17:09:21+08:00
draft: false 
---

# 概述

Redis 字符串数据类型的相关命令用于管理 redis 字符串值，基本语法如下：

```shell
redis 127.0.0.1:6379> COMMAND KEY_NAME
```



# 常见命令

| 命令                    | 描述                                                         |
| ----------------------- | ------------------------------------------------------------ |
| SET KEY VALUE           | 设置指定key的值                                              |
| GET KEY                 | 获取指定 key 的值。                                          |
| GETRANGE key start end  | 返回 key 中字符串值的子字符                                  |
| GETSET key value        | 将给定 key 的值设为 value ，并返回 key 的旧值(old value)。   |
| GETBIT key offset       | 对 key 所储存的字符串值，获取指定偏移量上的位(bit)。         |
| MGET key1 key2          | 获取所有(一个或多个)给定 key 的值。                          |
| SETBIT key offset value | 对 key 所储存的字符串值，设置或清除指定偏移量上的位(bit)。   |
| SETEX key seconds value | 将值 value 关联到 key ，并将 key 的过期时间设为 seconds (以秒为单位)。 |
| SETNX key value         | 只有在 key 不存在时设置 key 的值。                           |
| APPEND key value        | 如果 key 已经存在并且是一个字符串， APPEND 命令将指定的 value 追加到该 key 原来值（value）的末尾。 |
| INCR key                | 将 key 中储存的数字值增一。                                  |
| INCR key increment      | 将 key 所储存的值加上给定的增量值（increment） 。            |
| DECR key                | 将 key 中储存的数字值减一。                                  |
| DECR key increment      | key 所储存的值减去给定的减量值（decrement） 。               |



更多命令可以相关 https://redis.io/commands#string



# Redis 源码的结构

在 C 语言中，字符串可以用一个 \0 结尾的 char 数组来表示。但是其在Redis里面并没有直接使用该结构，因为在 Redis 内部， 字符串的追加和长度计算很常见， 而 APPEND 和 STRLEN 更是这两种操作，如果使用 C语言默认的数据结构，会造成性能的瓶颈。

```c
#define SDS_TYPE_5  0
#define SDS_TYPE_8  1
#define SDS_TYPE_16 2
#define SDS_TYPE_32 3
#define SDS_TYPE_64 4
#define SDS_TYPE_MASK 7

// sds结构体，使用不同的结构体来保存不同长度大小的字符串
typedef char *sds;

//该结构已被启动
struct __attribute__ ((__packed__)) sdshdr5 {
    unsigned char flags; /* flags共8位，低三位保存类型标志，高5位保存字符串长度，小于32(2^5-1) */
    char buf[]; // 保存具体的字符串
};
struct __attribute__ ((__packed__)) sdshdr8 {
    uint8_t len; /* 字符串长度，buf已用的长度 */
    uint8_t alloc; /* 为buf分配的总长度，alloc-len就是sds结构体剩余的空间 */
    unsigned char flags; /* 低三位保存类型标志 */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr16 {
    uint16_t len; /* used */
    uint16_t alloc; /* excluding the header and null terminator */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr32 {
    uint32_t len; /* used */
    uint32_t alloc; /* excluding the header and null terminator */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr64 {
    uint64_t len; /* used */
    uint64_t alloc; /* excluding the header and null terminator */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
```

sds结构体从4.0开始就使用了5种header定义，节省内存的使用，但是不会用到sdshdr5，我认为是因为sdshdr5能保存的大小较少，2^5=32，因此就不使用它。

其他的结构体保存了len、alloc、flags以及buf四个属性。各自的含义见代码的注释。

