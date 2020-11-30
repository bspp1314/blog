---
title: "Redis数据类型之bitmap"
date: 2020-11-29T13:38:40+08:00
draft: false
categories: ["redis"]
tags: ["redis"]
---

# 简介

bitmap就是通过最小的单位bit来进行0或者1的设置，表示某个元素对应的值或者状态。一个bit的值，或者是0，或者是1；也就是说一个bit能存储的最多信息是2。redis中bit映射被限制在512MB之内，所以最大是2^32位。建议每个key的位数都控制下，因为读取时候时间复杂度O(n)，越大的串读的时间花销越多。



# 常用接口

```
setbit key offset value: bool or int (1 or 0) 给一个指定key的值得第offset位 赋值为value。
getbit key offset
bitbount key  返回一个指定key中位的值为1的个数(是以byte为单位不是bit)
```

# bitmap的优势、限制

### 优势

1.基于最小的单位bit进行存储，所以非常省空间。
2.二进制数据的存储，进行相关计算的时候非常快。



# Golang 中的简单使用



```go
rdb := redis.NewClien(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})
	
	_,err := rdb.SetBit("login_status",1,1).Result()
	if err != nil {
		log.Fatal(err)
	}
	
	defer rdb.Del("login_status")
	v,err := rdb.GetBit("login_status",1).Result()
	log.Println("value is ",v)

```





# 场景

## 用户在线状态

> 需求分析：

需要对子项目提供一个接口，来提供某用户是否在线？

> 设计方案：

使用bitmap是一个节约空间效率又高的一种方法，只需要一个key，然后用户id为偏移量offset，如果在线就设置为1，不在线就设置为一个亿用户只需要10M左右的空间。



```go
// 不分片 
func GetUserLoginStatus(rdb *redis.Client, offset int64) (int64, error) {
	return rdb.GetBit("user_login_status", offset).Result()
}

func GetUserLoginStatusShard(rdb *redis.Client, offset int64) (int64, error) {
	return rdb.GetBit(fmt.Sprintf("user_login_status_%d",offset / 100000 ), offset).Result()
}


// 分片
func SetUserLoginStatus(rdb *redis.Client, offset int64,online bool) (int64, error) {
	if online {
		return rdb.SetBit("user_login_status", offset,1).Result()
	}else{
		return rdb.SetBit("user_login_status", offset,0).Result()

	}
}

func SetUserLoginStatusShard(rdb *redis.Client, offset int64,online bool) (int64, error) {
	if online {
		return rdb.SetBit(fmt.Sprintf("user_login_status_%d",offset / 100000), offset,1).Result()
	}else{
		return rdb.SetBit(fmt.Sprintf("user_login_status_%d",offset / 100000), offset,0).Result()
	}
}
```

如上所示上面有两种的实现方式，一种是对数据进行分片一种是不对数据进行分片。对于过亿的数据，就可以进行分片了

如果你的数据量在一千万左右，实际上可以不需要分片，对上两种的实现进行千万级的测试，发现其性能相差不到 10%。

```go
 go test -bench=.
goos: darwin
goarch: amd64
pkg: github.com/bspp1314/go-common-lib/redis-lib/bitmap
BenchmarkUserLoginStatus-4                 12968             89549 ns/op   //千万数据量的非分片实现
BenchmarkUserLoginStatusShard-4            12194             94778 ns/op  //千万数据量的分片实现
PASS
ok      github.com/bspp1314/go-common-lib/redis-lib/bitmap      4.031s

```



# 统计活跃用户
如果要统计某一天的所有的活跃用户数，使用`bitcount`命令，bitcount可以统计1的个数，也就是活跃用户数：

> bitcount 2020-01-01 [时间复杂度为O(N)]



如果要统计某一段时间内的活跃用户数，需要用到bitop命令。这个命令提供四种位运算，`AND(与)`，`(OR)或`，`XOR(亦或)`，`NOT(非)`。我们可以对某一段时间内的所有key进行`OR(或)`操作，或操作出来的位图是0的就代表这段时间内一次都没有登陆的用户。那只要我们求出1的个数就可以了。

备注 总活跃度值得是交集

```go
r := rand.New(rand.NewSource(time.Now().UnixNano()))
	activeReal := 0
	notActiveReal := 0
	for i := 0; i < 100; i++ {
		for j := 0; j < 2; j++ {
			date := time.Unix(int64(1577808000+86400*j), 0).Format("2006-01-02")
			if (r.Intn(10000000) & 1) == 1 {
				SetUserActive(rdb, int64(i), date, true)
				activeReal++
			} else {
				SetUserActive(rdb, int64(i), date, false)
				notActiveReal++
			}
		}
	}

	log.Println("activeReal",activeReal)
	log.Println("notActiveReal",notActiveReal)


	var keys []string
	for j:=0;j < 2;j++ {
		key  := fmt.Sprintf("active_%s",time.Unix(int64(1577808000 +86400 * j),0).Format("2006-01-02"))
		keys = append(keys,key)
		log.Println(rdb.BitCount(key,&redis.BitCount{
			Start: 0,
			End:  365000,
		}).Result())

	}
	_,err := rdb.BitOpOr("active_2020",keys...).Result()
	if err != nil {
		log.Fatal(err)
	}
	//
	log.Println(rdb.BitCount("active_2020",&redis.BitCount{
		Start: 0,
		End:  10000,
	}).Result())

```




# 参考
一看就懂系列之 详解redis的bitmap在亿级项目中的 https://blog.csdn.net/u011957758/article/details/74783347

Redis如何存储和计算一亿用户的活跃度 https://www.cnblogs.com/bryan31/p/13331213.html

