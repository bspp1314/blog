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



















# 参考 

Panic and Recover  https://golangbot.com/panic-and-recover/

Golang: 深入理解panic and recover  https://ieevee.com/tech/2017/11/23/go-panic.html