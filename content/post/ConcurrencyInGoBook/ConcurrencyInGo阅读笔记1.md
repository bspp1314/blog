---
title: "ConcurrencyInGo阅读笔记1"
date: 2020-09-08T10:47:52+08:00
draft: true
---



# Race Conditons (竞态条件)

什么是竞态条件 ？

> A race condition occurs when two or more operations must execute in the correct
> order, but the program has not been written so that this order is guaranteed to be
> maintained.

大多数时候，这出现在所谓的数据竞争（Data Race）中，其中一个并发操作尝试在某些未确定的时间读取变量，而另一个并发操作尝试写入同一个变量。



一个小例子

```go
1 var data int
2 go func() {
3 data++
4 }()
5 if data == 0 {
6 fmt.Printf("the value is %v.\n", data)
7 }
```



上述代码可能会出现以下三种情况

- Nothing is printed. In this case, line 3 was executed before line 5.
-  “the value is 0” is printed. In this case, lines 5 and 6 were executed before line 3
-  “the value is 1” is printed. In this case, line 5 was executed before line 3, but line 3
  was executed before line 6.

之所以出现以上三种情况是因为在写这些并发代码的时候，开发发人员按顺序编写代码，而事实上并发代码不是顺序运行的。

> Most of the time, data races are introduced because the developers are thinking about
> the problem sequentially. They assume that because a line of code falls before another
> that it will run first. They assume the goroutine above will be scheduled and execute
> before the data variable is read in the if statement.



# Atomicity 原子性

什么是原子性

> When something is considered atomic, or to have the property of atomicity, this
> means that within the **context** that it is operating, it is **indivisible, or uninterruptible**.



当某种东西被认为是原子性的或者具有原子性的时候,那么久意味着它在运行的上下文（context）是不可分割的和中断。请注意所谓的原子性一定是在某一个Context中或者说是在某一个层级下才有意义的。



> The first thing that’s very important is the word “context.” Something may be atomic
> in one context, but not another. Operations that are atomic within the context of your
> process may not be atomic in the context of the operating system; operations that are
> atomic within the context of the operating system may not be atomic within the con‐
> text of your machine; and operations that are atomic within the context of your
> machine may not be atomic within the context of your application. In other words,
> the atomicity of an operation can change depending on the currently defined scope.
> This fact can work both for and against you



一个简单的例子

```go 
i++
```

上述这个简单的代码端看起来很像一个原子操作,我们可以来分析一下这操作的三个过程

1.  Retrieve the value of i 
2. Increment the value of  i 
3. Store the value of i 



尽管这些操作中的每一个都是原子的，但三者的组合可能不是，取决于你的上下文。 这揭示了原子操作的一个有趣特性：将它们结合并不一定会产生更大的原子操作。 创建操作原子取决于你希望它在哪个上下文中处于原子状态。 如果你的上下文是一个没有并发进程的程序，那么这个代码在该上下文中是原子的。



## 原子性的重要性

> Atomicity is important because if something is atomic, implicitly it is safe within concurrent contexts. This allows us to compose logically correct pro‐
> grams。



# Memory Access Synchronization(内存访问同步)

解决 Data Race 一个简单的方法就是引入内存访问同步已经锁，我们可以对上面的Data Race 代码进行一下优化。

```go
var memoryAccess sync.Mutex //1
var value int
go func() {
	memoryAccess.Lock() //2
	value++
	memoryAccess.Unlock() //3
}()

memoryAccess.Lock() //4
if value == 0 {
	fmt.Printf("the value is %v.\n", value)
} else {
	fmt.Printf("the value is %v.\n", value)
}
memoryAccess.Unlock() //5
```



内存访问同步和锁虽然解决了看似解决了Data Race,当实际上还是存在一些问题。其一这个程序的操作顺序仍然不确定。 我们刚刚只是缩小了非确定性的范围。在这个例子中，仍然不确定goroutine是否会先执行，或者我们的if和else块是否都会执行。其二代码里面引入了锁，加锁和释放锁的过程必然会带来一定的开销，当然这还是最严重的问题，锁的引入可能导致程序出现死锁等问题。



# DeadLock

什么是死锁

> A deadlocked program is one in which all concurrent processes are waiting on one
> another. In this state, the program will never recover without outside intervention

具体来说死锁可以是这样产生的

Resource A and resource B are used by process X and process Y

- X starts to use A.
- X and Y try to start using B
- Y 'wins' and gets B first
- now Y needs to use A
- A is locked by X, which is waiting for Y







# 参考

What is  a Race Conditions  https://stackoverflow.com/questions/34510/what-is-a-race-condition

What is DeadLock https://stackoverflow.com/questions/34512/what-is-a-deadlock



