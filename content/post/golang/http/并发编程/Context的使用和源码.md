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

# Context 的四个接口

[`context.Context`](https://github.com/golang/go/blob/df2999ef43ea49ce1578137017949c0ee660608a/src/context/context.go#L62-L154) 是 Go 语言在 1.7 版本中引入标准库的接口[1](https://draveness.me/golang/docs/part3-runtime/ch06-concurrency/golang-context/#fn:1)，该接口定义了四个需要实现的方法。
```go
// A Context carries a deadline, a cancellation signal, and other values across
// API boundaries.
//
// Context's methods may be called by multiple goroutines simultaneously.
type Context interface {
	// Deadline returns the time when work done on behalf of this context
	// should be canceled. Deadline returns ok==false when no deadline is
	// set. Successive calls to Deadline return the same results.
	Deadline() (deadline time.Time, ok bool)

	// Done returns a channel that's closed when work done on behalf of this
	// context should be canceled. Done may return nil if this context can
	// never be canceled. Successive calls to Done return the same value.
	// The close of the Done channel may happen asynchronously,
	// after the cancel function returns.
	//
	// WithCancel arranges for Done to be closed when cancel is called;
	// WithDeadline arranges for Done to be closed when the deadline
	// expires; WithTimeout arranges for Done to be closed when the timeout
	// elapses.
	//
	// Done is provided for use in select statements:
	//
	//  // Stream generates values with DoSomething and sends them to out
	//  // until DoSomething returns an error or ctx.Done is closed.
	//  func Stream(ctx context.Context, out chan<- Value) error {
	//  	for {
	//  		v, err := DoSomething(ctx)
	//  		if err != nil {
	//  			return err
	//  		}
	//  		select {
	//  		case <-ctx.Done():
	//  			return ctx.Err()
	//  		case out <- v:
	//  		}
	//  	}
	//  }
	//
	// See https://blog.golang.org/pipelines for more examples of how to use
	// a Done channel for cancellation.
	Done() <-chan struct{}

	// If Done is not yet closed, Err returns nil.
	// If Done is closed, Err returns a non-nil error explaining why:
	// Canceled if the context was canceled
	// or DeadlineExceeded if the context's deadline passed.
	// After Err returns a non-nil error, successive calls to Err return the same error.
	Err() error

	// Value returns the value associated with this context for key, or nil
	// if no value is associated with key. Successive calls to Value with
	// the same key returns the same result.
	//
	// Use context values only for request-scoped data that transits
	// processes and API boundaries, not for passing optional parameters to
	// functions.
	//
	// A key identifies a specific value in a Context. Functions that wish
	// to store values in Context typically allocate a key in a global
	// variable then use that key as the argument to context.WithValue and
	// Context.Value. A key can be any type that supports equality;
	// packages should define keys as an unexported type to avoid
	// collisions.
	//
	// Packages that define a Context key should provide type-safe accessors
	// for the values stored using that key:
	//
	// 	// Package user defines a User type that's stored in Contexts.
	// 	package user
	//
	// 	import "context"
	//
	// 	// User is the type of value stored in the Contexts.
	// 	type User struct {...}
	//
	// 	// key is an unexported type for keys defined in this package.
	// 	// This prevents collisions with keys defined in other packages.
	// 	type key int
	//
	// 	// userKey is the key for user.User values in Contexts. It is
	// 	// unexported; clients use user.NewContext and user.FromContext
	// 	// instead of using this key directly.
	// 	var userKey key
	//
	// 	// NewContext returns a new Context that carries value u.
	// 	func NewContext(ctx context.Context, u *User) context.Context {
	// 		return context.WithValue(ctx, userKey, u)
	// 	}
	//
	// 	// FromContext returns the User value stored in ctx, if any.
	// 	func FromContext(ctx context.Context) (*User, bool) {
	// 		u, ok := ctx.Value(userKey).(*User)
	// 		return u, ok
	// 	}
	Value(key interface{}) interface{}
}
```

## Deadline

> Deadline returns the time when work done on behalf of this context should be canceled. Deadline returns ok==false when no deadline is set. Successive calls to Deadline return the same results.

如果ok为true deadline 返回被取消的时间，也就是完成工作的截止日期。否则的话工作就不存在deadline.

## Done

> Done returns a channel that’s closed when work done on behalf of this context should be canceled. Done may return nil if this context can never be canceled. Successive calls to Done > >return the same value.The close of the Done channel may happen asynchronously,after the cancel function returns.

返回一个 Channel，这个 Channel 会在当前工作完成或者上下文被取消之后关闭，多次调用 Done 方法会返回同一个 Channel

## Err

> If Done is not yet closed, Err returns nil. If Done is closed, Err returns a non-nil error explaining why:Canceled if the context was canceled or DeadlineExceeded if the context’s deadline passed.After Err returns a non-nil error, successive calls to Err return the same error.

如果Done 中的 Channel 未被关闭，那么返回为空。

如果Done 中的 Channel 被关闭了，返回context.Context结束的原因

- 如果context.Context被取消，会返回Canceled
- 如果context.Context超时，会返回DeadlineExceeded 错误

## Value

从 context.Context 中获取键对应的值，对于同一个上下文来说，多次调用 Value 并传入相同的 Key 会返回相同的结果，该方法可以用来传递请求特定的数据

# Context 默认上下文

Golang 定义了Context接口后，自己简单的实现了这个接口。

```go
// An emptyCtx is never canceled, has no values, and has no deadline. It is not
// struct{}, since vars of this type must have distinct addresses.
type emptyCtx int

func (*emptyCtx) Deadline() (deadline time.Time, ok bool) {
	return
}

func (*emptyCtx) Done() <-chan struct{} {
	return nil
}

func (*emptyCtx) Err() error {
	return nil
}

func (*emptyCtx) Value(key interface{}) interface{} {
	return nil
}

func (e *emptyCtx) String() string {
	switch e {
	case background:
		return "context.Background"
	case todo:
		return "context.TODO"
	}
	return "unknown empty Context"
}
```



context.emptyCtx 通过返回 `nil` 实现了 context.Context 接口，它没有任何特殊的功能。所以，这实际上是一个空的 context，永远不会被 cancel，没有存储值，也没有 deadline。

它被包装成：



```
var (
	background = new(emptyCtx)
	todo       = new(emptyCtx)
)
```



通过下面两个导出的函数对外公开：

```
func Background() Context {
	return background
}

func TODO() Context {
	return todo
}
```

- context.Background 一般是上下文的默认值，一般在main函数里设定，所有其他的上下文都应该从它衍生（Derived）出来；

- context.TODO 应该只在不确定应该使用哪种上下文时使用；

  

# Context.WithCancel

context.WithCancel函数函数返回一个新的context.Context并返回用于取消该上下文的函数CancelFunc.执行返回的取消函数，当前上下文以及它的子上下文都会被取消，所有的 Goroutine 都会同步收到这一取消信号。我们可以来看一个例子

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())

	for i := 0; i < 3; i++ {
		go handle(ctx,i)
	}

	select {
	case <-time.After(1 * time.Second):
		fmt.Println("...")
		cancel()
	}

	time.Sleep(1 * time.Second)
}


