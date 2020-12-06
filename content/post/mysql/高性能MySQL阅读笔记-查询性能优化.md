---
title: "高性能MySQL阅读笔记 查询性能优化"
date: 2020-12-06T14:13:19+08:00
draft: true
---

# 慢查询基础：优化数据访问

查询性能低下最基本的原因是访问的数据太多

- 确认应用程序是否在检索大量超过需要的数据。这通常意味着访问了大多的行，但有时候也可能访问了太多的列。
- 确认MySQL服务器是否在分析大量超过需要的数据行。



## 是否向数据库请求了不需要的数据

有些查询会请求超过实际需求的数据，然后这些多余的数据会被应用程序丢弃。

- 查询不需要的记录 比如需要10行的数据，结果查了100行
- 多表关联时返回全部数据
- 总是取出全部列
- 重复查询相同的数据 



## MySQL 是否在扫描额外的记录

对于MySQL,最简单的衡量查询开销的三个指标

- 响应的时间
- 扫描的行数
- 返回的行数



### 响应的时间

响应的时间 = 服务时间 + 排队时间

在不同类型的应用压力下，响应时间并没有一致的规律。存储引擎的锁（表锁、行锁）、高并发资源竞争、硬件响应等等都会影响响应时间。



### 扫描的行数和返回的行数

理想的情况下扫描的行数和返回的行数应该是相同的。但实际情况中这种理想的情况并不多，一般扫描的行数对返回的行数的比率通常在 1:1 和 10：1比较好



#### 扫描的行数和访问类型



在评估查询开销的时候，需要考虑一下从表中找到某一行的数据成本。MySQL中有好几种访问方式可以查找并返回一行结果。

- 全表扫描
- 索引扫描
- 范围扫描
- 唯一扫描
- 唯一索引扫描
- 常数引用

一个简单的实例

```mysql
create table people
(
    id         int unsigned auto_increment
        primary key,
    first_name varchar(50) default '' not null,
    last_name  varchar(50) default '' not null
);
```

然后向表插入10万条数据

```mysql
explain select * from people where first_name =  'XPXFCOLFsXdnsibxqlHlfzZmvtoEqygLoDkzSmxZvZMjNRjVLF'\G;
***************************[ 1. row ]***************************
id            | 1
select_type   | SIMPLE
table         | people
partitions    | <null>
type          | ALL
possible_keys | <null>
key           | <null>
key_len       | <null>
ref           | <null>
rows          | 99519
filtered      | 10.0
Extra         | Using where

(END)
select * from people where first_name =  'XPXFCOLFsXdnsibxqlHlfzZmvtoEqygLoDkzSmxZvZMjNRjVLF'\G;
***************************[ 1. row ]***************************
id         | 50001
first_name | XPXFCOLFsXdnsibxqlHlfzZmvtoEqygLoDkzSmxZvZMjNRjVLF
last_name  | MTMzNTQ4NjAwNzUzNTA3OTQyNA==
1 row in set
Time: 0.056s
```

可以看到查询这一条数据几乎扫描了全表的数据。

增加索引

```mysql
alter table people add index name (`first_name`,`last_name`);
```

```mysql
explain select * from people where first_name =  'XPXFCOLFsXdnsibxqlHlfzZmvtoEqygLoDkzSmxZvZMjNRjVLF'\G;
***************************[ 1. row ]***************************
id            | 1
select_type   | SIMPLE
table         | people
partitions    | <null>
type          | ref
possible_keys | name
key           | name
key_len       | 202
ref           | const
rows          | 1
filtered      | 100.0
Extra         | Using index

 select * from people where first_name =  'XPXFCOLFsXdnsibxqlHlfzZmvtoEqygLoDkzSmxZvZMjNRjVLF'\G;
***************************[ 1. row ]***************************
id         | 50001
first_name | XPXFCOLFsXdnsibxqlHlfzZmvtoEqygLoDkzSmxZvZMjNRjVLF
last_name  | MTMzNTQ4NjAwNzUzNTA3OTQyNA==
1 row in set
Time: 0.007s
```

一般MySQL能够使用如下三种方法应用WHRER条件，从好到坏依次如下

- 在索引中使用WHERE条件来过滤不匹配的记录。这是在存储引擎完成的。
- 使用索引覆盖扫描（在 Extra 列中出现Using index）来返回记录，直接从索引中过滤不需要的记录并返回命中的结果。这是在MySQL服务器层完成的，但无须再回表查询记录。
- 从数据表中返回数据，然后过滤不满足条件的记录。（在 Extra 列中出现Using Where）。这在MySQL服务器层完成，MySQL需要从数据表先从数据表读出记录然后过滤。








# 参考

MySQL EXPLAIN详解  https://www.jianshu.com/p/ea3fc71fdc45