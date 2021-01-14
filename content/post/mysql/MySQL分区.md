---
title: "MySQL分区"
date: 2021-01-12T18:28:27+08:00
draft: true
---

在日常的工作中，我们遇到一张表里面保存较大量的表的记录，而这些表里保存了大量的历史数据，而我们经常操作的的记录又往往事其中最新的记录，由于所有的数据都一个普通的表里，这给数据库照成非常大的压力。面对这类问题，最有效的方法就是在使用分区表。



# 分区的类型

目前MySQL支持一下几种类型的分区，RANGE分区，LIST分区，HASH分区，KEY分区。**如果表存在主键或者唯一索引时，分区列必须是唯一索引的一个组成部分。实战十有八九都是用RANGE分区。**



## Range 分区

Range 分区是基于属于一个给定连续区间的列值，把多行分配给分区。最常见的是基于时间字段. 基于分区的列最好是整型，如果日期型的可以使用函数转换为整型。

````go
CREATE TABLE my_range_timestamp
(
    id    int ,
    name  varchar(30) not null  default '',
    ctime timestamp default '2020-02-02 02:02:02' not null
)partition by range (UNIX_TIMESTAMP(ctime)) (
    partition p20210101 values  less than (UNIX_TIMESTAMP('2021-01-02 00:00:00')),
    partition p20210102 values  less than (UNIX_TIMESTAMP('2021-01-03 00:00:00')),
    partition p20210103 values  less than (UNIX_TIMESTAMP('2021-01-04 00:00:00'))
);
````

备注：如果是datatime 可以 to_days 函数

插入一些数据

```mysql
insert into my_range_timestamp (id,name,ctime) values (1,'name1','2021-01-01 00:00:01');
insert into my_range_timestamp (id,name,ctime) values (2,'name2','2021-01-01 00:00:02');
insert into my_range_timestamp (id,name,ctime) values (3,'name3','2021-01-01 00:00:03');
insert into my_range_timestamp (id,name,ctime) values (4,'name4','2021-01-01 00:00:04');

insert into my_range_timestamp (id,name,ctime) values (1,'name1','2021-01-02 00:00:01');
insert into my_range_timestamp (id,name,ctime) values (2,'name2','2021-01-02 00:00:02');
insert into my_range_timestamp (id,name,ctime) values (3,'name3','2021-01-02 00:00:03');
insert into my_range_timestamp (id,name,ctime) values (4,'name4','2021-01-02 00:00:04');
```

 

通过 explains 来验证

```mysql
explain select * from my_range_timestamp where name = 'name1' and ctime = '2021-01-01 00:00:02';  

***************************[ 1. row ]***************************
id            | 1
select_type   | SIMPLE
table         | my_range_timestamp
partitions    | p20210101
type          | ALL
possible_keys | <null>
key           | <null>
key_len       | <null>
ref           | <null>
rows          | 4
filtered      | 25.0
Extra         | Using where


```

可以看到分区确实被用到了



上面分区还有一个存在问题，当我们插入大于 2021-01-04 00:00:00 的数据的时候，会收到一个错误。



```mysql
insert into my_range_timestamp (id,name,ctime) values (4,'name4','2021-05-04 00:00:04');                                                                      
(1526, 'Table has no partition for value 1620086404')

```

我们可以通过一个增加一个默认分区来解决这个问题

```mysql
alter table my_range_timestamp partition by range (UNIX_TIMESTAMP(ctime)) (
    partition p20210101 values  less than (UNIX_TIMESTAMP('2021-01-02 00:00:00')),
    partition p20210102 values  less than (UNIX_TIMESTAMP('2021-01-03 00:00:00')),
    partition p20210103 values  less than (UNIX_TIMESTAMP('2021-01-04 00:00:00')),
    partition p values  less than (MAXVALUE)
);
```



#  LIST 分区

LIST分区和RANGE分区很相似，只是分区列的值是离散的，不是连续的。LIST分区使用VALUES IN，因为每个分区的值是离散的，因此只能定义值。LIST分区列是非null列，否则插入null值如果枚举列表里面不存在null值会插入失败。

```mysql
create table t_list( 
　　a int(11) not null default 0, 
　　b int(11) not null defaule 0
　　)(partition by list (b) 
　　partition p0 values in (1,3,5,7,9), 
　　partition p1 values in (2,4,6,8,0) 
　　);
```



### HASH分区

　　说到哈希，那么目的很明显了，将数据均匀的分布到预先定义的各个分区中，保证每个分区的数量大致相同。

### KEY分区

　　KEY分区和HASH分区相似，不同之处在于HASH分区使用用户定义的函数进行分区，KEY分区使用数据库提供的函数进行分区。



# 性能

> 一项技术，不是用了就一定带来益处。比如显式锁功能比内置锁强大，你没玩好可能导致很不好的情况。分区也是一样，不是启动了分区数据库就会运行的更快，分区可能会给某些sql语句性能提高，但是分区主要用于数据库高可用性的管理。数据库应用分为2类，一类是OLTP（在线事务处理），一类是OLAP（在线分析处理）。对于OLAP应用分区的确可以很好的提高查询性能，因为一般分析都需要返回大量的数据，如果按时间分区，比如一个月用户行为等数据，则只需扫描响应的分区即可。在OLTP应用中，分区更加要小心，通常不会获取一张大表的10%的数据，大部分是通过索引返回几条数据即可。
>
> 　　比如一张表1000w数据量，如果一句select语句走辅助索引，但是没有走分区键。那么结果会很尴尬。如果1000w的B+树的高度是3，现在有10个分区。那么不是要(3+3)*10次的逻辑IO？（3次聚集索引，3次辅助索引，10个分区）。所以在OLTP应用中请小心使用分区表。



# 参考

『浅入浅出』MySQL 和 InnoDB  https://draveness.me/mysql-innodb/

搞懂 MySQL 分区   https://www.cnblogs.com/GrimMjx/p/10526821.html

OLTP https://database.guide/what-is-oltp/

OLAP https://database.guide/what-is-olap/

