---
title: "安装elasticsearch和简单的使用"
date: 2020-09-21T11:04:41+08:00
draft: true
---

# 什么是Elasticsearch

[Elasticsearch](https://www.getapp.com/it-management-software/a/qbox-dot-io-hosted-elasticsearch/)是一个用 Java 开发的开源全文搜索引擎。用户上传 JSON 格式的数据集。然后，Elasticsearch 在向集群索引中的文档添加可搜索的引用之前先保存原始文档。



# 安装elasticsearch
下载镜像
```
docker pull docker.elastic.co/elasticsearch/elasticsearch:7.9.0
```
创建挂载的目录

```
mkdir -p /home/linyuanpeng/data/elasticsearch/data
mkdir -p /home/linyuanpeng/data/elasticsearch/config
echo "http.host: 0.0.0.0" >> /home/linyuanpeng/data/elasticsearch/configelasticsearch.yml
```

创建容器并启动

```shell
docker run --name elasticsearch -p 9200:9200 -p 9300:9300  -e "discovery.type=single-node" -v /home/linyuanpeng/data/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml -v /home/linyuanpeng/data/elasticsearch/data:/usr/share/elasticsearch/data -v /home/linyuanpeng/data/elasticsearch/plugins:/usr/share/elasticsearch/plugins -d elasticsearch:7.9.0

其中elasticsearch.yml是挂载的配置文件，data是挂载的数据，plugins是es的插件，如ik，而数据挂载需要权限，需要设置data文件的权限为可读可写,需要下边的指令。
chmod -R 777 要修改的路径

-e "discovery.type=single-node" 设置为单节点
```

# 安装Kibana 

# 下载镜像

```
docker pull docker.elastic.co/kibana/kibana:7.9.0

```



```

docker run --name kibana -e ELASTICSEARCH_HOSTS=http://自己的IP地址:9200 -p 5601:5601 -d docker.elastic.co/kibana/kibana:7.9.0:7.6.2


进入容器修改相应内容
server.port: 5601
server.host: 0.0.0.0
elasticsearch.hosts: [ "http://自己的IP地址:9200" ]
i18n.locale: "Zh-CN"

然后访问页面
http://xx.xx.xx.xx:5601/app/kibana

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



