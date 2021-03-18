---
title: "redis事件模式"
date: 2021-03-19T18:03:51+08:00
draft: true
---

Redis 是一个事件驱动的内存数据库，服务器需要处理两种类型的事件。

- 文件事件
- 时间事件



# Reactor 

Redis 基于 Reactor 模式开发了自己的事件处理器。

 Reactor 模式。看下图：

![image-20210318114026002](image-20210318114026002.png)



“I/O 多路复用模块”会监听多个 FD ，当这些FD产生，accept，read，write 或 close 的文件事件。会向“文件事件分发器（dispatcher）”传送事件。

文件事件分发器（dispatcher）在收到事件之后，会根据事件的类型将事件分发给对应的 handler。



## I/O 多路复用模块

Redis 的 I/O 多路复用模块，其实是封装了操作系统提供的 select，epoll，avport 和 kqueue 这些基础函数。向上层提供了一个统一的接口，屏蔽了底层实现的细节。

一般而言 Redis 都是部署到 Linux 系统上，所以我们就看看使用 Redis 是怎么利用 linux 提供的 epoll 实现I/O 多路复用。



首先看看 epoll 提供的三个方法：

```c
/*
 * 创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大
 */
int epoll_create(int size)；

/*
 * 可以理解为，增删改 fd 需要监听的事件
 * epfd 是 epoll_create() 创建的句柄。
 * op 表示 增删改
 * epoll_event 表示需要监听的事件，Redis 只用到了可读，可写，错误，挂断 四个状态
 */
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)；

/*
 * 可以理解为查询符合条件的事件
 * epfd 是 epoll_create() 创建的句柄。
 * epoll_event 用来存放从内核得到事件的集合
 * maxevents 获取的最大事件数
 * timeout 等待超时时间
 */
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
```



再看 Redis 对文件事件，封装epoll向上提供的接口：

```c

/*
 * 事件状态
 */
typedef struct aeApiState {

    // epoll_event 实例描述符
    int epfd;

    // 事件槽
    struct epoll_event *events;

} aeApiState;

/*
 * 创建一个新的 epoll 
 */
static int  aeApiCreate(aeEventLoop *eventLoop)
/*
 * 调整事件槽的大小
 */
static int  aeApiResize(aeEventLoop *eventLoop, int setsize)
/*
 * 释放 epoll 实例和事件槽
 */
static void aeApiFree(aeEventLoop *eventLoop)
/*
 * 关联给定事件到 fd
 */
static int  aeApiAddEvent(aeEventLoop *eventLoop, int fd, int mask)
/*
 * 从 fd 中删除给定事件
 */
static void aeApiDelEvent(aeEventLoop *eventLoop, int fd, int mask)
/*
 * 获取可执行事件
 */
static int  aeApiPoll(aeEventLoop *eventLoop, struct timeval *tvp)


```

所以看看这个ae_peoll.c 如何对 epoll 进行封装的：

- `aeApiCreate()` 是对 `epoll.epoll_create()` 的封装。
- `aeApiAddEvent()`和`aeApiDelEvent()` 是对 `epoll.epoll_ctl()`的封装。
- `aeApiPoll()` 是对 `epoll_wait()`的封装。

这样 Redis 的利用 epoll 实现的 I/O 复用器就比较清晰了。





再往上一层次我们需要看看 ea.c 是怎么封装的？

首先需要关注的是事件处理器的数据结构：

```c
/* File event structure */
typedef struct aeFileEvent {
    int mask; /* one of AE_(READABLE|WRITABLE|BARRIER) */ //事件处理类型
    aeFileProc *rfileProc; //读事件处理其
    aeFileProc *wfileProc; //写事件
    void *clientData; //客户端数据
} aeFileEvent;

```



除了使用 ae_peoll.c 提供的方法外,ae.c 还增加 “增删查” 的几个 API。

- 增:`aeCreateFileEvent`
- 删:`aeDeleteFileEvent`
- 查: 查包括两个维度 `aeGetFileEvents` 获取某个 fd 的监听类型和`aeWait`等待某个fd 直到超时或者达到某个状态。



## 事件分发器（dispatcher）

Redis 的事件分发器 `ae.c/aeProcessEvents` 不但处理文件事件还处理时间事件，所以这里只贴与文件分发相关的出部分代码，dispather 根据 mask 调用不同的事件处理器。







# 参考

如何使用epoll？一个完整的C例子 http://www.yeolar.com/note/2012/07/02/epoll-example/

Redis 中的事件驱动模型 https://xilidou.com/2018/03/22/redis-event/