func handle(ctx context.Context,id int) {
	for {
		select {
		case <-ctx.Done():
			fmt.Printf("任务 %d 退出停止了...\n",id)
			return
		default:
			fmt.Printf("goroutine执行任务 %d 中...\n",id)
			time.Sleep(300 * time.Millisecond)
		}
	}

}

```

out

```
goroutine执行任务 0 中...
goroutine执行任务 1 中...
goroutine执行任务 2 中...
goroutine执行任务 2 中...
goroutine执行任务 1 中...
goroutine执行任务 0 中...
goroutine执行任务 0 中...
goroutine执行任务 1 中...
goroutine执行任务 2 中...
goroutine执行任务 1 中...
goroutine执行任务 2 中...
goroutine执行任务 0 中...
...
任务 0 退出停止了...
任务 2 退出停止了...
任务 1 退出停止了...
```
启动了3个任务goroutine执行任务，每一个都使用了Context进行跟踪，当我们使用cancel函数通知取消时，这3个goroutine都会被结束。这就是Context的控制能力，所有基于这个Context或者衍生的子Context都会收到通知，这时就可以进行清理操作了，最终释放goroutine，这就优雅的解决了goroutine启动后不可控的问题。

## context.WithCancel源码

```go
//WithCancel returns a copy of parent with a new Done channel. The returned
//context's Done channel is closed when the returned cancel function is called
//or when the parent context's Done channel is closed, whichever happens first.
//
//Canceling this context releases resources associated with it, so code should
//call cancel as soon as the operations running in this Context complete.
func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
	if parent == nil {
		panic("cannot create context from nil parent")
	}
	c := newCancelCtx(parent)
	propagateCancel(parent, &c)
	return &c, func() { c.cancel(true, Canceled) }
}

