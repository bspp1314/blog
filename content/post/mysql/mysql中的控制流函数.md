---

title: "Mysql中的控制流函数"
date: 2020-09-03T10:47:29+08:00
draft: false
categories: ["MySQL"]
---



MySQL 中的控制流函数主要有一下四种 <!--more-->



| Name     | Description                  |
| -------- | ---------------------------- |
| CASE()   | Case operator                |
| IF()     | If/else construct            |
| IFNULL() | Null if/else construct       |
| NULLIF() | Return NULL if expr1 = expr2 |



# CASE

case 的两种语法

# 第一种语法

```mysql
CASE value WHEN [compare_value] THEN result [WHEN [compare_value] THEN result ...] [ELSE result] END
```

value: 使用简单 CASE 格式时所计算的表达式

compare_value: 使用简单 CASE 格式时 value 所比较的简单表达式

result:返回值

例子1:

```mysql
select case 1 when 1 then "this is one " when 2 then "this is two" else "this is else"  end;
```
out 

```mysql
+--------------------------------------------------------------------------------------+
| case 1 when 1 then "this is one " when 2 then "this is two" else "this is else"  end |
+--------------------------------------------------------------------------------------+
| this is one                                                                          |
+--------------------------------------------------------------------------------------+
```
例子2：
```
select case 3 when 1 then "this is one " when 2 then "this is two" else "this is else"  end;
```
out
```
+--------------------------------------------------------------------------------------+
| case 3 when 1 then "this is one " when 2 then "this is two" else "this is else"  end |
+--------------------------------------------------------------------------------------+
| this is else                                                                         |
+--------------------------------------------------------------------------------------+
```




## 第二种语法

```mysql
CASE WHEN [condition] THEN result [WHEN [condition] THEN result ...] [ELSE result] END
```
condition：使用 CASE 搜索格式时所计算的布尔表达式

result:返回值



例子3：

```mysql
SELECT CASE WHEN 1>0 THEN 'true' ELSE 'false' END;
```


out 
```mysql
+--------------------------------------------+
| CASE WHEN 1>0 THEN 'true' ELSE 'false' END |
+--------------------------------------------+
| true                                       |
+--------------------------------------------+
```





# IF()

if的使用语法为

```mysql
IF (expr1,expr2,expr3)
```

如果 expr1为真,IF()返回expr2,否则返回expr3

例子4：

```mysql
SELECT IF(1>2,2,3);
```

out 

```
+-------------+
| IF(1>2,2,3) |
+-------------+
| 3           |
+-------------+
```



# IFNULL

ifnull的语法为

```go
IFNULL(expr1,expr2)
```

如果expr 不为空，返回 expr1,否则返回expr2

例子5
```mysql
mysql> SELECT IFNULL(1,0);
        -> 1
mysql> SELECT IFNULL(NULL,10);
        -> 10
mysql> SELECT IFNULL(1/0,10);
        -> 10
mysql> SELECT IFNULL(1/0,'yes');
        -> 'yes'
```

# NULLIF

nullif的语法为

```
NULLIF(expr1,expr2)
```

如果 expr  = expr2 ，返回空。否则返回expr1.

例子6

```mysql
mysql> SELECT NULLIF(1,1);
        -> NULL
mysql> SELECT NULLIF(1,2);
        -> 1
```



# 一个典型的应用

存在以下两张表

```mysql
create table vip (
    id int not null primary key auto_increment,
    vip varchar(250) not null default  ''
);

create table rs (
    id int not null primary key auto_increment,
    vid int not null default 0,
    rip varchar(250) not null default  '',
    status varchar(12) not null default ''
);
```

其数据如下



```
vip
"id"	"vip"
1	10.10.10.1
2	10.10.10.2
```



```
rs
"id"	"vid"	"rip"	"status"
1	1	10.10.100.11	online
2	1	10.10.100.12	offline
3	1	10.10.100.13	offline
4	2	10.10.100.103	online
5	2	10.10.100.104	online

```



用一条语句统计每个vip所对应的下线数量和上线数量

```mysql
select v.vip ,count(if(r.status  = 'online',true,null)) as 在线 ,count(if(r.status  = 'online',null,true)) as 不在线 from vip as  v left join rs r on v.id = r.vid group by v.vip;
```

out

```
"vip"	"在线"	"不在线"
10.10.10.1	1	2
10.10.10.2	2	0
```



# 参考

[MySQL-Control Flow Functions](https://dev.mysql.com/doc/refman/8.0/en/control-flow-functions.html#function_if) 





sosk05.cpp.shyc3.qianxin-inc.cn

sosk05.cpp.shyc3.qianxin-inc.cn