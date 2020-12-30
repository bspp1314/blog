---
title: "Defer"
date: 2020-12-28T10:31:38+08:00
draft: true
---



Go语言中的Defer会在当前函数或方法返回之前执行设定的函数，常常文件的关闭，解锁资源等操作之中。


# 一些常见的操作

##  defer 的执行顺序

defer 的作用就是把关键字之后的函数执行压入一个栈中延迟执行，多个 defer 的执行顺序是后进先出 LIFO

```go
func main() {
	for i := 0; i < 5; i++ {
		defer fmt.Println(i)
	}
}
```

out

```
4
3
2
1
0
```

## defer 参数的确定

Go语言中所有的函数调用都是传值，defer也同样是传值。

```go
func add(a int, b int) int {
	fmt.Println("a + b  =  ",a+b)
	return a+b
}

func main() {
	a := 10
	b := 10

	defer add(a,add(a,b))
	fmt.Println(a + b)
}
```



```shell
a + b  =   20
20
a + b  =   30
```

defer 函数的参数 ,参数在 defer 时就已经计算完成并确定



# defer 和 Recover 

defer函数实在return之后执行的，而panic 是在return 之前在return之前执行的，所以我们可以在defer之中捕获函数抛出的 panic，因而 defer 的另一个重要用途就是执行 recover。

```go
func DeferPanic(i int) int  {
	defer func() {
		if err := recover();err != nil {
			fmt.Printf("捕获到Panic %v \n",err)
		}
	}()

	if i == 1  {
		panic("Panic err ")
	}

	return i +1

}

func main() {
	DeferPanic(1)
	DeferPanic(2)
}

```

 

```
捕获到Panic Panic err  
```



# defer 的数据结构

