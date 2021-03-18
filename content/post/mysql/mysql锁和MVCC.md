---
title: "Mysql锁和MVCC"
date: 2021-03-04T13:29:40+08:00
draft: true
---

# 悲观锁和乐观锁



我们都知道锁的种类一般分为乐观锁和悲观锁两种，InnoDB 存储引擎中使用的就是悲观锁，而按照锁的粒度划分，也可以分成行锁和表锁。



- 乐观锁 

  ​	乐观锁是一种思想，它其实并不是一种真正的『锁』，它会先尝试对资源进行修改，在写回时判断资源是否进行了改变，如果没有发生改变就会写回，否则就会进行重试，在整个的执行过程中其实都**没有对数据库进行加锁**；

- 悲观锁
	悲观锁就是一种真正的锁了，它会在获取资源前对资源进行加锁，确保同一时刻只有有限的线程能够访问该资源，其他想要尝试获取资源的操作都会进入等待状态，直到该线程完成了对资源的操作并且释放了锁后，其他线程才能重新操作资源；



#  锁的种类

对数据的操作其实就只有读或写两种操作，数据库在实现锁时，也会对这两种操作使用不同的锁；InnoDB 实现了标准的行级锁，也就是共享锁（Shared Lock）和互斥锁（Exclusive Lock）；共享锁和互斥锁的作用其实非常好理解：

- 共享锁 （读锁 ） 允许事务对一条行数据进行读取；
- **互斥锁（写锁）**：允许事务对一条行数据进行删除或更新；

而它们的名字也暗示着各自的另外一个特性，**共享锁之间是兼容的，而互斥锁与其他任意锁都不兼容：**



|        | S Lock | X Lock |
| ------ | ------ | ------ |
| S Lock | Yes    | No     |
| X Lock | No     | No     |





# 锁的粒度



无论是共享锁还是互斥锁其实都只是对某一个数据行进行加锁，InnoDB 支持多种粒度的锁，也就是行锁和表锁；为了支持多粒度锁定，InnoDB 存储引擎引入了意向锁（Intention Lock），意向锁就是一种表级锁。

与上一节中提到的两种锁的种类相似的是，意向锁也分为两种：

- **意向共享锁**：事务想要在获得表中某些记录的共享锁，需要在表上先加意向共享锁；
- **意向互斥锁**：事务想要在获得表中某些记录的互斥锁，需要在表上先加意向互斥锁；




|         | IS Lock | IX Lock | S Lock | XLock |
| ------- | ------- | ------- | ------ | ----- |
| IS Lock | Yes     | Yes     | Yes    | No    |
| IX Lock | Yes     | Yes     | No     | No    |
| S Lock  | Yes     | No      | Yes    | No    |
| X Lock  | No      | No      | No     | No    |





意向锁其实不会阻塞全表扫描之外的任何请求，它们的主要目的是为了表示**是否有人请求锁定表中的某一行数据**。

> 有的人可能会对意向锁的目的并不是完全的理解，我们在这里可以举一个例子：如果没有意向锁，当已经有人使用行锁对表中的某一行进行修改时，如果另外一个请求要对全表进行修改，那么就需要对所有的行是否被锁定进行扫描，在这种情况下，效率是非常低的；不过，在引入意向锁之后，当有人使用行锁对表中的某一行进行修改之前，会先为表添加意向互斥锁（IX），再为行记录添加互斥锁（X），在这时如果有人尝试对全表进行修改就不需要判断表中的每一行数据是否被加锁了，只需要通过等待意向互斥锁被释放就可以了。



# 锁的算法

## Recode Lock 

记录锁（Record Lock）是加到**索引记录**上的锁。如果InnoDB存储引擎表在创建的时候没有设置任务一个索引，那么这时InnoDB 存储引擎会使用隐式的主键来进行锁定。



假设我们存在下面的一张表 `users`：

```mysql
CREATE TABLE users(
    id INT NOT NULL AUTO_INCREMENT,
    last_name VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    age INT,
    PRIMARY KEY(id),
    KEY(last_name),
    KEY(age)
);
```



**如果我们使用 `id` 或者 `last_name` 作为 SQL 中 `WHERE` 语句的过滤条件，那么 InnoDB 就可以通过索引建立的 B+ 树找到行记录并添加锁。**



**如果使用 `first_name` 作为过滤条件时，由于 InnoDB 不知道待修改的记录具体存放的位置，也无法对将要修改哪条记录提前做出判断就会锁定整个表。**



## Gap Lock 间隙锁



间隙锁是对索引记录中的一段连续区域的锁；当使用类似 `SELECT * FROM users WHERE id BETWEEN 10 AND 20 FOR UPDATE;` 的 SQL 语句时，就会阻止其他事务向表中插入 `id = 15` 的记录，因为整个范围都被间隙锁锁定了。



## Next-Key Lock 

Next-Key 锁相比前两者就稍微有一些复杂，它是记录锁和记录前的间隙锁的结合，在 `users` 表中有以下记录：

