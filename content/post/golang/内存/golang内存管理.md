---
title: "Golang内存管理"
date: 2021-02-25T14:18:28+08:00
draft: true
---

Go 的内存分配器基于 Thread-Cache Malloc ，tcmalloc为每一个线程实现了一个本地cache,区分了小对象（小于 32kb）和大对象分配两种分配类型，其管理的内存单元称为 span。不过由于Golang 本身并没有显示的内存申请和释放, Go 的内存分配器与 tcmalloc 存在一定差异。

# 逃逸分析

在官网 (golang.org) FAQ 上有一个关于变量分配的问题如下：

How do I know whether a variable is allocated on the heap or the stack?

> From a correctness standpoint, you don’t need to know. Each variable in Go exists as long as there are references to it. The storage location chosen by the implementation is irrelevant to the semantics of the language.
>
> The storage location does have an effect on writing efficient programs. When possible, the Go compilers will allocate variables that are local to a function in that function’s stack frame. However, if the compiler cannot prove that the variable is not referenced after the function returns, then the compiler must allocate the variable on the garbage-collected heap to avoid dangling pointer errors. Also, if a local variable is very large, it might make more sense to store it on the heap rather than the stack.
>
> In the current compilers, if a variable has its address taken, that variable is a candidate for allocation on the heap. However, a basic *escape analysis* recognizes some cases when such variables will not live past the return from the function and can reside on the stack.

从上面我们可以看到出现两种情况下 Golang的内存会被分配到堆上

- compiler cannot prove that the variable is not referenced after the function returns
- local variable is very large, it might make more sense to store it on the heap rather than the stack.



我们可以通过以下代码来验证一下

```go
type smallObj struct {
	arr [1 << 10]byte
}

type largeObj struct {
	arr [1 << 26]byte
}

func f1() int {
	x := new(int)
	*x = 1
	return *x
}

func f2() *int {
	y := 2
	return &y
}

func f3() {
	large := largeObj{}
	_ = large
}

func f4() {
	small := smallObj{}
	_ = small
}

func main() {
	f1()
	f2()
	f3()
	f4()
}
```


```shell
 go build -gcflags "-N -l -m" -ldflags=-compressdwarf=false  main.go
# command-line-arguments
./main.go:12:10: new(int) does not escape
./main.go:18:2: moved to heap: y
./main.go:23:2: moved to heap: large
```

可以看到 f2 中 y 的指针被返回，进而发生了逃逸；f3 中 large 无法被一个执行栈装下，即便没有返回，也会直接在堆上分配；我们可以再看一下其汇编指令
```go
"".f2 STEXT size=103 args=0x8 locals=0x20
    0x0000 00000 (main.go:17)   TEXT    "".f2(SB), ABIInternal, $32-8
		.....
    0x0031 00049 (main.go:18)   PCDATA  $1, $0
    0x0031 00049 (main.go:18)   CALL    runtime.newobject(SB)
		....
    0x005a 00090 (main.go:19)   RET 
```
```go
"".f3 STEXT size=82 args=0x0 locals=0x20
		0x0000 00000 (main.go:22)   TEXT    "".f3(SB), ABIInternal, $32-0
    0x0000 00000 (main.go:22)   MOVQ    (TLS), CX
    0x0009 00009 (main.go:22)   CMPQ    SP, 16(CX)
		.....
    0x0028 00040 (main.go:23)   CALL    runtime.newobject(SB)
````

可以发现，对于产生在 Go 堆上分配对象的情况，均调用了运行时的 `runtime.newobject` 方法。 所以 `runtime.newobject` 就是内存分配的入口了。



# 主要的结构

Golang的内存分配器主要包含了一下几个核心部分

- mheap  在页大小为8K的粒度进行管理
- mspan 是 mheap 上管理的一连串的页

## heapArena 

Golang

```go
const (
	pageSize = 8192 // 8K
	heapArenaBytes =  67108864  // 64M 
	heapArenaBitmapBytes = heapArenaBytes / 32       //2097152 2M 
	pagesPerArena        = heapArenaBytes / pageSize  // 8192 K 
)

type heapArena struct {
	bitmap       [heapArenaBitmapBytes]byte
	spans        [pagesPerArena]*mspan      
	pageInUse    [pagesPerArena / 8]uint8
	pageMarks    [pagesPerArena / 8]uint8
	pageSpecials [pagesPerArena / 8]uint8
	checkmarks   *checkmarksMap
	zeroedBase   uintptr
} 
```

- bitmap 一个2MB个byte数组来标记这个heap area 64M 内存的使用情况，bitmap位图主要为GC标记数组，用2bits标记8(PtrSize) 个byte的使用情况。之所以用2个bits，一是标记对应地址中是否存在对象，另外是标记此对象是否被gc标记过。一个功能一个bit位，所以， heap bitmaps用两个bit位. 
- spans：是一个8192（pagesPerArena）大小的指针数组，每个mspan是8KB；
- pageInUse：是一个位图，使用1024 * 8 bit来标记 8192个页(8192*8KB = 64MB)中哪些页正在使用中；
- pageMarks：标记页，与GC相关；

## mspan 

 [`runtime.mspan`](https://draveness.me/golang/tree/runtime.mspan)是Go语言内存管理的基本单元，该结构体中包含 `next` 和 `prev` 两个字段，它们分别指向了前一个和后一个 [`runtime.mspan`](https://draveness.me/golang/tree/runtime.mspan)



```

```



# 参考





Golang 内存管理 http://legendtkl.com/2017/04/02/golang-alloc/

TCMalloc : Thread-Caching Malloc  http://goog-perftools.sourceforge.net/doc/tcmalloc.html

第 7 章 内存分配 https://golang.design/under-the-hood/zh-cn/part2runtime/ch07alloc/

tcmalloc 介绍 http://legendtkl.com/2015/12/11/go-memory/

