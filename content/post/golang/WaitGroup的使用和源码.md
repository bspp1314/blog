---
title: "WaitGroup的使用和源码"
date: 2020-10-27T16:25:32+08:00
draft: false
categories: ["golang"]
tags: ["并发","WaitContext"]
---

# WaitGroup 用途

[`sync.WaitGroup`](https://github.com/golang/go/blob/71239b4f491698397149868c88d2c851de2cd49b/src/sync/waitgroup.go#L20-L29) 它能够一直等到所有的goroutine执行完成，并且阻塞主线程的执行，直到所有的goroutine执行完成。

> A WaitGroup waits for a collection of goroutines to finish.The main goroutine calls Add to set the number of goroutines to wait for. Then each of the goroutines runs and calls Done when finished. At the same time,Wait can be used to block until all goroutines have finished.



# WaitGroup 的简单使用

比较常见的使用场景是批量发出 RPC 或者 HTTP 请求

```go
func main() {
	request := make([]*Request,10)

	wg := &sync.WaitGroup{}
	for i := 0;i < len(request);i++ {
		wg.Add(1)
		go HandlerReq(request[i],wg)
	}

	wg.Wait()
}

func HandlerReq(req *Request,wg *sync.WaitGroup)  {
	fmt.Println("Do Request .....")
	time.Sleep(time.Second)
	wg.Done()
}

```

# WaitGroup的结构 

[`sync.WaitGroup`](https://github.com/golang/go/blob/71239b4f491698397149868c88d2c851de2cd49b/src/sync/waitgroup.go#L20-L29) 结构体中的成员变量非常简单，其中只包含两个成员变量：

```go
// A WaitGroup must not be copied after first use.
type WaitGroup struct {
	noCopy noCopy

	// 64-bit value: high 32 bits are counter, low 32 bits are waiter count.
	// 64-bit atomic operations require 64-bit alignment, but 32-bit
	// compilers do not ensure it. So we allocate 12 bytes and then use
	// the aligned 8 bytes in them as state, and the other 4 as storage
	// for the sema.
	state1 [3]uint32
}
```

- noCopy 标志WaitGroup不允许拷贝

- state1  这个数组会存储当前结构体的状态 

  

  |      | state1[0] | state1[1] | state1[2] |
| ---- | --------- | --------- | --------- |
  | 64位 | waiter    | counter   | sema      |
  | 32位 | sema      | waiter    | counter   |
  |      |           |           |           |
  
  
  

- counter： 当前还未执行结束的goroutine计数器
- waiter:  等待goroutine-group结束的goroutine数量，即有多少个等候者
- semaphore: 信号量





# ADD 

```go
// Add adds delta, which may be negative, to the WaitGroup counter.
// If the counter becomes zero, all goroutines blocked on Wait are released.
// If the counter goes negative, Add panics.
//
// Note that calls with a positive delta that occur when the counter is zero
// must happen before a Wait. Calls with a negative delta, or calls with a
// positive delta that start when the counter is greater than zero, may happen
// at any time.
// Typically this means the calls to Add should execute before the statement
// creating the goroutine or other event to be waited for.
// If a WaitGroup is reused to wait for several independent sets of events,
// new Add calls must happen after all previous Wait calls have returned.
// See the WaitGroup example.
func (wg *WaitGroup) Add(delta int) {
  // 获取和state 和  semaphore
   statep, semap := wg.state()
   if race.Enabled {
      _ = *statep // trigger nil deref early
      if delta < 0 {
         // Synchronize decrements with Wait.
         race.ReleaseMerge(unsafe.Pointer(wg))
      }
      race.Disable()
      defer race.Enable()
   }
   
  // 给计数器原子增加加上 delta 
   state := atomic.AddUint64(statep, uint64(delta)<<32)
   //v是本次增加后计数器的值
   v := int32(state >> 32)
  //等待执行 goroutine 数量
  w := uint32(state)
  //仅用于-race编译时,与主逻辑无关
  if race.Enabled && delta > 0 && v == int32(delta) {
      // The first increment must be synchronized with Wait.
      // Need to model this as a read, because there can be
      // several concurrent wg.counter transitions from 0.
      race.Read(unsafe.Pointer(semap)) 
 }
    
    //在正常情况下,每次创建goroutine,计数器v加1;
    //该goroutine个数执行完毕调用Done使计数器v减1; 所以计数器v一定>=0
   if v < 0 {
      panic("sync: negative WaitGroup counter")
   }
    
    // 当计数器为0时，`Add`以一个正数`delta`的调用必须发生在`Wait`操作之前。
    // 这其实就是Add加的操作之前已经有Wait操作了，panic
   if w != 0 && delta > 0 && v == int32(delta) {
      panic("sync: WaitGroup misuse: Add called concurrently with Wait")
   }
  
   // 计数器为正数，没有等待者，这是说明Add成功，但是为似乎没有更新wg.state1
   if v > 0 || w == 0 {
      return
   }
   // This goroutine has set counter to 0 when waiters > 0.
   // Now there can't be concurrent mutations of state:
   // - Adds must not happen concurrently with Wait,
   // - Wait does not increment waiters if it sees counter == 0.
   // Still do a cheap sanity check to detect WaitGroup misuse.
   if *statep != state {
      panic("sync: WaitGroup misuse: Add called concurrently with Wait")
   }
   // Reset waiters count to 0.
   *statep = 0
  // Reset waiters count to 0.
	// 重置状态，并用发出等同于等待者数量的信号量，告诉所有等待者任务已经完成
  // v == 0 且 w > 0 ,
   for ; w != 0; w-- {
      runtime_Semrelease(semap, false, 0)
   }
}
```





```go
// Wait blocks until the WaitGroup counter is zero.
func (wg *WaitGroup) Wait() {
   statep, semap := wg.state()
   if race.Enabled {
      _ = *statep // trigger nil deref early
      race.Disable()
   }
   for {
      state := atomic.LoadUint64(statep)
      v := int32(state >> 32) //计算器
     w := uint32(state)//正在等待结束的goroutine数量
     // 计数器v==0就不需要等待直接返回即可
      if v == 0 {
         // Counter is 0, no need to wait.
         if race.Enabled {
            race.Enable()
            race.Acquire(unsafe.Pointer(wg))
         }
         return
      }
      // Increment waiters count.
     		// 尝试原子地将w+1,如果失败就在for循环内不停尝试,类似乐观锁
      if atomic.CompareAndSwapUint64(statep, state, state+1) {
         if race.Enabled && w == 0 {
            // Wait must be synchronized with the first Add.
            // Need to model this is as a write to race with the read in Add.
            // As a consequence, can do the write only for the first waiter,
            // otherwise concurrent Waits will race with each other.
            race.Write(unsafe.Pointer(semap))
         }
         //此处v>0,所以需要等待v减为0;当v通过Add()减为0时,会唤醒此处的等待
         runtime_Semacquire(semap)
         //简单检测一个并发问题: 当Wait()被唤醒后,应满足v==0&&w==0
         //否则一定出现了Wait()返回前,Add()被并发调用的问题
         if *statep != 0 {
            panic("sync: WaitGroup is reused before previous Wait has returned")
         }
         if race.Enabled {
            race.Enable()
            race.Acquire(unsafe.Pointer(wg))
         }
         return
      }
   }
}
```



# 参考

同步原语和锁  https://draveness.me/golang/docs/part3-runtime/ch06-concurrency/golang-sync-primitives/

Golang 之 WaitGroup 源码解析 https://www.linkinstar.wiki/2020/03/15/golang/source-code/sync-waitgroup-source-code/


