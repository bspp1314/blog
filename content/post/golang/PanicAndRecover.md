---
title: "Panic and Recover"
date: 2020-12-30T21:09:52+08:00
draft: true
---

# panic and recover 

Golang 之中常见的错误处理方式返回error给调用者，但是如果出现错误导致程序无法继续进行下去，函数调用`panic` 来终止当前的groutine。当panic 结束当前的groutine，会执行defer调用链，执行完毕后再退出groutine。而recover可以中止 `panic` 造成的程序崩溃，它是一个只能在 `defer` 中发挥作用的函数，在其他作用域中调用不会发挥任何作用。



# 简单的使用

```go
func DeferPanic(i int) int  {
	defer func() {
		fmt.Println("i value is ",i)
	}()

	if i == 1  {
		panic("i not be  1 ")
	}
  
  i = i +1 
	return i
}

func main() {
	DeferPanic(1)
	DeferPanic(2)
}
```
out


```shell
$ go run panic.go
i value is  1
panic: i not be  1 

goroutine 1 [running]:
main.DeferPanic(0x1, 0x0)
        /Users/workplace/go/src/github.com/bspp1314/go-common-lib/defer/panic/panic.go:15 +0x9d
main.main()
        /Users/workplace/go/src/github.com/bspp1314/go-common-lib/defer/panic/panic.go:23 +0x2a
exit status 2


```

可以看到在程序调用panic之后退出了当前的groutine,并且在退出之前调用了defer调用链。 

```go
func DeferPanic(i int) int  {
	defer func() {
		//if err := recover();err != nil {
		//	fmt.Printf("捕获到Panic %v \n",err)
		//}

		fmt.Println("i value is ",i)
	}()

	if i == 1  {
		panic("i not be  1 ")
	}

	i = i + 1

	return i +1

}

func main() {
	go DeferPanic(1)
	DeferPanic(2)

}
```

out 

```go
func DeferPanic(i int) int  {
	defer func() {
		//if err := recover();err != nil {
		//	fmt.Printf("捕获到Panic %v \n",err)
		//}

		fmt.Println("i value is ",i)
	}()

	if i == 1  {
		panic("i not be  1 ")
	}

	i = i + 1

	return i +1

}

func main() {
	go DeferPanic(1)
	DeferPanic(2)

}
```
out 
```go
i value is  3
i value is  1
panic: i not be  1 

goroutine 6 [running]:
main.DeferPanic(0x1, 0x0)
        /Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/defer/panic/panic.go:17 +0xab
created by main.main
        /Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/defer/panic/panic.go:27 +0x3e
exit status 2

```

从上面的列子可以看到panic只处理当前的groutine 







```go
func DeferPanic(i int) int  {
	defer func() {
		if err := recover();err != nil {
			fmt.Printf("捕获到Panic %v \n",err)
		}

		fmt.Println("i value is ",i)
	}()

	if i == 1  {
		panic("i not be  1 ")
	}

	i = i + 1

	return i +1

}

func main() {
	DeferPanic(1)
	DeferPanic(2)
}
```



out 

```
go run panic.go
捕获到Panic i not be  1  
i value is  1
i value is  3

```

从上述例子可以看到recover可以捕获到panic .



# panic 的结构

```go
type _panic struct {
  //指向 defer 
	argp      unsafe.Pointer // pointer to arguments of deferred call run during panic; cannot move - known to liblink
	// panic 参数
  arg       interface{}    // argument to panic
	//指向更早的panic
  link      *_panic        // link to earlier panic
	pc        uintptr        // where to return to in runtime if this panic is bypassed
	sp        unsafe.Pointer // where to return to in runtime if this panic is bypassed
	//该panic 是否被恢复
  recovered bool           // whether this panic is over
	//前的 panic 是否被强行终止
  aborted   bool           // the panic was aborted
	goexit    bool
}
```





