---
title: "Mutex和RWMutex的使用和源码"
date: 2020-11-10T16:07:27+08:00
draft: true
---

# Mutex 

[sync.Mutex](https://golang.org/pkg/sync/#Mutex)是Go标准库中常用的一个互斥锁。当一个 goroutine 获得了这个锁的拥有权后， 其它请求锁的 goroutine 就会阻塞在 `Lock` 方法的调用上，直到锁被释放。



## sync.Mutex 简单的使用

```go
type Source struct {
	counter  int64
	sync.Mutex
}

func (s *Source) Add(counter int64)  {
	s.Lock()
	s.counter += counter
	defer s.Unlock()
}

func (s *Source)Counter() int64  {
	s.Lock()
	defer s.Unlock()

	return s.counter
}

func main() {
	// 互斥锁
	s := &Source{}
	for i:=0;i< 50 ;i++ {
		go func() {
			s.Add(10)
		}()
	}

	time.Sleep(1 * time.Second)

	fmt.Println(s.Counter())
}

```

#sync.Mutex 的结构

```go
// A Mutex is a mutual exclusion lock.
// The zero value for a Mutex is an unlocked mutex.
//
// A Mutex must not be copied after first use.
type Mutex struct {
	state int32
	sema  uint32
}

const (
	mutexLocked = 1 << iota // mutex is locked 
	mutexWoken      // 刚刚被唤醒
	mutexStarving   // 饥饿模式
	mutexWaiterShift = iota
	starvationThresholdNs = 1e6 //饥饿模式阈值：超1ms获取不到锁则进入饥饿模式
)

```



sync.Mutex 的结构非常的简单，包含两个字段 state 和 sema。state 用来保存锁的各种状态，sema用来保存信号量。

status 的各个位的含义如下

```
state:   |32|31|...|4|3|2|1|
         \__________/ | | |
               |      | | |
               |      | | mutex的占用状态（1被占用，0可用）
               |      | |
               |      |  mutex的当前goroutine是否被唤醒
               |      |
               |        饥饿的标志位
               | 当前阻塞在mutex上的goroutine数
```

sync.Mutex 的两种模式

在源代码中，有一段注释：

```
// Mutex fairness.
//
// Mutex can be in 2 modes of operations: normal and starvation.
// In normal mode waiters are queued in FIFO order, but a woken up waiter
// does not own the mutex and competes with new arriving goroutines over
// the ownership. New arriving goroutines have an advantage -- they are
// already running on CPU and there can be lots of them, so a woken up
// waiter has good chances of losing. In such case it is queued at front
// of the wait queue. If a waiter fails to acquire the mutex for more than 1ms,
// it switches mutex to the starvation mode.
//
// In starvation mode ownership of the mutex is directly handed off from
// the unlocking goroutine to the waiter at the front of the queue.
// New arriving goroutines don't try to acquire the mutex even if it appears
// to be unlocked, and don't try to spin. Instead they queue themselves at
// the tail of the wait queue.
//
// If a waiter receives ownership of the mutex and sees that either
// (1) it is the last waiter in the queue, or (2) it waited for less than 1 ms,
// it switches mutex back to normal operation mode.
//
// Normal mode has considerably better performance as a goroutine can acquire
// a mutex several times in a row even if there are blocked waiters.
// Starvation mode is important to prevent pathological cases of tail latency.
```

大概的意思是

```
// 公平锁
//
// 锁有两种模式：正常模式和饥饿模式。
// 在正常模式下，所有的等待锁的goroutine都会存在一个先进先出的队列中（轮流被唤醒）
// 但是一个被唤醒的goroutine并不是直接获得锁，而是仍然需要和那些新请求锁的（new arrivial）
// 的goroutine竞争，而这其实是不公平的，因为新请求锁的goroutine有一个优势——它们正在CPU上
// 运行，并且数量可能会很多。所以一个被唤醒的goroutine拿到锁的概率是很小的。在这种情况下，
// 这个被唤醒的goroutine会加入到队列的头部。如果一个等待的goroutine有超过1ms（写死在代码中）
// 都没获取到锁，那么就会把锁转变为饥饿模式。
//
// 在饥饿模式中，锁的所有权会直接从释放锁(unlock)的goroutine转交给队列头的goroutine，
// 新请求锁的goroutine就算锁是空闲状态也不会去获取锁，并且也不会尝试自旋。它们只是排到队列的尾部。
//
// 如果一个goroutine获取到了锁之后，它会判断以下两种情况：
// 1. 它是队列中最后一个goroutine；
// 2. 它拿到锁所花的时间小于1ms；
// 以上只要有一个成立，它就会把锁转变回正常模式。

// 正常模式会有比较好的性能，因为即使有很多阻塞的等待锁的goroutine，
// 一个goroutine也可以尝试请求多次锁。
// 饥饿模式对于防止尾部延迟来说非常的重要。
```







# 参考

sync.mutex 源代码分析  https://colobu.com/2018/12/18/dive-into-sync-mutex/

6.2 同步原语与锁 https://draveness.me/golang/docs/part3-runtime/ch06-concurrency/golang-sync-primitives/#mutex