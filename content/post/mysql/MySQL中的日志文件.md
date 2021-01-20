---
title: "MySQL中的日志文件"
date: 2021-01-15T10:08:37+08:00
draft: true
---

#  慢查询日志文件



MySQL的慢查询日志是MySQL提供的一种日志记录，它用来记录在MySQL中响应时间超过阀值的语句，具体指运行时间超过long_query_time值的SQL，则会被记录到慢查询日志中。long_query_time的默认值为10，意思是运行10S以上的语句。



## 参数说明

- slow_query_log 慢查询开启状态
- slow_query_log_file 慢查询日志存放的位置（这个目录需要MySQL的运行帐号的可写权限，一般设置为MySQL的数据存放目录）
- long_query_time 查询超过多少秒才记录
- log_queries_not_using_indexes 如果运行的SQL语句没有索引，也会被记录
- log_throttle_queries_not_using_index 用来表示每分钟允许记录到slow log 的 且未使用索引SQL的次数

## 设置

查看慢查询相关参数

```mysql
show variables like '%slow_query%'\G;                                                                                                      
***************************[ 1. row ]***************************
Variable_name | slow_query_log
Value         | OFF
***************************[ 2. row ]***************************
Variable_name | slow_query_log_file
Value         | /var/lib/mysql/web02v-slow.log
2 rows in set
Time: 0.035s


show variables like '%long_query_time%'\G;                                                                                                 
***************************[ 1. row ]***************************
Variable_name | long_query_time
Value         | 10.000000
1 row in set
Time: 0.034s
```

将 slow_query_log 全局变量设置为“ON”状态

```mysql
set global slow_query_log='ON'; 
```

查询超过1秒就记录 

```mysql
set global long_query_time=1;
```



设置后需要重新连接session ,查看设置后的参数

```mysql
show variables like '%slow_query%'\G;                                                                                                      
***************************[ 1. row ]***************************
Variable_name | slow_query_log
Value         | ON
***************************[ 2. row ]***************************
Variable_name | slow_query_log_file
Value         | /var/lib/mysql/web02v-slow.log
2 rows in set
Time: 0.035s


show variables like '%long_query_time%'\G;                                                                                                 
***************************[ 1. row ]***************************
Variable_name | long_query_time
Value         | 1.000000
1 row in set
Time: 0.034s
```

MySQL 5.1 开始也可以将慢查询日志放入一张表中，名为slow_log

```MySQL
show create table mysql.slow_log\G;        
***************************[ 1. row ]***************************
Table        | slow_log
Create Table | CREATE TABLE `slow_log` (
  `start_time` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `user_host` mediumtext NOT NULL,
  `query_time` time(6) NOT NULL,
  `lock_time` time(6) NOT NULL,
  `rows_sent` int(11) NOT NULL,
  `rows_examined` int(11) NOT NULL,
  `db` varchar(512) NOT NULL,
  `last_insert_id` int(11) NOT NULL,
  `insert_id` int(11) NOT NULL,
  `server_id` int(10) unsigned NOT NULL,
  `sql_text` mediumblob NOT NULL,
  `thread_id` bigint(21) unsigned NOT NULL
) ENGINE=CSV DEFAULT CHARSET=utf8 COMMENT='Slow log'
```

参数log_output 可以指定慢查询的输出格式

```mysql
show variables like '%log_output%'\G;                                                                                                                                   
***************************[ 1. row ]***************************
Variable_name | log_output
Value         | FILE
1 row in set
Time: 0.039s

```

# 查询日志

查询日志记录所有对MYSQL数据库请求的信息。无论这些请求是否得到正确的执行。

```mysql
 show variables like '%general_log%';                                                                                                                                    
+------------------+---------------------------+
| Variable_name    | Value                     |
+------------------+---------------------------+
| general_log      | ON                        |
| general_log_file | /var/lib/mysql/web02v.log |
+------------------+---------------------------+

```








# 参考 

5.4.5 The Slow Query Log https://dev.mysql.com/doc/refman/8.0/en/slow-query-log.html