Defer 的源码在[runtime2](https://github.com/golang/go/blob/9b955d2d3fcff6a5bc8bce7bafdc4c634a28e95b/src/runtime/runtime2.go#L885)中如下

```go
// A _defer holds an entry on the list of deferred calls.
// If you add a field here, add code to clear it in freedefer and deferProcStack
// This struct must match the code in cmd/compile/internal/gc/reflect.go:deferstruct
// and cmd/compile/internal/gc/ssa.go:(*state).call.
// Some defers will be allocated on the stack and some on the heap.
// All defers are logically part of the stack, so write barriers to
// initialize them are not required. All defers must be manually scanned,
// and for heap defers, marked.
type _defer struct {
  //参数和返回值的大小
	siz     int32 // includes both arguments and results
	//是否执行过了
  started bool
  //是否在堆上分配
	heap    bool
	// openDefer indicates that this _defer is for a frame with open-coded
	// defers. We have only one defer record for the entire frame (which may
	// currently have 0, 1, or more defers active).
  //表示当前 `defer` 是否经过开放编码的优化
	openDefer bool
  //栈指针
	sp        uintptr  // sp at time of defer
  //调用方的程序计数器
	pc        uintptr  // pc at time of defer
  //传入的函数
	fn        *funcval // can be nil for open-coded defers
  //defer中的panic
	_panic    *_panic  // panic that is running defer
	//defer链表，函数执行流程中的defer，会通过 link这个 属性进行串联
  link      *_defer

//  在1.14中大部分的流程并没有改变，主要是在open-coded的基础上对deferreturn函数做了一定的调整；

//在open-coded模式下，仅有一个defer对象，fd、varp、framepc uintptr等字段保存了所有的defer函数信息（函数指针、参数、上下文等），在runOpenDeferFrame仅通过一个遍历就执行了所有的defer函数；


	// If openDefer is true, the fields below record values about the stack
	// frame and associated function that has the open-coded defer(s). sp
	// above will be the sp for the frame, and pc will be address of the
	// deferreturn call in the function.
	fd   unsafe.Pointer // funcdata for the function associated with the frame
	varp uintptr        // value of varp for the stack frame
	// framepc is the current pc associated with the stack frame. Together,
	// with sp above (which is the sp associated with the stack frame),
	// framepc/sp can be used as pc/sp pair to continue a stack trace via
	// gentraceback().
	framepc uintptr
}
```

defer 结构体是延迟调用链表上的一个元素，所有的结构体都会通过 `link` 字段串联成链表。



# Defer 的实现

## 在堆上分配
在 Golang 1.13 之前的版本中，所有 defer 都是在堆上分配，该机制在编译时会进行两个步骤：

- 在 `defer` 语句的位置插入 `runtime.deferproc`，当被执行时，延迟调用会被保存为一个 `_defer` 记录，并将被延迟调用的入口地址及其参数复制保存，存入 Goroutine 的调用链表中。
- 在函数返回之前的位置插入 `runtime.deferreturn`，当被执行时，会将延迟调用从 Goroutine 链表中取出并执行，多个延迟调用则以 jmpdefer 尾递归调用方式连续执行。

```go
// Create a new deferred function fn with siz bytes of arguments.
// The compiler turns a defer statement into a call to this.
//go:nosplit
func deferproc(siz int32, fn *funcval) { // arguments of fn follow fn
  //获取当前的Groutine 
	gp := getg()
	if gp.m.curg != gp {
		// go code on the system stack can't defer
		throw("defer on system stack")
	}

  // 栈指针
	sp := getcallersp()
  //参数指针
	argp := uintptr(unsafe.Pointer(&fn)) + unsafe.Sizeof(fn)
  //计数器
	callerpc := getcallerpc()

  //创建一个新的defer 
	d := newdefer(siz)
	if d._panic != nil {
		throw("deferproc: d.panic != nil after newdefer")
	}
  //将新的链表插入表头
	d.link = gp._defer
	gp._defer = d
	d.fn = fn
	d.pc = callerpc
	d.sp = sp
	switch siz {
	case 0:
		// Do nothing.
	case sys.PtrSize:
		*(*uintptr)(deferArgs(d)) = *(*uintptr)(unsafe.Pointer(argp))
	default:
		memmove(deferArgs(d), unsafe.Pointer(argp), uintptr(siz))
	}

	return0()
}
```



```go
func deferreturn(arg0 uintptr) {
	gp := getg()
	d := gp._defer
  //判断defer 调用链是否为空
	if d == nil {
		return
	}
	sp := getcallersp()
	if d.sp != sp {
		return
	}
  ..... 
  
	switch d.siz {
	case 0:
		// Do nothing.
	case sys.PtrSize:
		*(*uintptr)(unsafe.Pointer(&arg0)) = *(*uintptr)(deferArgs(d))
	default:
		memmove(unsafe.Pointer(&arg0), deferArgs(d), uintptr(d.siz))
	}
	fn := d.fn
	d.fn = nil
	gp._defer = d.link
	freedefer(d)
	// If the defer function pointer is nil, force the seg fault to happen
	// here rather than in jmpdefer. gentraceback() throws an error if it is
	// called with a callback on an LR architecture and jmpdefer is on the
	// stack, because the stack trace can be incorrect in that case - see
	// issue #8153).
	_ = fn.fn
  //跳转到 defer 所在的代码段并在执行结束之后跳转回 runtime.deferreturn
	jmpdefer(fn, uintptr(unsafe.Pointer(&arg0)))
}

```



```go
TEXT runtime·jmpdefer(SB), NOSPLIT, $0-8
	MOVL	fv+0(FP), DX	// fn
	MOVL	argp+4(FP), BX	// caller sp
	LEAL	-4(BX), SP	// caller sp after CALL
#ifdef GOBUILDMODE_shared
	SUBL	$16, (SP)	// return to CALL again
#else
	SUBL	$5, (SP)	// return to CALL again
#endif
	MOVL	0(DX), BX
	JMP	BX	// but first run the deferred function
```

# 在栈上分配

Go 1.13 版本新加入 `deferprocStack` 实现了在栈上分配的形式来取代 `deferproc`

验证一下

```go
func Add()  {
	defer func() {

	}()

}
func main() {
	Add()
}

```
使用以下命令来查看其编译后的代码（-N 禁用编译器优化）

```
go tool compile -S  -l -N main.go 
```

```
"".Add STEXT size=109 args=0x0 locals=0x60                                                                                                                                          
  2     0x0000 00000 (main.go:15)   TEXT    "".Add(SB), ABIInternal, $96-0
  3     0x0000 00000 (main.go:15)   MOVQ    (TLS), CX
  4     0x0009 00009 (main.go:15)   CMPQ    SP, 16(CX)
  5     0x000d 00013 (main.go:15)   PCDATA  $0, $-2
  6     0x000d 00013 (main.go:15)   JLS 102
  7     0x000f 00015 (main.go:15)   PCDATA  $0, $-1
  8     0x000f 00015 (main.go:15)   SUBQ    $96, SP
  9     0x0013 00019 (main.go:15)   MOVQ    BP, 88(SP)
 10     0x0018 00024 (main.go:15)   LEAQ    88(SP), BP
 11     0x001d 00029 (main.go:15)   FUNCDATA    $0, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
 12     0x001d 00029 (main.go:15)   FUNCDATA    $1, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
 13     0x001d 00029 (main.go:16)   MOVL    $0, ""..autotmp_1+8(SP)
 14     0x0025 00037 (main.go:16)   LEAQ    "".Add.func1·f(SB), AX
 15     0x002c 00044 (main.go:16)   MOVQ    AX, ""..autotmp_1+32(SP)
 16     0x0031 00049 (main.go:16)   LEAQ    ""..autotmp_1+8(SP), AX
 17     0x0036 00054 (main.go:16)   MOVQ    AX, (SP)
 18     0x003a 00058 (main.go:16)   PCDATA  $1, $0
 19     0x003a 00058 (main.go:16)   CALL    runtime.deferprocStack(SB)
 20     0x003f 00063 (main.go:16)   NOP
 21     0x0040 00064 (main.go:16)   TESTL   AX, AX
 22     0x0042 00066 (main.go:16)   JNE 86
 23     0x0044 00068 (main.go:16)   JMP 70
 24     0x0046 00070 (main.go:20)   XCHGL   AX, AX
 25     0x0047 00071 (main.go:20)   CALL    runtime.deferreturn(SB)

```



使用deferprocStack栈上分配在函数返回后 `_defer` 便得到释放，省去了内存分配时产生的性能开销。

```go
//go:nosplit
func deferprocStack(d *_defer) {
	gp := getg()
	if gp.m.curg != gp {
		// go code on the system stack can't defer
		throw("defer on system stack")
	}
	// siz and fn are already set.
	// The other fields are junk on entry to deferprocStack and
	// are initialized here.
	d.started = false
	d.heap = false
	d.openDefer = false
	d.sp = getcallersp()
	d.pc = getcallerpc()
	d.framepc = 0
	d.varp = 0
	// The lines below implement:
	//   d.panic = nil
	//   d.fd = nil
	//   d.link = gp._defer
	//   gp._defer = d
	// But without write barriers. The first three are writes to
	// the stack so they don't need a write barrier, and furthermore
	// are to uninitialized memory, so they must not use a write barrier.
	// The fourth write does not require a write barrier because we
	// explicitly mark all the defer structures, so we don't need to
	// keep track of pointers to them with a write barrier.
	*(*uintptr)(unsafe.Pointer(&d._panic)) = 0
	*(*uintptr)(unsafe.Pointer(&d.fd)) = 0
	*(*uintptr)(unsafe.Pointer(&d.link)) = uintptr(unsafe.Pointer(gp._defer))
	*(*uintptr)(unsafe.Pointer(&gp._defer)) = uintptr(unsafe.Pointer(d))

	return0()
	// No code can go here - the C return register has
	// been set and must not be clobbered.
}
```



## 开放编码



> Version 1.14 of Go continues to include development coding (open coded), which eliminates the need for deferproc or deferprocStack operations at run time before the deferred call is inserted directly into the function return, and deferreturn at run time does not make tail recursive calls, but simply iterates through all deferred function executions in a loop.
>



Golang 1.14版本引入了开放编码，该机制会将延迟调用直接插入函数返回之前，省去了运行时的 `deferproc` 或 `deferprocStack` 操作，在运行时的 `deferreturn` 也不会进行尾递归调用，而是直接在一个循环中遍历所有延迟函数执行。



这种机制使得 `defer` 的**开销几乎可以忽略**，唯一的运行时成本就是存储参与延迟调用的相关信息，不过使用此机制需要一些条件：

- 函数的 `defer` 数量少于或者等于 8 个；
- 函数的 `defer` 关键字不能在循环中执行；

- 函数的 `return` 语句与 `defer` 语句的乘积小于或者等于 15 个；
- 没有禁用编译器优化，即没有设置 `-gcflags "-N"`；

延迟比特

> The mechanism also introduces an element, the delay bit (defer bit), which is used at run time to record whether each defer was executed (especially defer in the conditional judgment branch), making it easy to determine which functions were executed when the last delayed call was made.
>
> The principle of delay bit:
>
> For each defer in the same function, it will be allocated 1 bit. If it is executed, it will be set to 1; otherwise, it will be set to 0. When it needs to judge the delay call before the return of the function, it will use the mask to judge the bit of each position.
>
> To be lightweight, the delay bit is officially limited to 1 byte, or 8 bits, which is why you can't go beyond 8 defer. If you do, you will still choose stack allocation, but obviously in most cases you won't go beyond 8.



```go

deferBits = 0 //  Delay the initial value of the bit  00000000

deferBits |= 1<<0 //  The first 1 a  defer , is set to  00000001
_f1 = f1 //  Delay function 
_a1 = a1 //  The parameters of the delay function 
if cond {
  //  If the first 2 a  defer  Is executed, set to  00000011 Otherwise, it will still be  00000001
  deferBits |= 1<<1
  _f2 = f2
  _a2 = a2
}
...
exit:
//  Before the function returns, the delay bit is checked in reverse order, and the function is evaluated by the mask bit by bit to determine whether the function is called 

//  if  deferBits  for  00000011 ,  00000011 & 00000010 != 0 , so call  f2
//  Otherwise,  00000001 & 00000010 == 0 , don't call  f2
if deferBits & 1<<1 != 0 {
  deferBits &^= 1<<1 //  The shift prepares for the next judgment 
  _f2(_a2)
}
//  Similarly, since  00000001 & 00000001 != 0 , the call  f1
if deferBits && 1<<0 != 0 {
  deferBits &^= 1<<0
  _f1(_a1)
}
```






# 参考

探究 Go 语言 defer 语句的三种机制  https://zhuanlan.zhihu.com/p/110105594

理解 Go defer https://sanyuesha.com/2017/07/23/go-defer/

Defer https://aavon.github.io/doc/pages/defer.html

defer https://draveness.me/golang/docs/part2-foundation/ch05-keyword/golang-defer/

Three mechanisms of Go language defer statements  https://ofstack.com/Golang/28467/three-mechanisms-of-go-language-defer-statements.html

