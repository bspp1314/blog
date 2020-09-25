---
title: "Go常见库之cron"
date: 2020-09-14T10:37:34+08:00
draft: false
categories: ["golang","golang常见库"]
---

# 简介

[`cron`](https://github.com/robfig/cron)一个用于管理定时任务的库，用 Go 实现 Linux 中crontab这个命令的效果。<!--more-->



# crontab 表达式的基本给

在学习cron库之前，我们需要了解一下cron表达式的配置。linux 中可以通过 crontab -e 来配置定时任务。不过，linux 中的 cron 只能精确到分钟。而我们这里要讨论的 Go 实现的 cron 可以精确到秒，除了这点比较大的区别外，cron 表达式的基本语法是类似的。



cron(计划任务)，顾名思义，按照约定的时间，定时的执行特定的任务（job）。cron 表达式 表达了这种约定。

cron 表达式代表了一个时间集合，使用 6 个空格分隔的字段表示。

| 字段名       | 是否必填 | 范围           | 特定字符   |
| ------------ | -------- | -------------- | ---------- |
| Seconds      | 是       | 0-59           | * / , -    |
| Minutes      | 是       | 0-59           | * / , -    |
| Hours        | 是       | 0-24           | * / , -    |
| Day of month | 是       | 1-31           | * / , - ?  |
| Month        | 是       | 1-12           | * / , -    |
| Day of week  | 是       | 0-6 or SUN-SAT | * / , -  ? |

## 特殊符号说明


###### 星号(*)   
表示 cron 表达式能匹配该字段的所有值。如在第5个字段使用星号(month)，表示每个月。

###### 斜线(/)     

表示增长间隔，如第2个字段(minutes) 值是 3-59/15，表示每小时的第3分钟开始执行一次，之后每隔 15 分钟执行一次（即 3、18、33、48 这些时间点执行），这里也可以表示为：3/15。

###### 逗号(,)   
用于枚举值，如第6个字段值是 MON,WED,FRI，表示 星期一、三、五 执行。   

###### 连字号(-)  
表示一个范围，如第3个字段的值为 9-17 表示 9am 到 5pm 直接每个小时（包括9和17）。  

###### 问号(?)
只用于 日(Day of month) 和 星期(Day of week)，表示不指定值，可以用于代替 



- 每隔5秒执行一次：*/5 * * * * *
- 每隔1分钟执行一次：0 */1 * * * *
- 每天23点执行一次：0 0 23 * * *
- 每天凌晨1点执行一次：0 0 1 * * *
- 每月1号凌晨1点执行一次：0 0 1 1 * *
-  在26分、29分、33分执行一次：0 26,29,33 * * * *
-   每天的0点、13点、18点、21点都执行一次：0 0 0,13,18,21 * * *

# 快速的使用

使用

```go
func main() {
	c :=cron.New(cron.WithSeconds()) //如果不加WithSeconds 默认支持到分钟
	c.AddFunc("*/1 * * * * *", func() {
		fmt.Println("tick every 1 second")
	})

	c.Start()
	time.Sleep(time.Second * 5)
}

```



out

```
go run ex1.go
tick every 1 second
tick every 1 second
tick every 1 second
tick every 1 second
tick every 1 second
```

## 时区

默认情况下，所有时间都是基于当前时区的。当然我们也可以指定时区，有 2 两种方式

- 在时间字符串前面添加一个`CRON_TZ=` + 具体时区，比如东京时区为`Asia/Tokyo`，纽约时区为`America/New_York`；
- 创建`cron`对象时增加一个时区选项cron.WithLocation(location)，location为time.LoadLocation(zone)加载的时区对象，zone为具体的时区格式。或者调用已创建好的cron对象的 SetLocation()方法设置时区。



```go
func main() {
	zone,err := time.LoadLocation("America/New_York")
	if err != nil {
		fmt.Println(err)
		return
	}
	c :=cron.New(cron.WithSeconds(),cron.WithLocation(zone))
	c.AddFunc("0 0 6 * * *", func() {
		fmt.Println("Every 6 o'clock at New York")
	})
	c.AddFunc("CRON_TZ=Asia/Tokyo 0 0 6 * * *", func() {
		fmt.Println("Every 6 o'clock at Tokyo")
	})

	c.Start()
	for {
		time.Sleep(time.Second)
	}
}
```



# Job 接口

除了直接将无参函数作为回调外，cron还支持Job接口：

```go
// Job is an interface for submitted cron jobs.
type Job interface {
	Run()
}

// AddJob adds a Job to the Cron to be run on the given schedule.
// The spec is parsed using the time zone of this Cron instance as the default.
// An opaque ID is returned that can be used to later remove it.
func (c *Cron) AddJob(spec string, cmd Job) (EntryID, error) {
	schedule, err := c.parser.Parse(spec)
	if err != nil {
		return 0, err
	}
	return c.Schedule(schedule, cmd), nil
}
```



使用方法如下

```go
type User struct {
	Name string
}

func (u *User) Hello()  {
	fmt.Println("hello, "+u.Name)
}

func (u *User) Run()  {
	u.Hello()
}

func main() {
	c :=cron.New(cron.WithSeconds())
	c.AddJob("*/1 * * * * *", &User{
		Name: "job",
	})

	c.Start()
	time.Sleep(time.Second * 5)
}
```

实际上AddFunc()方法内部也调用了AddJob()方法。

```go
// FuncJob is a wrapper that turns a func() into a cron.Job
type FuncJob func()

//Implementing Job Interface 
func (f FuncJob) Run() { f() }

// AddFunc adds a func to the Cron to be run on the given schedule.
// The spec is parsed using the time zone of this Cron instance as the default.
// An opaque ID is returned that can be used to later remove it.
func (c *Cron) AddFunc(spec string, cmd func()) (EntryID, error) {
	return c.AddJob(spec, FuncJob(cmd))
}
```

# 自定义时间格式

Cron支持灵活的时间格式，如果默认的格式不能满足要求，我们可以自己定义时间格式。实际上我们之前使用的cron.WithSeconds() 就是本质上也是自定义格式

```go
func WithSeconds() Option {
	return WithParser(NewParser(
		Second | Minute | Hour | Dom | Month | Dow | Descriptor,
	))
}

func WithParser(p Parser) Option {
   return func(c *Cron) {
      c.parser = p
   }
}
```



时间规则字符串需要cron.Parser对象来解析



Cron 支持的时间域

```go
const (
	Second         ParseOption = 1 << iota // Seconds field, default 0
	SecondOptional                         // Optional seconds field, default 0
	Minute                                 // Minutes field, default 0
	Hour                                   // Hours field, default 0
	Dom                                    // Day of month field, default *
	Month                                  // Month field, default *
	Dow                                    // Day of week field, default *
	DowOptional                            // Optional day of week field, default *
	Descriptor                             // Allow descriptors such as @monthly, @weekly, etc.
)
```

使用

```go 
type User struct {
	Name string
}

func (u *User) Hello()  {
	fmt.Println("hello, "+u.Name)
}

func (u *User) Run()  {
	u.Hello()
}

func main() {
	c :=cron.New(cron.WithParser(cron.NewParser(
		cron.Second | cron.Minute | cron.Hour | cron.Dom | cron.Month | cron.Dow | cron.Descriptor,
	)))
	c.AddJob("*/1 * * * * *", &User{
		Name: "job",
	})

	c.Start()
	time.Sleep(time.Second * 5)
}

```



# Option

cron 对象创建使用了选项模式,其中前面我们已经看过了三个

- WithLocation：指定时区
- WithParser：使用自定义的解析器
- WithSeconds：让时间格式支持秒

Cron 还提供了另外两种选项

- WithLogger 自定义Logger    

- WithChain



## WithLogger的使用

WithLogger 可以设置内部使用我们自定义的Logger 

```go
func main() {
	c := cron.New(cron.WithParser(cron.NewParser(
		cron.Second|cron.Minute|cron.Hour|cron.Dom|cron.Month|cron.Dow|cron.Descriptor,
	)), cron.WithLogger(
		cron.VerbosePrintfLogger(log.New(os.Stdout, "cron: ", log.LstdFlags))))
	c.AddJob("*/1 * * * * *", &User{
		Name: "job",
	})

	c.Start()
	time.Sleep(time.Second * 5)
}

```

上面调用cron.VerbosPrintfLogger包装log.Logger，个logger会详细记录cron内部的调度过程：

```go
cron: 2020/09/14 13:57:21 start
cron: 2020/09/14 13:57:21 schedule, now=2020-09-14T13:57:21+08:00, entry=1, next=2020-09-14T13:57:22+08:00
cron: 2020/09/14 13:57:22 wake, now=2020-09-14T13:57:22+08:00
cron: 2020/09/14 13:57:22 run, now=2020-09-14T13:57:22+08:00, entry=1, next=2020-09-14T13:57:23+08:00
hello, job
cron: 2020/09/14 13:57:23 wake, now=2020-09-14T13:57:23+08:00
hello, job
cron: 2020/09/14 13:57:23 run, now=2020-09-14T13:57:23+08:00, entry=1, next=2020-09-14T13:57:24+08:00
cron: 2020/09/14 13:57:24 wake, now=2020-09-14T13:57:24+08:00
cron: 2020/09/14 13:57:24 run, now=2020-09-14T13:57:24+08:00, entry=1, next=2020-09-14T13:57:25+08:00
hello, job
cron: 2020/09/14 13:57:25 wake, now=2020-09-14T13:57:25+08:00
cron: 2020/09/14 13:57:25 run, now=2020-09-14T13:57:25+08:00, entry=1, next=2020-09-14T13:57:26+08:00
hello, job
cron: 2020/09/14 13:57:26 wake, now=2020-09-14T13:57:26+08:00
cron: 2020/09/14 13:57:26 run, now=2020-09-14T13:57:26+08:00, entry=1, next=2020-09-14T13:57:27+08:00
hello, job
```



## WithChain 和 Job Wrappers 

Cron  可以配置一个job wrappers,用于所有提交的job添加横切功能 。比如

> A Cron runner may be configured with a chain of job wrappers to add cross-cutting functionality to all submitted jobs. 



- Recover any panics from jobs (activated by default)
- Delay a job's execution if the previous run hasn't completed yet
- Skip a job's execution if the previous run hasn't completed yet
- Log each job's invocations



Cron 内置了三个job wrappers 

- Recover: 捕获内部Job产生的panic
- DelayIfStillRunning：触发时，如果上一次任务还未执行完成（耗时太长），则等待上一次任务完成之后再执行；
- SkipIfStillRunning：触发时，如果上一次任务还未完成，则跳过此次执行。



当然我们也可以自己定义一些 Cron 

```go
type User struct {
	Name string
}

func (u *User) Hello() {
	fmt.Println("hello," + u.Name)
}

func (u *User) Run() {
	u.Hello()
}

func Before()cron.JobWrapper  {
	return func(j cron.Job) cron.Job {
		f := func() {
			log.Println("Before")
			j.Run()
		}

		return cron.FuncJob(f)
	}
}

func After()cron.JobWrapper  {
	return func(j cron.Job) cron.Job {
		f := func() {
			j.Run()
			log.Println("After")
		}

		return cron.FuncJob(f)
	}
}

func main() {
	c := cron.New(cron.WithChain(Before(),After()),cron.WithSeconds())
	c.AddJob("*/1 * * * * *", &User{
		Name: "job",
	})


	c.Start()
	time.Sleep(time.Second * 5)
}
```

out 

```
2020/09/14 19:35:39 Before
hello,job
2020/09/14 19:35:39 After
2020/09/14 19:35:40 Before
hello,job
2020/09/14 19:35:40 After
2020/09/14 19:35:41 Before
hello,job
2020/09/14 19:35:41 After
2020/09/14 19:35:42 Before
hello,job
2020/09/14 19:35:42 After
2020/09/14 19:35:43 Before
hello,job
2020/09/14 19:35:43 After
```








# 参考连接

Go Cron 官方文档 https://godoc.org/github.com/robfig/cron

Go Cron 源码 https://github.com/robfig/cron

Go 每日一库之 cron https://darjun.github.io/2020/06/25/godailylib/cron/