// newCancelCtx returns an initialized cancelCtx.
func newCancelCtx(parent Context) cancelCtx {
	return cancelCtx{Context: parent}
}

```

- newCancelCtx 根据上层传入的context创建一个cancelCtx
- propagateCancel 会构建父子上下文之间的关联，当父上下文被取消时，子上下文也会被取消

> propagateCancel arranges for child to be canceled when parent is.

我们先来看一下context.cancelCtx结构

```go
type cancelCtx struct {
	Context

	// 保护之后的字段
	mu       sync.Mutex
	done     chan struct{}
	children map[canceler]struct{}
	err      error
}
```

这是一个可以取消的 Context，实现了 canceler 接口。它直接将接口 Context 作为它的一个匿名字段，这样，它就可以被看成一个 Context。

## cancelCtx

Done 函数

```go
func (c *cancelCtx) Done() <-chan struct{} {
	c.mu.Lock()
	if c.done == nil {
		c.done = make(chan struct{})
	}
	d := c.done
	c.mu.Unlock()
	return d
}
```

Done 函数返回的是一长度为0的 channel，而且没有地方向这个 channel 里面写数据。所以，直接调用读这个 channel，协程会被 block 住。一般通过搭配 select 来使用。一旦关闭，就会立即读出零值。

Cancel 函数

```go
// cancel closes c.done, cancels each of c's children, and, if
// removeFromParent is true, removes c from its parent's children.
func (c *cancelCtx) cancel(removeFromParent bool, err error) {
  // 二人 必须为空
	if err == nil {
		panic("context: internal error: missing cancel error")
	}
  //已经被其他gcanceled 
	c.mu.Lock()
	if c.err != nil {
		c.mu.Unlock()
		return // already canceled
	}
  // 给 err 字段赋值
	c.err = err
  // 关闭 channel，通知其他协程
	if c.done == nil {
		c.done = closedchan
	} else {
		close(c.done)
	}
	for child := range c.children {
		// NOTE: acquiring the child's lock while holding parent's lock.
    // 递归地取消所有子节点
		child.cancel(false, err)
	}
	c.children = nil
	c.mu.Unlock()

	if removeFromParent {
     // 从父节点中移除自己 
		removeChild(c.Context, c)
	}
}
```

## propagateCancel

propagateCancel 是将parent和child context相关联使得当parent被canceler时候，child context 也被canceler

```go
// propagateCancel arranges for child to be canceled when parent is.
func propagateCancel(parent Context, child canceler) {
  //如果parent.Done() == nil,parent不会取法Done,当前函数直接方法nil即可
	done := parent.Done()
	if done == nil {
		return // parent is never canceled
	}

  // parent context 已经被取消
	select {
	case <-done:
		// parent is already canceled
		child.cancel(false, parent.Err())
		return
	default:
	}

  //Context 转换成cancelCtx,转换成功
	if p, ok := parentCancelCtx(parent); ok {
		p.mu.Lock()
		if p.err != nil {
			// parent has already been canceled
			child.cancel(false, p.err)
		} else {
			if p.children == nil {
				p.children = make(map[canceler]struct{})
			}
      
      // 将 child 和 parent 关联
			p.children[child] = struct{}{}
		}
		p.mu.Unlock()
	} else {
    //如果parent无法转换成cancelCtx,新启动一个协程监控父节点或子节点取消信号
		atomic.AddInt32(&goroutines, +1)
		go func() {
			select {
			case <-parent.Done():
				child.cancel(false, parent.Err())
			case <-child.Done():
			}
		}()
	}
}
```
# WithTimeout 和 WithDeadline

WithTimeout实际上调用也是WithDeadline.

```go
// WithTimeout returns WithDeadline(parent, time.Now().Add(timeout)).
//
// Canceling this context releases resources associated with it, so code should
// call cancel as soon as the operations running in this Context complete:
//
// 	func slowOperationWithTimeout(ctx context.Context) (Result, error) {
// 		ctx, cancel := context.WithTimeout(ctx, 100*time.Millisecond)
// 		defer cancel()  // releases resources if slowOperation completes before timeout elapses
// 		return slowOperation(ctx)
// 	}
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc) {
	return WithDeadline(parent, time.Now().Add(timeout))
}
```
在分析WithDeadline,我们需要看一下timerCtx

```go
// A timerCtx carries a timer and a deadline. It embeds a cancelCtx to
// implement Done and Err. It implements cancel by stopping its timer then
// delegating to cancelCtx.cancel.
type timerCtx struct {
	cancelCtx
	timer *time.Timer // Under cancelCtx.mu.

	deadline time.Time
}

