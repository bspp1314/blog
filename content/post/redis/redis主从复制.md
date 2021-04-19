---
title: "Redis主从复制"
date: 2021-03-24T10:12:54+08:00
draft: true
---

# 发起建立 master-slave 关系

发起 master-slave 关系有几种方式，不过我们通常是在 conf 里面进行配置

- `redis.conf` 文件中配置 `slaveof [masterip] [masterport]` 选项，当然还是需要在服务启动的时候指定这个 redis.conf 配置
- `redis-server` 命令启动服务的时候指定参数 `--slaveof [masterip] [masterport]`
- `client 模式`下通过 `slaveof [masterip] [masterport]` 命令执行绑定主服务器



# redis的完全数据同步的源代码的分析 

从服务 连接master服务看三种方式最终都会调用 `replicationCron`

我们依次来看这个函数

```c
/* Replication cron function, called 1 time per second. */
void replicationCron(void) {
    static long long replication_cron_loops = 0;

    /* Non blocking connection timeout? */
    if (server.masterhost &&
        (server.repl_state == REPL_STATE_CONNECTING ||
         slaveIsInHandshakeState()) &&
         (time(NULL)-server.repl_transfer_lastio) > server.repl_timeout)
    {
        serverLog(LL_WARNING,"Timeout connecting to the MASTER...");
        cancelReplicationHandshake();
    }

    /* Bulk transfer I/O timeout? */
    if (server.masterhost && server.repl_state == REPL_STATE_TRANSFER &&
        (time(NULL)-server.repl_transfer_lastio) > server.repl_timeout)
    {
        serverLog(LL_WARNING,"Timeout receiving bulk data from MASTER... If the problem persists try to set the 'repl-timeout' parameter in redis.conf to a larger value.");
        cancelReplicationHandshake();
    }
  
    /* Timed out master when we are an already connected slave? */
    if (server.masterhost && server.repl_state == REPL_STATE_CONNECTED &&
        (time(NULL)-server.master->lastinteraction) > server.repl_timeout)
    {
        serverLog(LL_WARNING,"MASTER timeout: no data nor PING received...");
        freeClient(server.master);
    }
    
    .....

}
```



这一部分代码主要是用来确实上次的连接是否超时，如果超时，就释放这些连接，就是重置一些参数。

```c
void replicationCron(void) { 
/* Check if we should connect to a MASTER */
    if (server.repl_state == REPL_STATE_CONNECT) {
        serverLog(LL_NOTICE,"Connecting to MASTER %s:%d",
            server.masterhost, server.masterport);
        if (connectWithMaster() == C_OK) {
            serverLog(LL_NOTICE,"MASTER <-> REPLICA sync started");
        }
    }
  ......
}
```

`connectWithMaster()`使用非阻塞套接字建立连接，并注册可读可写`syncWithMaster()`文件事件，更新`repl_state = REPL_STATE_CONNECTING`。






