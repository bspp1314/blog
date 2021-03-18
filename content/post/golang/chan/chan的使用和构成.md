---
title: "反射"
date: 2021-03-18T10:43:49+08:00
draft: true
categories: ["golang"]
tags: ["chan"]
---

## 概述
作为 Go 语言中核心的数据结构和 Goroutine 之间的通信方式，Channel 是支撑 Go 语言高性能并发编程模型的结构之一，我们首先需要了解 Channel 背后的设计原理以及它的底层数据结构。

## 设计原理    
在 Go 语言中，**一个最常见的也是经常被人提及的设计模式就是不要通过共享内存的方式进行通信，而是应该通过通信的方式共享内存**，在很多主流的编程语言中，当我们想要并发执行一些代码时，我们往往都会在多个线程之间共享变量，同时为了解决线程冲突的问题，我们又需要在读写这些变量时加锁。

![image-20210318143425868](image-20210318143425868.png)

Go 语言对于并发编程的设计与上述这种共享内存的方式完全不同，虽然我们在 Golang 中也能使用共享内存加互斥锁来实现并发编程，但是与此同时，Go 语言也提供了一种不同的并发模型，也就是 CSP，即通信顺序进程（Communicating sequential processes），Goroutine 其实就是 CSP 中的实体，Channel 就是用于传递信息的通道，使用 CSP 并发模型的 Goroutine 就会通过 Channel 来传递消息。

![image-20210318143513467](image-20210318143513467.png)



上图中的两个 Goroutine，一个会负责向 Channel 中发送消息，另一个会负责从 Channel 中接收消息，它们两者并没有任何直接的关联，能够独立地工作和运行，但是间接地通过 Channel 完成了通信。





# 简单的使用

## 创建channel

channel 使用之前需要通过 make 创建。

```go
unBufferChan := make(chan int)  // 1
bufferChan := make(chan int, 4) // 2

```

上面的方式 1 创建的是无缓冲 channel，方式 2 创建的是缓冲 channel。如果使用 channel 之前没有 make，会出现 dead lock 错误。至于为什么是 dead lock。

```go
func main() {
    var x chan int
    go func() {
        x <- 1
    }()
    <-x
}
```



```go
fatal error: all goroutines are asleep - deadlock!

goroutine 1 [chan receive (nil chan)]:
main.main()
        /Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/channel-lib/ex1/main.go:10 +0x4a

goroutine 5 [chan send (nil chan)]:
main.main.func1(0x0)
        /Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/channel-lib/ex1/main.go:7 +0x37
created by main.main
        /Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/channel-lib/ex1/main.go:6 +0x3e
exit status 2

```



## channel 读写操作



```go
func main() {
	ch := make(chan int,10)

	go func() {
		for i := 0; i < 10; i++ {
      //读操作
			ch <- i
		}
	}()

	for i := 0; i < 10; i++ {
    //写操作
    v：= <-ch 
		fmt.Println("Rev value is ",v)
	}
}

```



## channel 分裂

channel 分为无缓冲 channel 和有缓冲 channel。两者的区别如下：

- 无缓冲：发送和接收动作是同时发生的。如果没有 goroutine 读取 channel （<- channel），则发送者 (channel <-) 会一直阻塞



![image-20210318145140731](image-20210318145140731.png)

- 缓冲：缓冲 channel 类似一个有容量的队列。当队列满的时候发送者会阻塞；当队列空的时候接收者会阻塞。

![image-20210318145201207](image-20210318145201207.png)

关于关闭 channel 有几点需要注意的是：

- 重复关闭 channel 会导致 panic。
- 向关闭的 channel 发送数据会 panic。
- 从关闭的 channel 读数据不会 panic，读出 channel 中已有的数据之后再读就是 channel 类似的默认值，比如 chan int 类型的 channel 关闭之后读取到的值为 0。

对于上面的第三点，我们需要区分一下：channel 中的值是默认值还是 channel 关闭了。可以使用 ok-idiom 方式，这种方式在 map 中比较常用。

```go
ch := make(chan int, 10)
...
close(ch)

// ok-idiom 
val, ok := <-ch
if ok == false {
    // channel closed
}
```



# chan 的典型 用法

## 简单的groutine 通信

```go
func main() {
    x := make(chan int)
    go func() {
        x <- 1
    }()
    <-x
}
```





## Select 

select 一定程度上可以类比于 linux 中的 IO 多路复用中的 select。后者相当于提供了对多个 IO 事件的统一管理，而 Golang 中的 select 相当于提供了对多个 channel 的统一管理。当然这只是 select 在 channel 上的一种使用方法。

