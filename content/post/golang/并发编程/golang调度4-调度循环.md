---
title: "Golang调度4 调度循环"
date: 2021-01-26T14:08:51+08:00
draft: true
---

上面的分析完了建了一个 goroutine，设置好了 sched 成员的 sp 和 pc 字段，并且将其添加到了 p0 的本地可运行队列，等待调度器的调度。

我们回到 rumtine.rt0_go继续看接下来的代码

```go
	// start this M
	// 主线程进入调度循环
	CALL	runtime·mstart(SB)

	CALL	runtime·abort(SB)	// mstart should never return
	RET
```

很简单的一段代码,runtime.mstart进入调度循环，如果失败，会调用runtime.abort退出.

接下来看mstart代码

```go
func mstart() {
	_g_ := getg()

	osStack := _g_.stack.lo == 0
    //对于启动过程来说，g0的stack.lo早已完成初始化，所以onStack = false
	if osStack {
		// Initialize stack bounds from system stack.
		// Cgo may have left stack size in stack.hi.
		// minit may update the stack bounds.
		size := _g_.stack.hi
		if size == 0 {
			size = 8192 * sys.StackGuardMultiplier
		}
		_g_.stack.hi = uintptr(noescape(unsafe.Pointer(&size)))
		_g_.stack.lo = _g_.stack.hi - size + 1024
	}
	// Initialize stack guard so that we can start calling regular
	// Go code.
  //栈底警示
	_g_.stackguard0 = _g_.stack.lo + _StackGuard
	// This is the g0, so we can also call go:systemstack
	// functions, which check stackguard1.
	_g_.stackguard1 = _g_.stackguard0
	mstart1()

	// Exit this thread.
	switch GOOS {
	case "windows", "solaris", "illumos", "plan9", "darwin", "aix":
		// Windows, Solaris, illumos, Darwin, AIX and Plan 9 always system-allocate
		// the stack, but put it in _g_.stack before mstart,
		// so the logic above hasn't set osStack yet.
		osStack = true
	}
	mexit(osStack)
}

```

`mstart` 函数设置了 stackguard0 和 stackguard1 字段后，就直接调用 mstart1() 函数：

```go 
func mstart1() {
  //这里的 _g_ = m0.g0 
	_g_ := getg()

	if _g_ != _g_.m.g0 {
		throw("bad runtime·mstart")
	}

	// Record the caller for use as the top of stack in mcall and
	// for terminating the thread.
	// We're never coming back to mstart1 after we call schedule,
	// so other calls can reuse the current frame.
  //getcallerpc(),获取mstart1执行完的返回地址
  //getcallersp(),获取调用mstart1时的栈顶地址
	save(getcallerpc(), getcallersp())
	asminit()////在AMD64 平台中，这个函数什么也没做，是个空函数
	minit() //与信号相关的初始化，目前不需要关心

	// Install signal handlers; after minit so that minit can
	// prepare the thread to be able to handle the signals.
	if _g_.m == &m0 {
		mstartm0()//与信号相关的初始化，目前不需要关心
	}

  //初始化过程中fn == nil,暂时不关心
	if fn := _g_.m.mstartfn; fn != nil {
		fn()
	}

	if _g_.m != &m0 {// m0已经绑定了allp[0]，不是m0的话还没有p，所以需要获取一个p
		acquirep(_g_.m.nextp.ptr())
		_g_.m.nextp = 0
	}
  //schedule函数永远不会返回
	schedule()
}

```

mstart1首先调用save函数来保存g0的调度信息,其中getcallerpc()返回的是mstart调用mstart1时被call指令压栈的返回地址，getcallersp()函数返回的是调用mstart1函数之前mstart函数的栈顶地址。我们接下来看一下 save代码

```go
func save(pc, sp uintptr) {
	_g_ := getg()

	_g_.sched.pc = pc // 设置g0的pc
	_g_.sched.sp = sp // 设置g0的sp 
	_g_.sched.lr = 0
	_g_.sched.ret = 0
	_g_.sched.g = guintptr(unsafe.Pointer(_g_))
	// We need to ensure ctxt is zero, but can't have a write
	// barrier here. However, it should always already be zero.
	// Assert that.
	if _g_.sched.ctxt != nil {
		badctxt()
	}
}

```



