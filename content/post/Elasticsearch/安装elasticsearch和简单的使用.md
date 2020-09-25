---
title: "安装elasticsearch和简单的使用"
date: 2020-09-21T11:04:41+08:00
draft: true
---

# 什么是Elasticsearch

[Elasticsearch](https://www.getapp.com/it-management-software/a/qbox-dot-io-hosted-elasticsearch/)是一个用 Java 开发的开源全文搜索引擎。用户上传 JSON 格式的数据集。然后，Elasticsearch 在向集群索引中的文档添加可搜索的引用之前先保存原始文档。



# 安装JDK 

网上教程很多，也可以教程之前写的[Linux安装JDK](https://www.jianshu.com/p/4418cb3bda31)



# 安装Elasticsearch 

```shell
mkdir -p  /usr/local/tool/elasticsearch && cd /usr/local/tool/elasticsearch
curl -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.1-linux-x86_64.tar.gz
tar -xvf elasticsearch-7.9.1-linux-x86_64.tar.gz
cd elasticsearch-7.9.1/bin
./elasticsearch

```



# 遇到的坑

```java
org.elasticsearch.bootstrap.StartupException: java.lang.RuntimeException: can not run elasticsearch as root
```

这个问题很明显，不允许使用root用户启动，那么我们新建一个es用户，并赋予权限：

```shell
useradd es
```



添加es用户密码

```shell
passwd es 
```

将文件夹elasticsearch-7.9.1赋予es权限

```
chown -R es:es /usr/local/tool/elasticsearch/elasticsearch-7.9.1
```

将文件夹elasticsearch-5.4.2赋予es权限

切换为es用户

```shell
su es
```

再次启动

```shell
./elasticsearch
```

这次启动就成功了，使用一个窗口登录root用户，输入命令：



```shell
curl -X GET http://localhost:9200
{
  "name" : "xxxxxxxxxxxxxxxxxx",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "Mx8xFL9hQj2kSRwdbXRz0g",
  "version" : {
    "number" : "7.9.1",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "083627f112ba94dffc1232e8b42b73492789ef91",
    "build_date" : "2020-09-01T21:22:21.964974Z",
    "build_snapshot" : false,
    "lucene_version" : "8.6.2",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
  }
```



在浏览器访问http://xx.xx.xx.xx:9200/拒绝访问（xx.xx.xx.xx为服务器ip）

使用root用户，打开elasticsearch.yml文件

```
network.host: 0.0.0.0
```

使用es用户启动，发现又出现了错误

```java
max virtual memory areas vm.max_map_count[65530] is too low,increate to at least 
```

使用root用户打开如下文件：

```
vi /etc/security/limits.conf
```

添加配置如下

```
hadoop soft nofile 65536
hadoop hard nofile 131072
hadoop soft nproc 2048
hadoop hard nproc 4096
```



打开文件

```
vim /etc/sysctl.conf
```

添加如下配置

```
vm.max_map_count = 655360
```

使配置生效

```
/sbin/sysctl -p
```

然后又遇到了如下问题

```
the default discovery settings are unsuitable for production use; at least one of [discovery.seed_hosts, discovery.seed_providers, cluster.initial_master_nodes] must be configured
```

这个问题是和集群相关配置出了问题，这里我们先不关心集群配置，只用单机模式。

在elasticsearch的配置文件里面添加

```
discovery.type: single-node
```

# 基本概念

## Node 和 Cluster 

Elastic 本质上是一个分布式数据库，允许多台服务器协同工作，每台服务器可以运行多个 Elastic 实例。

单个 Elastic 实例称为一个节点（node）。一组节点构成一个集群（cluster）。

## Index

Elastic 会索引所有字段，经过处理后写入一个反向索引（Inverted Index）。查找数据的时候，直接查找该索引。

所以，Elastic 数据管理的顶层单位就叫做 Index（索引）。它是单个数据库的同义词。每个 Index （即数据库）的名字必须是小写。

下面的命令可以查看当前节点的所有 Index。

```
curl -X GET 'http://localhost:9200/_cat/indices?v'
```

out

```shell
green  open   .apm-custom-link               Q42weBBUQn6qPWG6esFKXQ   1   0          0            0       208b           208b
green  open   .kibana_task_manager_1         G5dyQ9nqSs2KXgy4pyE3Bw   1   0          6          123    130.9kb        130.9kb
green  open   kibana_sample_data_ecommerce   FuFBW-h7SmaIxUs1gMsdhA   1   0       4675            0      4.7mb          4.7mb
green  open   .kibana-event-log-7.9.1-000001 nW9-AoFCQQyTVvk2C2CgMA   1   0          2            0     10.9kb         10.9kb
green  open   .apm-agent-configuration       eQMOxHW1SC6j8drxMCd8WQ   1   0          0            0       208b           208b
yellow open   lyp_test_001                   YE3kn68kQVq_MBUgz542Kw   1   1          0            0       208b           208b
green  open   .async-search                  -lMr-Ph7Th6eR1HtWVLwDg   1   0          5            0      2.5mb          2.5mb
yellow open   accounts                       iqKCHtGaTk6Quo6eu783Nw   1   1          0            0       208b           208b
green  open   .kibana_1                      rfVe8awjQGiS-YtQ5OsAMA   1   0         74           29     11.3mb         11.3mb
```



## Document

### Document

Index 里面单条的记录称为 Document（文档）。许多条 Document 构成了一个 Index。

Document 使用 JSON 格式表示，下面是一个例子。

```json
{
"user_name":"lilicen",
"user_id":44
}
```

同一个 Index 里面的 Document，不要求有相同的结构（scheme），但是最好保持相同，这样有利于提高搜索效率



## Type 



https://juejin.im/post/6844903694287241229

https://stackoverflow.com/questions/59350069/elasticsearch-7-start-up-error-the-default-discovery-settings-are-unsuitable-f



