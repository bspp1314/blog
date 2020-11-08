---
title: "Redis数据类型使用之list"
date: 2020-11-04T16:54:38+08:00
draft: false
---

# Redis 中 list 的常见操作有

| 命令                       | 描述                                                         |
| -------------------------- | ------------------------------------------------------------ |
| rpush key value1 value2 .. | 在名称为key的list尾添加一个值为value1,value2的元素           |
| lpush key  value1 value2   | 在名称为key的list头添加一个值为value1,value2 的元素          |
| llen                       | 返回名称为key的list的长度                                    |
| lrange key start end       | 返回名称为key的list中start至end之间的元素                    |
| ltrim  key start end       | 截取名称为key的list                                          |
| lindex key index           | 返回名称为key的list中index位置的元素                         |
| lset key index value       | 给名称为key的list中index位置的元素赋值                       |
| lrem key count value       | 删除count个key的list中值为value的元素                        |
| lpop key                   | 返回并删除名称为key的list中的首元素                          |
| rpop key                   | 返回并删除名称为key的list中的尾元素                          |
| blpop key timeout          | 它是 [RPOP key](http://redisdoc.com/list/rpop.html#rpop) 命令的阻塞版本，当给定列表内没有任何元素可供弹出的时候，连接将被 [BRPOP](http://redisdoc.com/list/brpop.html#brpop) 命令阻塞，直到等待超时或发现可弹出元素为止。 |
| brpop key timeout          | 参考上一个命令                                               |



# 在Golang 中的简单使用

```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	cmd := rdb.RPush("language", "Golang", "Java") // push data to list right
	if err := cmd.Err(); err != nil {
		log.Fatal(err)
	}
	defer rdb.Del("language")


	cmd = rdb.LPush("language", "PHP", "Rust") // push data to list right
	if err := cmd.Err(); err != nil {
		log.Fatal(err)
	}

	res, err := rdb.LRange("language", 0, math.MaxInt64).Result()
	if err != nil {
		log.Fatal(err)
	}
	// Rust PHP Golang Java
	fmt.Println(res)

	//Remove
	e,err := rdb.LPop("language").Result()
	if err != nil {
		log.Fatal(err)
	}
	//Get  Rust
	fmt.Println(e)

	//Remove
	e,err = rdb.RPop("language").Result()
	if err != nil {
		log.Fatal(err)
	}
	//Get  Java
	fmt.Println(e)
}

```