从上图可以看出，g0.sched.sp指向了mstart1函数执行完成后的返回地址，该地址保存在了mstart函数的栈帧之中；g0.sched.pc指向的是mstart函数中调用mstart1函数之后的 if 语句。



继续分析代码，save函数执行完成后，返回到mstart1继续其它跟m相关的一些初始化，完成这些初始化后则调用调度系统的核心函数schedule()完成goroutine的调度

```go
// One round of scheduler: find a runnable goroutine and execute it.
// Never returns.
func schedule() {
  //_g_ = 每个工作线程m对应的g0，初始化时是m0的g0
	_g_ := getg()

	if _g_.m.locks != 0 {
		throw("schedule: holding locks")
	}

	if _g_.m.lockedg != 0 {
		stoplockedm()
		execute(_g_.m.lockedg.ptr(), false) // Never returns.
	}

	// We should not schedule away from a g that is executing a cgo call,
	// since the cgo call is using the m's g0 stack.
	if _g_.m.incgo {
		throw("schedule: in cgo")
	}

top:
	pp := _g_.m.p.ptr()
	pp.preempt = false

	if sched.gcwaiting != 0 {
		gcstopm()
		goto top
	}
	if pp.runSafePointFn != 0 {
		runSafePointFn()
	}

	// Sanity check: if we are spinning, the run queue should be empty.
	// Check this before calling checkTimers, as that might call
	// goready to put a ready goroutine on the local run queue.
	if _g_.m.spinning && (pp.runnext != 0 || pp.runqhead != pp.runqtail) {
		throw("schedule: spinning with local work")
	}

	checkTimers(pp, 0)

	var gp *g
	var inheritTime bool

	// Normal goroutines will check for need to wakeP in ready,
	// but GCworkers and tracereaders will not, so the check must
	// be done here instead.
	tryWakeP := false
	if trace.enabled || trace.shutdown {
		gp = traceReader()
		if gp != nil {
			casgstatus(gp, _Gwaiting, _Grunnable)
			traceGoUnpark(gp, 0)
			tryWakeP = true
		}
	}
	if gp == nil && gcBlackenEnabled != 0 {
		gp = gcController.findRunnableGCWorker(_g_.m.p.ptr())
		tryWakeP = tryWakeP || gp != nil
	}
	if gp == nil {
		// Check the global runnable queue once in a while to ensure fairness.
		// Otherwise two goroutines can completely occupy the local runqueue
		// by constantly respawning each other.
    // 
   //为了保证调度的公平性，每进行61次调度就需要优先从全局运行队列中获取goroutine，
   //因为如果只调度本地队列中的g，那么全局运行队列中的goroutine将得不到运行
		if _g_.m.p.ptr().schedtick%61 == 0 && sched.runqsize > 0 {
			lock(&sched.lock)
			gp = globrunqget(_g_.m.p.ptr(), 1)
			unlock(&sched.lock)
		}
	}
	if gp == nil {
    //从与m关联的p的本地运行队列中获取goroutine
		gp, inheritTime = runqget(_g_.m.p.ptr())
		// We can see gp != nil here even if the M is spinning,
		// if checkTimers added a local goroutine via goready.
	}
	if gp == nil {
    //如果从本地运行队列和全局运行队列都没有找到需要运行的goroutine，
    //则调用findrunnable函数从其它工作线程的运行队列中偷取，如果偷取不到，则当前工作线程进入睡眠，
    //直到获取到需要运行的goroutine之后findrunnable函数才会返回。
		gp, inheritTime = findrunnable() // blocks until work is available
	}

	// 当前运行的是runtime的代码，函数调用栈使用的是g0的栈空间
  // 调用execte切换到gp的代码和栈空间去运行
	execute(gp, inheritTime)
}

```

调度 g 的选择

- 为了公平，调度器每调度 61 次的时候，都会尝试从全局队列里取出待运行的 goroutine 来运行，调用 `globrunqget`

- 调用 `runqget`，从 P 本地可运行队列先选出一个可运行的 goroutine

- 如果还没找到，就要去其他 P 里面去偷一些 goroutine 来执行，调用 `findrunnable` 函数。

- 调用用 `execute(gp,inheritTime)` 切换到选出的 goroutine 栈执行，调度器的调度次数会在这里更新，源码如下：