func (c *timerCtx) cancel(removeFromParent bool, err error) {
	c.cancelCtx.cancel(false, err)
	if removeFromParent {
		// Remove this timerCtx from its parent cancelCtx's children.
		removeChild(c.cancelCtx.Context, c)
	}
	c.mu.Lock()
	if c.timer != nil {
		c.timer.Stop()
		c.timer = nil
	}
	c.mu.Unlock()
}
```
可以看到timerCtx 实际上就是cancelCtx 加上一个 timer定时器和 deadline

接下来我们来继续看WithDeadline

```go
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc) {
	if parent == nil {
		panic("cannot create context from nil parent")
	}
	if cur, ok := parent.Deadline(); ok && cur.Before(d) {
    // parent Dealine 比当前的Deadline 更早，直接返回 parent WithCancel(parent)
		// The current deadline is already sooner than the new one.
		return WithCancel(parent)
	}
  //初始化timerCtx
	c := &timerCtx{
		cancelCtx: newCancelCtx(parent),
		deadline:  d,
	}
  //当前 context 加入 parent 的子树里
	propagateCancel(parent, c)
	dur := time.Until(d)
	if dur <= 0 {
    // deadline 已经到达，直接取消
		c.cancel(true, DeadlineExceeded) // deadline has already passed
		return c, func() { c.cancel(false, Canceled) }
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.err == nil {
    // d 时间后，timer 会自动调用 cancel 函数。自动取消
		c.timer = time.AfterFunc(dur, func() {
			c.cancel(true, DeadlineExceeded)
		})
	}
	return c, func() { c.cancel(true, Canceled) }
}
```

# WithValue

context.WithValue 返回一个存储k-v的context 。我们先来看一个简单的例子

```go
func main() {
	ctx,cancel := context.WithCancel(context.Background())
	valueCtx := context.WithValue(ctx,"X-Access-Token","token value")
	valueCtx = context.WithValue(valueCtx,"From","main")
	go handler(valueCtx)

	time.Sleep(5 * time.Second)
	fmt.Println("外部取消任务")
	cancel()
	time.Sleep(time.Second)
}

func handler(ctx context.Context)  {
	valueCtx := context.WithValue(ctx,"From","handler")
	go handler2(valueCtx)
	for  {
		select {
		case <-ctx.Done():
			fmt.Printf("任务1执行中，From is %v ,Token is %v  \n",
				ctx.Value("From"),
				ctx.Value("X-Access-Token"))
			return
		default:
			fmt.Printf("任务1执行中，From is %v ,Token is %v  \n",
				ctx.Value("From"),
				ctx.Value("X-Access-Token"))
			time.Sleep(1 * time.Second)
		}
	}
}

func handler2(ctx context.Context)  {
	for  {
		select {
		case <-ctx.Done():
			fmt.Printf("任务2执行中，From is %v ,Token is %v  \n",
				ctx.Value("From"),
				ctx.Value("X-Access-Token"))
			return
		default:
			fmt.Printf("任务2执行中，From is %v ,Token is %v  \n",
				ctx.Value("From"),
				ctx.Value("X-Access-Token"))
			time.Sleep(1 * time.Second)
		}
	}
}
```
out 
```
任务1执行中，From is main ,Token is token value  
任务2执行中，From is handler ,Token is token value  
任务1执行中，From is main ,Token is token value  
任务2执行中，From is handler ,Token is token value  
任务1执行中，From is main ,Token is token value  
任务2执行中，From is handler ,Token is token value  
任务2执行中，From is handler ,Token is token value  
任务1执行中，From is main ,Token is token value  
任务2执行中，From is handler ,Token is token value  
任务1执行中，From is main ,Token is token value  
外部取消任务
任务1执行中，From is main ,Token is token value  
任务2执行中，From is handler ,Token is token value  
```
接下来我们可以看一下WithValue的源码

```go
func WithValue(parent Context, key, val interface{}) Context {
	if parent == nil {
		panic("cannot create context from nil parent")
	}
	if key == nil {
		panic("nil key")
	}
	if !reflectlite.TypeOf(key).Comparable() {
		panic("key is not comparable")
	}
	return &valueCtx{parent, key, val}
}

```
可以看到 WithVlaue 实际返回的是一个valueCtx的结构

```go
// A valueCtx carries a key-value pair. It implements Value for that key and
// delegates all other calls to the embedded Context.
type valueCtx struct {
	Context
	key, val interface{}
}

func (c *valueCtx) Value(key interface{}) interface{} {
	if c.key == key {
		return c.val
	}
	return c.Context.Value(key)
}

```

通过上面代码我们可以通过调用context.WithValue 可以形成这样一棵树

[![image-20201025142003273](http://localhost:1313/post/golang/context%E7%9A%84%E4%BD%BF%E7%94%A8%E5%92%8C%E6%BA%90%E7%A0%81/image-20201025142003273.png)](http://localhost:1313/post/golang/context的使用和源码/image-20201025142003273.png)

和链表有点像，只是它的方向相反：Context 指向它的父节点，链表则指向下一个节点。通过 WithValue 函数，可以创建层层的 valueCtx，存储 goroutine 间可以共享的变量。

Value 的取值过程是一个递归的查找过程，它会先判断当前节点的key是否是要找到的key,如果是，返回value。如果不是，那么就其parent节点进行查找。







# 参考

Go Concurrency Patterns: Context https://blog.golang.org/context

上下文Context https://draveness.me/golang/docs/part3-runtime/ch06-concurrency/golang-context/

Go语言实战笔记（二十）| Go Context https://www.flysnow.org/2017/05/12/go-in-action-go-context.html

剖析 Golang Context：从使用场景到源码分https://xie.infoq.cn/article/3e18dd6d335d1a6ab552a88e8

深度解密Go语言之context https://qcrao.com/2019/06/12/dive-into-go-context/

How to Gracefully Close Channels https://go101.org/article/channel-closing.html

Golang context.WithValue: how to add several key-value pairs https://stackoverflow.com/questions/40379960/golang-context-withvalue-how-to-add-several-key-value-pairs)



