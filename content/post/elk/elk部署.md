# Docker 部署 ElasticSearch



## 拉取镜像 

```shell
docker pull docker.elastic.co/elasticsearch/elasticsearch:7.9.0
```

# 运行镜像

`ElasticSearch`的默认端口是9200，我们把宿主环境9200端口映射到`Docker`容器中的9200端口，就可以访问到`Docker`容器中的`ElasticSearch`服务了，同时我们把这个容器命名为`es`。

```go
docker run -d --name elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:7.9.0
```

## 配置跨域

### 进入容器

由于要进行配置，因此需要进入容器当中修改相应的配置信息。

```shell
docker exec -it es /bin/bash
```

### 进行配置

```
# 显示文件
ls
结果如下：
LICENSE.txt  README.textile  config  lib   modules
NOTICE.txt   bin             data    logs  plugins

# 进入配置文件夹
cd config

# 显示文件
ls
结果如下：
elasticsearch.keystore  ingest-geoip  log4j2.properties  roles.yml  users_roles
elasticsearch.yml       jvm.options   role_mapping.yml   users

# 修改配置文件
vi elasticsearch.yml

# 加入跨域配置
http.cors.enabled: true
http.cors.allow-origin: "*"
```

### 重启容器

由于修改了配置，因此需要重启`ElasticSearch`容器。

```shell
docker restart es
```



###  curl 验证

```http
curl http://0.0.0.0:9200/
{
  "name" : "8827c8cce977",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "1Ps0Ig4ZQ8Oy6fcBjhJE2Q",
  "version" : {
    "number" : "7.9.0",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "a479a2a7fce0389512d6a9361301708b92dff667",
    "build_date" : "2020-08-11T21:36:48.204330Z",
    "build_snapshot" : false,
    "lucene_version" : "8.6.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```



# docker 部署 kibana



# 拉取镜像

```
docker pull docker.elastic.co/elasticsearch/kibana:7.9.0
```



# 启动 kibana 

```shell
docker run -d --name kibana --link=elasticsearch:9200 -p 5601:5601 kibana:7.9.0
```





# 登录验证

```
http://0.0.0.0:5601/app/home#/tutorial_directory/sampleData
```



# 基本的概念



## Node 和 Cluster 

Elastic 本质上是一个分布式数据库，允许多台服务器协同工作，每台服务器可以运行多个 Elastic 实例。

单个 Elastic 实例称为一个节点（node）。一组节点构成一个集群（cluster）。

## Index



Elastic 会索引所有字段，经过处理后写入一个反向索引（Inverted Index）。查找数据的时候，直接查找该索引。

所以，Elastic 数据管理的顶层单位就叫做 Index（索引）。它是单个数据库的同义词。每个 Index （即数据库）的名字必须是小写。

下面的命令可以查看当前节点的所有 Index。

```shell
curl -X GET 'http://0.0.0.0:9200/_cat/indices'
```



```shell
health status index                          uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .apm-custom-link               _JSZVgluSoKExTqiXqOa6A   1   0          0            0       208b           208b
green  open   .kibana-event-log-7.9.0-000001 NNESBxxSSeWYpbZakEHguQ   1   0          1            0      5.4kb          5.4kb
green  open   .kibana_task_manager_1         9u_L9mTyQs6_B3VWJKsoAw   1   0          6           27     83.8kb         83.8kb
green  open   .apm-agent-configuration       i0VArRhbTHSnsNeAotmLeQ   1   0          0            0       208b           208b
green  open   .kibana_1                      cqlsCD8TRku7-B-eTKTH5w   1   0         13            0     10.4mb         10.4mb

```



# Type

在一个索引中，你可以定义一种或多种类型。一个类型是你的索引的一个逻辑上的分类/分区，其语义完全由你来定。通常，会为具有一组共同字段的文档定义一个类型。比如说，我们假设你运营一个博客平台并且将你所有的数据存储到一个索引中。在这个索引中，你可以为用户数据定义一个类型，为博客数据定义另一个类型，当然，也可以为评论数据定义另一个类型。类型类似于关系型数据库中Table的概念。不过目前7.x版本只允许一个index里面有一个Type





## Document

Index 里面单条的记录称为 Document（文档）。许多条 Document 构成了一个 Index。

Document 使用 JSON 格式表示，下面是一个例子。

> ```javascript
> {
>   "user": "张三",
>   "title": "工程师",
>   "desc": "数据库管理"
> }
> ```

同一个 Index 里面的 Document，不要求有相同的结构（scheme），但是最好保持相同，这样有利于提高搜索效率。





# 新建和删除index

新建Index,可以直接向 Elastic 服务器发出 PUT 请求。下面的例子是新建一个名叫user的 Index。

```shell
$ curl -X PUT '0.0.0.0:9200/user'

{"acknowledged":true,"shards_acknowledged":true,"index":"user"}#
```

删除index

```
$  curl -X DELETE '0.0.0.0:9200/user'
{"acknowledged":true}#
```



# 索引文档

一个文档的 `_index` 、 `_type` 和 `_id` 唯一标识一个文档。 我们可以提供自定义的 `_id` 值，或者让 `index` API 自动生成。



## 使用自定义的 ID

如果你的文档有一个自然的标识符 （例如，一个 `user_account` 字段或其他标识文档的值），你应该使用如下方式的 `index` API 并提供你自己 `_id` 

```shell
 curl -H 'Content-Type: application/json' -X PUT '0.0.0.0:9200/polaris-center/user/1' -d '{"username":"linyuanpeng","email":"linyuanpeng@163.com"}'
```

Elasticsearch 响应体如下所示：

```json
{
"_index": "polaris-center",
"_type": "user",
"_id": "1",
"_version": 4,
"result": "created",
"_shards": {
"total": 2,
"successful": 1,
"failed": 0
},
"_seq_no": 3,
"_primary_term": 1
}
```





# 参考 
全文搜索引擎 Elasticsearch 入门教程 https://www.ruanyifeng.com/blog/2017/08/elasticsearch.html