```mysql
+------|-------------|--------------|-------+
|   id | last_name   | first_name   |   age |
|------|-------------|--------------|-------|
|    4 | stark       | tony         |    21 |
|    1 | tom         | hiddleston   |    30 |
|    3 | morgan      | freeman      |    40 |
|    5 | jeff        | dean         |    50 |
|    2 | donald      | trump        |    80 |
+------|-------------|--------------|-------+
```





如果使用 Next-Key 锁，那么 Next-Key 锁就可以在需要的时候锁定以下的范围：

```msyql
(-∞, 21]
(21, 30]
(30, 40]
(40, 50]
(50, 80]
(80, ∞)
```

> 既然叫 Next-Key 锁，锁定的应该是当前值和后面的范围，但是实际上却不是，Next-Key 锁锁定的是当前值和前面的范围。

当我们更新一条记录，比如 `SELECT * FROM users WHERE age = 30 FOR UPDATE;`，InnoDB 不仅会在范围 `(21, 30]` 上加 Next-Key 锁，还会在这条记录后面的范围 `(30, 40]` 加间隙锁，所以插入 `(21, 40]` 范围内的记录都会被锁定。



另外，当查询的索引隐含有唯一的属性时候，InnoDb存储引擎会对Next-Key Lock 进行优化，将其降级为 Record Lock。



创建测试代码如下

```mysql
drop table if exists t;
create table t (a int primary key);
insert inot t (a) values (1);
insert inot t (a) values (2);
insert inot t (a) values (5);
```






| Time | session1                                | Session2                      |
| ---- | --------------------------------------- | ----------------------------- |
| 1    | begin                                   |                               |
| 2    | select * from t where a = 5 for udpate; |                               |
| 3    |                                         | begin                         |
| 4    |                                         | insert inot t (a) values (4); |
| 5    |                                         | commit  # 成功不需要等待      |
| 6    | commit                                  |                               |

Next-Key Lock 降级为 Record Lock 仅仅在查询的列是唯一索引的情况。若是辅助索引，那么情况完全不同。

```mysql
 create table z (a int,b int,primary key(a),key(b));
 insert into z (a,b) values (1,1);
 insert into z (a,b) values (5,1);
 insert into z (a,b) values (5,3);
 insert into z (a,b) values (7,6);
 insert into z (a,b) values (10,8);
```

我们先列出其区间 b Next-Key

```
(-∞, 1]
(1, 3]
(3, 6]
(6, 8]
(8, ∞)
```



| Time | session1                                | Session2                                        | Session3                          | Session4                          | Session 5                         |
| ---- | --------------------------------------- | ----------------------------------------------- | --------------------------------- | --------------------------------- | --------------------------------- |
| 1    | begin                                   |                                                 |                                   |                                   |                                   |
| 2    | select * from t where a = 5 for udpate; |                                                 |                                   |                                   |                                   |
| 3    |                                         | begin                                           | begin                             | begin                             | begin                             |
| 4    |                                         | Select * from z where a = 5 lock in share mode; | Insert into z (a,b) values (4,2); | Insert into z (a,b) values (6,5); | Insert into z (a,b) values (8,6); |
| 5    |                                         | blocking ..                                     | blocking ...                      | blocking                          | commit # 成功不需要等待           |
| 6    | commit                                  |                                                 |                                   |                                   |                                   |
|      |                                         | commit                                          | commit                            | commit                            |                                   |



# 多版本控制协议

**发控制机制其实都是通过延迟或者终止相应的事务来解决事务之间的竞争条件（Race condition）来保证事务的可串行化** 虽然这种并发控制确实能够从根本上解决并发事务的可串行化的问题，但是在实际的生产环境中有时候我们有时候对数据库的事务大都是只读的，而且对读取到的数据不需要那么精确。那么种情况数据库系统引入了另一种并发控制机制 - *多版本并发控制*



（Multiversion Concurrency Control），每一个写操作都会创建一个新版本的数据，读操作会从有限多个版本的数据中挑选一个最合适的结果直接返回；在这时，读写操作之间的冲突就不再需要被关注，而管理和快速挑选数据的版本就成了 MVCC 需要解决的主要问题。



MySQL 中实现的多版本两阶段锁协议（Multiversion 2PL）将 MVCC 和 2PL 的优点结合了起来，每一个版本的数据行都具有一个唯一的时间戳，当有读事务请求时，数据库程序会直接从多个版本的数据项中具有最大时间戳的返回。



// TODO 图





更新操作就稍微有些复杂了，事务会先读取最新版本的数据计算出数据更新后的结果，然后创建一个新版本的数据，新数据的时间戳是目前数据行的最大版本 `＋1`

// TODO 图





数据版本的删除也是根据时间戳来选择的，MySQL 会将版本最低的数据定时从数据库中清除以保证不会出现大量的遗留内容。














mysql读锁（共享锁）与写锁（排他锁） https://blog.csdn.net/She_lock/article/details/82022431

浅谈数据库并发控制 - 锁和 MVCC https://draveness.me/database-concurrency-control/