```go
select {
    case e, ok := <-ch1:
        ...
    case e, ok := <-ch2:
        ...
    default:  
}
```



## rang channel 

range channel 可以直接取到 channel 中的值。当我们使用 range 来操作 channel 的时候，一旦 channel 关闭，channel 内部数据读完之后循环自动结束。

```go
func consumer(ch <-chan int)  {
	for c := range ch {
		fmt.Println("Rev value is ",c)
	}
}

func producer(ch chan<- int)  {
	for i := 0; i < 10; i++ {
		ch <- i
	}
}

func main() {
	ch := make(chan int,1)

	go consumer(ch)
	go producer(ch)

	time.Sleep(time.Second)
}

```

out 

```shell
Rev value is  0
Rev value is  1
Rev value is  2
Rev value is  3
Rev value is  4
Rev value is  5
Rev value is  6
Rev value is  7
Rev value is  8
Rev value is  9
```





# chan 的runtime 结构

```go
type hchan struct {
  //队列中数据的个数
	qcount   uint           // total data in the queue 
	// channel 大小
  dataqsiz uint           // size of the circular queue
	//存放数据的环形数组
  buf      unsafe.Pointer // points to an array of dataqsiz elements
	//channel 中数据类型的大小
  elemsize uint16
	//表示 channel 是否关闭
  closed   uint32
  //元素数据类型
	elemtype *_type // element type
	//send 的数组索引
  sendx    uint   // send index
	// recv 的数组索引
  recvx    uint   // receive index
  // 由 recv 行为（也就是 <-ch）阻塞在 channel 上的 goroutine 队列
	recvq    waitq  // list of recv waiters
  //  send 行为 (也就是 ch<-) 阻塞在 channel 上的 goroutine 队列
	sendq    waitq  // list of send waiters

	// lock protects all fields in hchan, as well as several
	// fields in sudogs blocked on this channel.
	//
	// Do not change another G's status while holding this lock
	// (in particular, do not ready a G), as this can deadlock
	// with stack shrinking.
	lock mutex
}

type waitq struct {
    first *sudog
    last  *sudog
}
type sudog struct {
    // The following fields are protected by the hchan.lock of the
    // channel this sudog is blocking on. shrinkstack depends on
    // this for sudogs involved in channel ops.

    g          *g
    selectdone *uint32 // CAS to 1 to win select race (may point to stack)
    next       *sudog
    prev       *sudog
    elem       unsafe.Pointer // data element (may point to stack)

    // The following fields are never accessed concurrently.
    // For channels, waitlink is only accessed by g.
    // For semaphores, all fields (including the ones above)
    // are only accessed when holding a semaRoot lock.

    acquiretime int64
    releasetime int64
    ticket      uint32
    parent      *sudog // semaRoot binary tree
    waitlink    *sudog // g.waiting list or semaRoot
    waittail    *sudog // semaRoot
    c           *hchan // channel
}

```

我们可以看到 channel 其实就是一个队列加一个锁，只不过这个锁是一个轻量级锁。其中 recvq 是读操作阻塞在 channel 的 goroutine 列表，sendq 是写操作阻塞在 channel 的 goroutine 列表。列表的实现是 sudog，其实就是一个对 g 的结构的封装。





# runtime.makechan 

```go
package main

func main() {
	x := make(chan int,1)

	go func() {
		x <-1
	}()

	<- x
	close(x)
}


```

我们通过一下命令来获取上面代码的汇编

```go
 go tool compile -l -N -S main.go 
```



```go
"".main STEXT size=158 args=0x0 locals=0x28
        0x0000 00000 (main.go:3)        TEXT    "".main(SB), ABIInternal, $40-0
        0x0000 00000 (main.go:3)        MOVQ    (TLS), CX
        0x0009 00009 (main.go:3)        CMPQ    SP, 16(CX)
        0x000d 00013 (main.go:3)        PCDATA  $0, $-2
        0x000d 00013 (main.go:3)        JLS     148
        0x0013 00019 (main.go:3)        PCDATA  $0, $-1
        0x0013 00019 (main.go:3)        SUBQ    $40, SP
        0x0017 00023 (main.go:3)        MOVQ    BP, 32(SP)
        0x001c 00028 (main.go:3)        LEAQ    32(SP), BP
        0x0021 00033 (main.go:3)        FUNCDATA        $0, gclocals·69c1753bd5f81501d95132d08af04464(SB)
        0x0021 00033 (main.go:3)        FUNCDATA        $1, gclocals·9fb7f0986f647f17cb53dda1484e0f7a(SB)
        0x0021 00033 (main.go:4)        LEAQ    type.chan int(SB), AX
        0x0028 00040 (main.go:4)        MOVQ    AX, (SP)
        0x002c 00044 (main.go:4)        MOVQ    $1, 8(SP)
        0x0035 00053 (main.go:4)        PCDATA  $1, $0
        0x0035 00053 (main.go:4)        CALL    runtime.makechan(SB)
.....
```