```go
// Schedules gp to run on the current M.
// If inheritTime is true, gp inherits the remaining time in the
// current time slice. Otherwise, it starts a new time slice.
// Never returns.
//
// Write barriers are allowed because this is called immediately after
// acquiring a P in several places.
//
//go:yeswritebarrierrec
//调度 gp 在当前 M 上运行
//如果inheritTime 为true ,gp执行当前的时间片
//否则，开启一个新的时间片
func execute(gp *g, inheritTime bool) {
  //get g0 
	_g_ := getg()

	// Assign gp.m before entering _Grunning so running Gs have an
	// M.
  //设置当前m最新的g为gp
	_g_.m.curg = gp
  //设置 gp.m 的 m 
	gp.m = _g_.m
  //设置待运行g的状态为_Grunning
	casgstatus(gp, _Grunnable, _Grunning)
	gp.waitsince = 0
	gp.preempt = false
	gp.stackguard0 = gp.stack.lo + _StackGuard
	if !inheritTime { 
		// 调度器调度次数增加 1
		_g_.m.p.ptr().schedtick++
	}

	// Check whether the profiler needs to be turned on or off.
	hz := sched.profilehz
	if _g_.m.profilehz != hz {
		setThreadCPUProfiler(hz)
	}

	if trace.enabled {
		// GoSysExit has to happen when we have a P, but before GoStart.
		// So we emit it here.
		if gp.syscallsp != 0 && gp.sysblocktraced {
			traceGoSysExit(gp.sysexitticks)
		}
		traceGoStart()
	}

  //gogo完成从g0到gp真正的切换
	gogo(&gp.sched)
}

```



> execute函数的第一个参数gp即是需要调度起来运行的goroutine，这里首先把gp的状态从_Grunnable修改为_Grunning，然后把gp和m关联起来，这样通过m就可以找到当前工作线程正在执行哪个goroutine，反之亦然。
>
> 完成gp运行前的准备工作之后，execute调用gogo函数完成从g0到gp的的切换：**CPU执行权的转让以及栈的切换**。
>
> gogo函数也是通过汇编语言编写的，这里之所以需要使用汇编，是因为goroutine的调度涉及不同执行流之间的切换，前面我们在讨论操作系统切换线程时已经看到过，执行流的切换从本质上来说就是CPU寄存器以及函数调用栈的切换，然而不管是go还是c这种高级语言都无法精确控制CPU寄存器的修改，因而高级语言在这里也就无能为力了，只能依靠汇编指令来达成目的。



  

 ```go
// func gogo(buf *gobuf)
// restore state from Gobuf; longjmp
TEXT runtime·gogo(SB), NOSPLIT, $16-8
  // BX =  &gp.sched
	MOVQ	buf+0(FP), BX		// gobuf
	// DX = gp.sched.g 
	MOVQ	gobuf_g(BX), DX
	//确认 g != nil 
	MOVQ	0(DX), CX		// make sure g != nil
	// 获取fs段基地址并放入BX寄存器
	get_tls(CX)
	 //把要运行的g的指针放入线程本地存储，这样后面的代码就可以通过线程本地存储
   // 获取到当前正在执行的goroutine的g结构体对象，从而找到与之关联的m和p
	MOVQ	DX, g(CX)
   //把CPU的SP寄存器设置为sched.sp，完成了栈的切换
	MOVQ	gobuf_sp(BX), SP	
 //下面三条同样是恢复调度上下文到CPU相关寄存器
	MOVQ	gobuf_ret(BX), AX
	MOVQ	gobuf_ctxt(BX), DX
	MOVQ	gobuf_bp(BX), BP
	//清空sched的值，因为我们已把相关值放入CPU对应的寄存器了，不再需要，这样做可以少gc的工作量
  MOVQ	$0, gobuf_sp(BX)	// clear to help garbage collector
	MOVQ	$0, gobuf_ret(BX)
	MOVQ	$0, gobuf_ctxt(BX)
	MOVQ	$0, gobuf_bp(BX)
	// 把sched.pc值放入BX寄存器
	MOVQ	gobuf_pc(BX), BX
	// JMP把BX寄存器的包含的地址值放入CPU的IP寄存器，于是，CPU跳转到该地址继续执行指令，
	JMP	BX

 ```

现在已经从g0切换到了gp这个goroutine，对于我们这个场景来说，gp还是第一次被调度起来运行，它的入口函数是runtime.main.