```go
/ The implementation of the predeclared function panic.
func gopanic(e interface{}) {
	//获取当前的 Groutine 
  gp := getg()
	......

  //创建一个panic 
  //panic可以嵌套，比如发生了panic之后运行defered函数又发生了panic，
  //最新的panic会被挂入goroutine对应的g结构体对象的_panic链表的表头
	var p _panic
	p.arg = e
	p.link = gp._panic
	gp._panic = (*_panic)(noescape(unsafe.Pointer(&p)))

	atomic.Xadd(&runningPanicDefers, 1)

	// By calculating getcallerpc/getcallersp here, we avoid scanning the
	// gopanic frame (stack scanning is slow...)
  //增加一个开放地址编码的defer 
	addOneOpenDeferFrame(gp, getcallerpc(), unsafe.Pointer(getcallersp()))

	for {
		d := gp._defer//取出_defer链表头的defered函数
    // defer 已经执行完毕
		if d == nil {
			break
		}

		// If defer was started by earlier panic or Goexit (and, since we're back here, that triggered a new panic),
		// take defer off list. An earlier panic will not continue running, but we will make sure below that an
		// earlier Goexit does continue running.
    //到这里一定发生了panic嵌套，即在defered函数中又发生了panic
		if d.started {
			if d._panic != nil {
         //取消上一次发生的panic
				d._panic.aborted = true
			}
			d._panic = nil
			if !d.openDefer {
				// For open-coded defers, we need to process the
				// defer again, in case there are any other defers
				// to call in the frame (not including the defer
				// call that caused the panic).
				d.fn = nil
				gp._defer = d.link
				freedefer(d)
				continue
			}
		}

		// Mark defer as started, but keep on list, so that traceback
		// can find and update the defer's argument frame if stack growth
		// or a garbage collection happens before reflectcall starts executing d.fn.
		d.started = true//用于判断是否发生了嵌套panic

		// Record the panic that is running the defer.
		// If there is a new panic during the deferred call, that panic
		// will find d in the list and will mark d._panic (this panic) aborted.
		d._panic = (*_panic)(noescape(unsafe.Pointer(&p)))//把panic和defer函数关联起来

		done := true
		if d.openDefer {
			done = runOpenDeferFrame(gp, d)
			if done && !d._panic.recovered {
				addOneOpenDeferFrame(gp, 0, nil)
			}
		} else {
       //在panic中记录当前panic的栈顶位置，用于recover判断
			p.argp = unsafe.Pointer(getargp(0))
      //通过reflectcall函数调用defered函数
      //如果defered函数再次发生panic而且并未被该defered函数recover，则reflectcall永远不会返回，参考例2。
      //如果defered函数并没有发生过panic或者发生了panic但该defered函数成功recover了新发生的panic，
      //则此函数会返回继续执行后面的代码。
			reflectcall(nil, unsafe.Pointer(d.fn), deferArgs(d), uint32(d.siz), uint32(d.siz))
		}
		p.argp = nil

		// reflectcall did not panic. Remove d.
		if gp._defer != d {
			throw("bad defer entry in panic")
		}
		d._panic = nil

		// trigger shrinkage to test stack copy. See stack_test.go:TestStackPanic
		//GC()

		pc := d.pc
		sp := unsafe.Pointer(d.sp) // must be pointer so it gets adjusted during stack copy
		if done {
			d.fn = nil
			gp._defer = d.link
			freedefer(d)
		}
		if p.recovered {
			gp._panic = p.link
			if gp._panic != nil && gp._panic.goexit && gp._panic.aborted {
				// A normal recover would bypass/abort the Goexit.  Instead,
				// we return to the processing loop of the Goexit.
				gp.sigcode0 = uintptr(gp._panic.sp)
				gp.sigcode1 = uintptr(gp._panic.pc)
				mcall(recovery)
				throw("bypassed recovery failed") // mcall should not return
			}
			atomic.Xadd(&runningPanicDefers, -1)

			if done {
				// Remove any remaining non-started, open-coded
				// defer entries after a recover, since the
				// corresponding defers will be executed normally
				// (inline). Any such entry will become stale once
				// we run the corresponding defers inline and exit
				// the associated stack frame.
				d := gp._defer
				var prev *_defer
				for d != nil {
					if d.openDefer {
						if d.started {
							// This defer is started but we
							// are in the middle of a
							// defer-panic-recover inside of
							// it, so don't remove it or any
							// further defer entries
							break
						}
						if prev == nil {
							gp._defer = d.link
						} else {
							prev.link = d.link
						}
						newd := d.link
						freedefer(d)
						d = newd
					} else {
						prev = d
						d = d.link
					}
				}
			}

			gp._panic = p.link
			// Aborted panics are marked but remain on the g.panic list.
			// Remove them from the list.
			for gp._panic != nil && gp._panic.aborted {
				gp._panic = gp._panic.link
			}
			if gp._panic == nil { // must be done with signal
				gp.sig = 0
			}
			// Pass information about recovering frame to recovery.
			gp.sigcode0 = uintptr(sp)
			gp.sigcode1 = pc
			mcall(recovery)
			throw("recovery failed") // mcall should not return
		}
	}

	// ran out of deferred calls - old-school panic now
	// Because it is unsafe to call arbitrary user code after freezing
	// the world, we call preprintpanics to invoke all necessary Error
	// and String methods to prepare the panic strings before startpanic.
	preprintpanics(gp._panic)

	fatalpanic(gp._panic) // should not return
	*(*int)(nil) = 0      // not reached
}

```

















# 参考 

Panic and Recover  https://golangbot.com/panic-and-recover/

Golang: 深入理解panic and recover  https://ieevee.com/tech/2017/11/23/go-panic.html

panic and recover 源码阅读  https://soyum2222.github.io/panic/

Go语言panic/recover的实现 https://zhuanlan.zhihu.com/p/72779197