可以看到  chan 最终的创建 函数为  `runtime.makechan`

```go
func makechan(t *chantype, size int) *hchan {
	elem := t.elem

	// compiler checks this but be safe.
  // 元素的大小不能 64k  
	if elem.size >= 1<<16 {
		throw("makechan: invalid channel element type")
	}
  //内存对齐判断
	if hchanSize%maxAlign != 0 || elem.align > maxAlign {
		throw("makechan: bad alignment")
	}

  //获取并判断chan 数据 需要的内存是否溢出
	mem, overflow := math.MulUintptr(elem.size, uintptr(size))
  // maxAlloc 为最大可分配内存
	if overflow || mem > maxAlloc-hchanSize || size < 0 {
		panic(plainError("makechan: size out of range"))
	}

	// Hchan does not contain pointers interesting for GC when elements stored in buf do not contain pointers.
	// buf points into the same allocation, elemtype is persistent.
	// SudoG's are referenced from their owning thread so they can't be collected.
	// TODO(dvyukov,rlh): Rethink when collector can move allocated objects.
	var c *hchan
	switch {
	case mem == 0:
    // 需要的内存大小为0，只需要分配hchan的内存即可
		// Queue or element size is zero.
		c = (*hchan)(mallocgc(hchanSize, nil, true))
   		
		// Race detector uses this location for synchronization.
		c.buf = c.raceaddr()
	case elem.ptrdata == 0:
    // elem 不包含指针数据
		// Elements do not contain pointers.
		// Allocate hchan and buf in one call.
		c = (*hchan)(mallocgc(hchanSize+mem, nil, true))
		c.buf = add(unsafe.Pointer(c), hchanSize)
	default:
		// Elements contain pointers.
		c = new(hchan)
		c.buf = mallocgc(mem, elem, true)
	}

	c.elemsize = uint16(elem.size)
	c.elemtype = elem
	c.dataqsiz = uint(size)
	lockInit(&c.lock, lockRankHchan)

	if debugChan {
		print("makechan: chan=", c, "; elemsize=", elem.size, "; dataqsiz=", size, "\n")
	}
	return c
}

// MulUintptr returns a * b and whether the multiplication overflowed.
// On supported platforms this is an intrinsic lowered by the compiler.
func MulUintptr(a, b uintptr) (uintptr, bool) {
	if a|b < 1<<(4*sys.PtrSize) || a == 0 {
		return a * b, false
	}
	overflow := b > MaxUintptr/a
	return a * b, overflow
}


```

makechan 的函数非常简单，就是简单的检查了一下是否可以创建chan，检查按照情况分配内存。

- mem == 0 ，说明是无缓冲，不需要为buf分配内存，将其指向其本身即可
- elem.ptrdata == 0，elem 为非指针，buf 和 hchan 分配在一块连续的内存智商
- elem 为 指针，buf 和 hchan 内存各自分配

# Send 

我们根据 go tool 命令 汇编码

```go
"".main.func1 STEXT size=72 args=0x8 locals=0x18
        0x0000 00000 (main.go:6)        TEXT    "".main.func1(SB), ABIInternal, $24-8
        0x0000 00000 (main.go:6)        MOVQ    (TLS), CX
        0x0009 00009 (main.go:6)        CMPQ    SP, 16(CX)
        0x000d 00013 (main.go:6)        PCDATA  $0, $-2
        0x000d 00013 (main.go:6)        JLS     65
        0x000f 00015 (main.go:6)        PCDATA  $0, $-1
        0x000f 00015 (main.go:6)        SUBQ    $24, SP
        0x0013 00019 (main.go:6)        MOVQ    BP, 16(SP)
        0x0018 00024 (main.go:6)        LEAQ    16(SP), BP
        0x001d 00029 (main.go:6)        FUNCDATA        $0, gclocals·1a65e721a2ccc325b382662e7ffee780(SB)
        0x001d 00029 (main.go:6)        FUNCDATA        $1, gclocals·69c1753bd5f81501d95132d08af04464(SB)
        0x001d 00029 (main.go:7)        MOVQ    "".x+32(SP), AX
        0x0022 00034 (main.go:7)        MOVQ    AX, (SP)
        0x0026 00038 (main.go:7)        LEAQ    ""..stmp_0(SB), AX
        0x002d 00045 (main.go:7)        MOVQ    AX, 8(SP)
        0x0032 00050 (main.go:7)        PCDATA  $1, $1
        0x0032 00050 (main.go:7)        CALL    runtime.chansend1(SB)
        0x0037 00055 (main.go:8)        MOVQ    16(SP), BP
        0x003c 00060 (main.go:8)        ADDQ    $24, SP

```

