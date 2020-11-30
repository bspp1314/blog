---
title: "Go-Redis数据类型使用"
date: 2020-11-04T16:54:38+08:00
draft: false
---
​                    |

# String 
常见操作
```
//set(key, value)：给数据库中名称为key的string赋予值value
//get(key)：返回数据库中名称为key的string的value
//getset(key, value)：给名称为key的string赋予上一次的value
//mget(key1, key2,…, key N)：返回库中多个string的value
//setnx(key, value)：添加string，名称为key，值为value
//setex(key, time, value)：向库中添加string，设定过期时间time
//mset(key N, value N)：批量设置多个string的值
//msetnx(key N, value N)：如果所有名称为key i的string都不存在
//incr(key)：名称为key的string增1操作
//incrby(key, integer)：名称为key的string增加integer
//decr(key)：名称为key的string减1操作
//decrby(key, integer)：名称为key的string减少integer
//append(key, value)：名称为key的string的值附加value
//substr(key, start, end)：返回名称为key的string的value的子串
//redis 设置字符串

```
```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	rdbCmdStatus  := rdb.Set("key", "value", 0)
	if rdbCmdStatus.Err() != nil {
		fmt.Errorf("Set redis failed %v,cmd is %s  ",rdbCmdStatus.Err(),rdbCmdStatus.String())
		return
	}

	log.Println(rdbCmdStatus.String())

	resStatus := rdb.Get("key")
	if resStatus.Err() != nil {
		fmt.Errorf("Get redis failed %v,cmd is %s  ",rdbCmdStatus.Err(),rdbCmdStatus.String())
		return
	}

	fmt.Println(resStatus.String())
}

```

# List 
```
//rpush(key, value)：在名称为key的list尾添加一个值为value的元素
//lpush(key, value)：在名称为key的list头添加一个值为value的 元素
//llen(key)：返回名称为key的list的长度
//lrange(key, start, end)：返回名称为key的list中start至end之间的元素
//ltrim(key, start, end)：截取名称为key的list
//lindex(key, index)：返回名称为key的list中index位置的元素
//lset(key, index, value)：给名称为key的list中index位置的元素赋值
//lrem(key, count, value)：删除count个key的list中值为value的元素
//lpop(key)：返回并删除名称为key的list中的首元素
//rpop(key)：返回并删除名称为key的list中的尾元素
//blpop(key1, key2,… key N, timeout)：lpop命令的block版本。
//brpop(key1, key2,… key N, timeout)：rpop的block版本。
//rpoplpush(srckey, dstkey)：返回并删除名称为srckey的list的尾元素，并将该元素添加到名称为dstkey的list的头部
```

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

# Hash 
```
//hset(key, field, value)：向名称为key的hash中添加元素field
//hget(key, field)：返回名称为key的hash中field对应的value
//hmget(key, (fields))：返回名称为key的hash中field i对应的value
//hmset(key, (fields))：向名称为key的hash中添加元素field
//hincrby(key, field, integer)：将名称为key的hash中field的value增加integer
//hexists(key, field)：名称为key的hash中是否存在键为field的域
//hdel(key, field)：删除名称为key的hash中键为field的域
//hlen(key)：返回名称为key的hash中元素个数
//hkeys(key)：返回名称为key的hash中所有键
//hvals(key)：返回名称为key的hash中所有键对应的value
//hgetall(key)：返回名称为key的hash中所有的键（field）及其对应的value
```

```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})


	// key is user id
	rdb.HSet("1","name","张三")
	rdb.HSet("1","age",40)

	//set name
	hmGetCmd,err := rdb.HMGet("1","name","age").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Get Name and age ",hmGetCmd)


	hGetAll,err := rdb.HGetAll("1").Result()
	if err != nil {
		log.Fatal(err)
	}

	log.Println(hGetAll)
	defer rdb.Del("1")
}
```

# Set 
```
//sadd(key, member)：向名称为key的set中添加元素member
//srem(key, member) ：删除名称为key的set中的元素member
//spop(key) ：随机返回并删除名称为key的set中一个元素
//smove(srckey, dstkey, member) ：移到集合元素
//scard(key) ：返回名称为key的set的基数
//sismember(key, member) ：member是否是名称为key的set的元素
//sinter(key1, key2,…key N) ：求交集
//sinterstore(dstkey, (keys)) ：求交集并将交集保存到dstkey的集合
//sunion(key1, (keys)) ：求并集
//sunionstore(dstkey, (keys)) ：求并集并将并集保存到dstkey的集合
//sdiff(key1, (keys)) ：求差集
//sdiffstore(dstkey, (keys)) ：求差集并将差集保存到dstkey的集合
//smembers(key) ：返回名称为key的set的所有元素
//srandmember(key) ：随机返回名称为key的set的一个元素
```

```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	_,err := rdb.SAdd("math_class","MaYu").Result()
	if err != nil {
		log.Fatal(err)
	}
	defer rdb.Del("math_class")

	_,err = rdb.SAdd("math_class","CuiGeHeng").Result()
	if err != nil {
		log.Fatal(err)
	}

	_,err = rdb.SAdd("math_class","ChenJingWen").Result()
	if err != nil {
		log.Fatal(err)
	}

	_,err = rdb.SAdd("math_class","ChenJun").Result()
	if err != nil {
		log.Fatal(err)
	}

	//get all math_class
	mathMembers,err := rdb.SMembers("math_class").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Math members is ",mathMembers)

	_,err = rdb.SAdd("english_class", "ChenJun").Result() // 向 whitelist 添加元素
	if err != nil {
		log.Fatal(err)
	}
	defer rdb.Del("english_class")



	_,err = rdb.SAdd("english_class", "FengYuanYuan").Result() // 向 whitelist 添加元素
	if err != nil {
		log.Fatal(err)
	}

	rdb.SAdd("english_class", "FengZhenKai").Result() // 向 whitelist 添加元素
	if err != nil {
		log.Fatal(err)
	}

	//get all math_class
	EnglishClassMembers,err := rdb.SMembers("english_class").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("English members is ",EnglishClassMembers)

	// 判断元素是否在集合中
	isMember, err := rdb.SIsMember("math_class", "MaYu").Result()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Is MaYu in math_class: ", isMember)

	//交集
	sInter,err := rdb.SInter("math_class","english_class").Result()
	if err != nil {
		log.Fatal(err)
	}

	log.Println("In math class and english class members is ",sInter)


	//交集
	sUnion,err := rdb.SUnion("math_class","english_class").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("In math class or english class members is ",sUnion)

}

```

