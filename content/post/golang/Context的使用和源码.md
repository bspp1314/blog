---
title: "Context的使用和源码"
date: 2020-10-20T10:57:12+08:00
draft: false
categories: ["golang"]
tags: ["并发","Context"]
---

# 简介

看了很多了关于Context的介绍，感觉还是官方的博客最准确。<!--more-->

> In Go servers, each incoming request is handled in its own goroutine. Request handlers often start additional goroutines to access backends such as databases and RPC services. The set of goroutines working on a request typically needs access to request-specific values such as the identity of the end user, authorization tokens, and the request's deadline. When a request is canceled or times out, all the goroutines working on that request should exit quickly so the system can reclaim any resources they are using.



在 Go 的 server 里，通常每来一个请求都会启动若干个 goroutine 同时工作：有些去数据库拿数据，有些去调用rpc接口等待。这些由一个请求产生的goroutine 需要共享这个请求的基本数据，例如登陆的 token，处理请求的最大超时时间（如果超过此值再返回数据，请求方因为超时接收不到）等等。当这个请求被取消或者超时了，那么就需要尽快释放由这些请求产生的groutine,系统就可以回收相关的资源。



# 简单的使用

我们可以来看一个例子，在这个例子中我们创建了一个过期时间为 1s 的上下文，并向上下文传入 `handle` 函数，该方法会使用 500ms 的时间处理传入的『请求』：

```go
func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	go handle(ctx, 500*time.Millisecond)
	select {
	case <-ctx.Done():
    fmt.Println("请求结束")
	}
}

func handle(ctx context.Context, duration time.Duration) {
	select {
	case <-ctx.Done():
		fmt.Println("请求处理超时了...")
	case <-time.After(duration):
		fmt.Println("handle 请求处理完成")
	}
}
```

因为过期时间大于处理时间，所以我们有足够的时间处理该『请求』

```shell
handle 请求处理完成
请求结束
```

如果我们将处理『请求』时间增加至 1500ms，整个程序都会因为上下文的过期而被中止，：

```
请求结束
请求处理超时了...
```







# 参考

Go Concurrency Patterns: Context https://blog.golang.org/context

上下文Context https://draveness.me/golang/docs/part3-runtime/ch06-concurrency/golang-context/

Go语言实战笔记（二十）| Go Context https://www.flysnow.org/2017/05/12/go-in-action-go-context.html