可以知道 go chan 发送数据时候，runtime会调用 runtime.chansend1 

```go
/ entry point for c <- x from compiled code
//go:nosplit
func chansend1(c *hchan, elem unsafe.Pointer) {
	chansend(c, elem, true, getcallerpc())
}

/*
 * generic single channel send/recv
 * If block is not nil,
 * then the protocol will not
 * sleep but return if it could
 * not complete.
 *
 * sleep can wake up with g.param == nil
 * when a channel involved in the sleep has
 * been closed.  it is easiest to loop and re-run
 * the operation; we'll see that it's now closed.
 */
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
  // chan 为空
	if c == nil {
    // 无需阻塞
		if !block {
			return false
		}
    // groutine 挂起
		gopark(nil, nil, waitReasonChanSendNilChan, traceEvGoStop, 2)
		throw("unreachable")
	}

	if debugChan {
		print("chansend: chan=", c, "\n")
	}

	if raceenabled {
		racereadpc(c.raceaddr(), callerpc, funcPC(chansend))
	}

	// Fast path: check for failed non-blocking operation without acquiring the lock.
	//
	// After observing that the channel is not closed, we observe that the channel is
	// not ready for sending. Each of these observations is a single word-sized read
	// (first c.closed and second full()).
	// Because a closed channel cannot transition from 'ready for sending' to
	// 'not ready for sending', even if the channel is closed between the two observations,
	// they imply a moment between the two when the channel was both not yet closed
	// and not ready for sending. We behave as if we observed the channel at that moment,
	// and report that the send cannot proceed.
	//
	// It is okay if the reads are reordered here: if we observe that the channel is not
	// ready for sending and then observe that it is not closed, that implies that the
	// channel wasn't closed during the first observation. However, nothing here
	// guarantees forward progress. We rely on the side effects of lock release in
	// chanrecv() and closechan() to update this thread's view of c.closed and full().
  // 非阻塞的且chan未关闭且chan的buff 已经满了，直接返回 
	if !block && c.closed == 0 && full(c) {
		return false
	}

	var t0 int64
	if blockprofilerate > 0 {
		t0 = cputicks()
	}

	lock(&c.lock)

  // chan 已经关闭，无法发送数据，直接抛出异常
	if c.closed != 0 {
		unlock(&c.lock)
		panic(plainError("send on closed channel"))
	}

	if sg := c.recvq.dequeue(); sg != nil {
		// Found a waiting receiver. We pass the value we want to send
		// directly to the receiver, bypassing the channel buffer (if any).
		send(c, sg, ep, func() { unlock(&c.lock) }, 3)
		return true
	}

	if c.qcount < c.dataqsiz {
		// Space is available in the channel buffer. Enqueue the element to send.
		qp := chanbuf(c, c.sendx)
		if raceenabled {
			raceacquire(qp)
			racerelease(qp)
		}
		typedmemmove(c.elemtype, qp, ep)
		c.sendx++
		if c.sendx == c.dataqsiz {
			c.sendx = 0
		}
		c.qcount++
		unlock(&c.lock)
		return true
	}

	if !block {
		unlock(&c.lock)
		return false
	}

	// Block on the channel. Some receiver will complete our operation for us.
	gp := getg()
	mysg := acquireSudog()
	mysg.releasetime = 0
	if t0 != 0 {
		mysg.releasetime = -1
	}
	// No stack splits between assigning elem and enqueuing mysg
	// on gp.waiting where copystack can find it.
	mysg.elem = ep
	mysg.waitlink = nil
	mysg.g = gp
	mysg.isSelect = false
	mysg.c = c
	gp.waiting = mysg
	gp.param = nil
	c.sendq.enqueue(mysg)
	gopark(chanparkcommit, unsafe.Pointer(&c.lock), waitReasonChanSend, traceEvGoBlockSend, 2)
	// Ensure the value being sent is kept alive until the
	// receiver copies it out. The sudog has a pointer to the
	// stack object, but sudogs aren't considered as roots of the
	// stack tracer.
	KeepAlive(ep)

	// someone woke us up.
	if mysg != gp.waiting {
		throw("G waiting list is corrupted")
	}
	gp.waiting = nil
	gp.activeStackChans = false
	if gp.param == nil {
		if c.closed == 0 {
			throw("chansend: spurious wakeup")
		}
		panic(plainError("send on closed channel"))
	}
	gp.param = nil
	if mysg.releasetime > 0 {
		blockevent(mysg.releasetime-t0, 2)
	}
	mysg.c = nil
	releaseSudog(mysg)
	return true
}
```



