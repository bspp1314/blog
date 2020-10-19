---
title: "Gin的学习笔记2 中间件的使用"
date: 2020-10-19T10:41:16+08:00
draft: false
---

# Gin中间件的作用

- Web请求到到达我们定义的HTTP请求处理方法之前，拦截请求并进行相应处理(比如：权限验证，数据过滤等)，这个可以类比为`前置拦截器`或`前置过滤器`，

- 在我们处理完成请求并响应客户端时，拦截响应并进行相应的处理(比如：添加统一响应部头或数据格式等)，这可以类型为`后置拦截器`或`后置过滤器`。

  

# 简单的使用

我们可以看一个简单的小例子，我们自定义两个插件，一个用来打印特定日志，一个用来打印一个接口的请求耗时。

```go
func HelloAction(c *gin.Context) {
	name := c.Query("name")
	time.Sleep(time.Second)
	c.JSON(200, gin.H{
		"message": fmt.Sprintf("hello %s ", name),
	})
}

func Logger() gin.HandlerFunc  {
	return func(context *gin.Context) {
		log.Println("Request  Log  ....... ")
		context.Next()
		log.Println("Response Log ....... ")
	}
}

func CostTime() gin.HandlerFunc  {
	return func(c *gin.Context) {
		log.Println("Start ....")
		t := time.Now().UnixNano()
		c.Next()
		log.Println("Cost Time",time.Now().UnixNano()-t)
	}

}


func main() {
	r := gin.Default()
	r.Use(CostTime(),Logger())

	r.GET("/hello", HelloAction)
	r.Run() // listen and serve on 0.0.0.0:8080}
}
```

通过curl 请求

```shell
curl   http://0.0.0.0:8080/hello 
{"message":"hello  "}
```

日志输出

```shell
2020/10/19 22:42:33 Start ....
2020/10/19 22:42:33 Request  Log  ....... 
2020/10/19 22:42:34 Response Log ....... 
2020/10/19 22:42:34 Cost Time 1001804
[GIN] 2020/10/19 - 22:42:34 | 200 |  1.001994446s |       127.0.0.1 | GET      "/hello"
```



# 源码分析

我们首先看一下中间在gin里面的定义，实际上就是一个带Context的参数的方法类型

```go
// HandlerFunc defines the handler used by gin middleware as return value.
type HandlerFunc func(*Context)

// HandlersChain defines a HandlerFunc array.
type HandlersChain []HandlerFunc

// Last returns the last handler in the chain. ie. the last handler is the main one.
func (c HandlersChain) Last() HandlerFunc {
	if length := len(c); length > 0 {
		return c[length-1]
	}
	return nil
}
```

通过Engine来添加中间件

```go
func (engine *Engine) Use(middleware ...HandlerFunc) IRoutes {
	engine.RouterGroup.Use(middleware...) //主要看这个函数 ...
	engine.rebuild404Handlers()
	engine.rebuild405Handlers()
	return engine
}

func (group *RouterGroup) Use(middleware ...HandlerFunc) IRoutes {
	group.Handlers = append(group.Handlers, middleware...) // 主要看这个操作
	return group.returnObj() //
}
```

Engine.RouterGroup.Hanlers是一个HandlersChain

```go
// RouterGroup is used internally to configure router, a RouterGroup is associated with
// a prefix and an array of handlers (middleware).
type RouterGroup struct {
	Handlers HandlersChain 
	basePath string
	engine   *Engine
	root     bool
}
```

设置完中间件，我们来看中间是怎么和实际的Action关联起来，比如我们上面代码中的 

```go
	r.GET("/hello", HelloAction)
```



```go
func (group *RouterGroup) GET(relativePath string, handlers ...HandlerFunc) IRoutes {
	return group.handle(http.MethodGet, relativePath, handlers)
}

func (group *RouterGroup) handle(httpMethod, relativePath string, handlers HandlersChain) IRoutes {
	absolutePath := group.calculateAbsolutePath(relativePath)
	handlers = group.combineHandlers(handlers) //看这个方法，将我们自己的处理业务的Action和中间合并
	group.engine.addRoute(httpMethod, absolutePath, handlers) // 添加到路由表，这部分我们先不关心
	return group.returnObj()
}

func (group *RouterGroup) combineHandlers(handlers HandlersChain) HandlersChain {
	finalSize := len(group.Handlers) + len(handlers)
	if finalSize >= int(abortIndex) {
		panic("too many handlers")
	}
	mergedHandlers := make(HandlersChain, finalSize)
	copy(mergedHandlers, group.Handlers)
	copy(mergedHandlers[len(group.Handlers):], handlers)
	return mergedHandlers
}
```

接下来我们需要看这些中间件是怎么调用的。

当http一个请求过来之后,会调用engine.ServerHTTP()，至于为何会调用ServeHTTP如果有疑惑，可以去看net.HTTP里面的源码

```go
// ServeHTTP conforms to the http.Handler interface.
func (engine *Engine) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	//生成一个Context
  c := engine.pool.Get().(*Context)  
	c.writermem.reset(w)
	c.Request = req
	c.reset()

	engine.handleHTTPRequest(c)  //处理请求

  //释放Context
	engine.pool.Put(c)
}

func (engine *Engine) handleHTTPRequest(c *Context) {
	//... 这些代码我们暂时不关心
	// Find root of the tree for the given HTTP method
	t := engine.trees
	for i, tl := 0, len(t); i < tl; i++ {
		if t[i].method != httpMethod {
			continue
		}
		root := t[i].root
		// Find route in tree
		value := root.getValue(rPath, c.Params, unescape)
		if value.handlers != nil {
			c.handlers = value.handlers //获取请求的hanlers 
			c.Params = value.params      //请求的参数
			c.fullPath = value.fullPath  //请求的fullPath 
			c.Next() //注意看这个函数调用，这是一个最重要的函数
			c.writermem.WriteHeaderNow()
			return
		}
			//... 这些代码我们暂时不关心
	}

	//... 这些代码我们暂时不关心
}
```

handleHTTPRequest最重要的代码最重要的函数调用就是c.Next()，我们可以来看一下它的实现

```go
func (c *Context) Next() {
	c.index++
	for c.index < int8(len(c.handlers)) {
    c.handlers[c.index](c)    //调用中间将，如果c.hanlers[c.index](c)存在c.Next(),就有有递归调用c.Next() 
		c.index++
	}
}
```







# 参考

中间件 https://chai2010.cn/advanced-go-programming-book/ch5-web/ch5-03-middleware.html

gin源码阅读之二 – 揭开gin的神秘面纱 https://www.haohongfan.com/2019/02/gin%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%E4%B9%8B%E4%BA%8C-%E6%8F%AD%E5%BC%80gin%E7%9A%84%E7%A5%9E%E7%A7%98%E9%9D%A2%E7%BA%B1/