## 一些前置的检查

```go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
  // chan 为空
	if c == nil {
    // 无需阻塞
		if !block {
			return false
		}
    // groutine 挂起
		gopark(nil, nil, waitReasonChanSendNilChan, traceEvGoStop, 2)
		throw("unreachable")
	}

	if debugChan {
		print("chansend: chan=", c, "\n")
	}

	if raceenabled {
		racereadpc(c.raceaddr(), callerpc, funcPC(chansend))
	}

  // 非阻塞的且chan未关闭且chan的buff 已经满了，直接返回 
	if !block && c.closed == 0 && full(c) {
		return false
	}

	var t0 int64
	if blockprofilerate > 0 {
		t0 = cputicks()
	}

	lock(&c.lock)

  // chan 已经关闭，无法发送数据，直接抛出异常
	if c.closed != 0 {
		unlock(&c.lock)
		panic(plainError("send on closed channel"))
	}
```

1. chan 为 nil,如果无需阻塞，直接返回false,如果需要阻塞，挂起 groutine 
2. 如果chan 为 非阻塞的且chan未关闭且chan的buff 已经满了，直接返回 
3.  chan 已经关闭，无法发送数据，直接抛出异常



## 直接发送

如果目标 Channel 没有被关闭并且已经有处于读等待的 goroutine，那么chansend 函数会通过 dequeue 从 recvq 中取出最先陷入等待的 Goroutine 并直接向它发送数据：

```go
if sg := c.recvq.dequeue(); sg != nil {
   // Found a waiting receiver. We pass the value we want to send
   // directly to the receiver, bypassing the channel buffer (if any).
   send(c, sg, ep, func() { unlock(&c.lock) }, 3)
   return true
}
```

我们可以从下面图中简单了解一下如果 Channel 中存在等待消息的 Goroutine 时，发送消息的处理过程：

![image-20210318183506580](image-20210318183506580.png)





```go
// send processes a send operation on an empty channel c.
// The value ep sent by the sender is copied to the receiver sg.
// The receiver is then woken up to go on its merry way.
// Channel c must be empty and locked.  send unlocks c with unlockf.
// sg must already be dequeued from c.
// ep must be non-nil and point to the heap or the caller's stack.
func send(c *hchan, sg *sudog, ep unsafe.Pointer, unlockf func(), skip int) {
	if raceenabled {
		if c.dataqsiz == 0 {
			racesync(c, sg)
		} else {
			// Pretend we go through the buffer, even though
			// we copy directly. Note that we need to increment
			// the head/tail locations only when raceenabled.
			qp := chanbuf(c, c.recvx)
			raceacquire(qp)
			racerelease(qp)
			raceacquireg(sg.g, qp)
			racereleaseg(sg.g, qp)
			c.recvx++
			if c.recvx == c.dataqsiz {
				c.recvx = 0
			}
			c.sendx = c.recvx // c.sendx = (c.sendx+1) % c.dataqsiz
		}
	}
	if sg.elem != nil {
    //将数据拷贝到目标的 sudog 上
		sendDirect(c.elemtype, sg, ep)
		sg.elem = nil
	}
	gp := sg.g
	unlockf()
	gp.param = unsafe.Pointer(sg)
	if sg.releasetime != 0 {
		sg.releasetime = cputicks()
	}
  //唤醒 目标的groutine 
	goready(gp, skip+1)
}

```



## 将数据存在缓冲区
```
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
    ...
    //在这里我们首先会使用 chanbuf  
    //计算出下一个可以放置待处理变量的位置，然后
    //通过 typedmemmove 将发送的消息拷贝到缓冲区中并增加 sendx
    //索引和 qcount 
    //计数器，在函数的最后会释放持有的锁。
    if c.qcount < c.dataqsiz {
        qp := chanbuf(c, c.sendx)
        typedmemmove(c.elemtype, qp, ep)
        c.sendx++
        if c.sendx == c.dataqsiz {
            c.sendx = 0
        }
        c.qcount++
        unlock(&c.lock)
        return true
    }
    
```

