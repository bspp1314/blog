---
title: "Gin的学习笔记3 Context分析"
date: 2020-10-26T16:50:45+08:00
draft: false
tag: ["http","gin"]
categories: ["golang","gin"]
---

`Context`是框架中非常重要的一点，它允许我们在中间件间共享变量，管理整个流程，验证请求的json以及提供一个json的响应体. 通常情况下我们的业务逻辑处理也是在整个Context引用对象中进行实现的.



# 框架中的Context结构体已经生成

```go
// Context is the most important part of gin. It allows us to pass variables between middleware,
// manage the flow, validate the JSON of a request and render a JSON response for example.
type Context struct {
  //一个包含size,status和ResponseWriter的结构体
	writermem responseWriter
	// http的请求体(指向原生的http.Request指针)
  Request   *http.Request
  // ResonseWriter接口
	Writer    ResponseWriter

  // 路由遍量参数
	Params   Params
  // 请求处理链 
	handlers HandlersChain
	index    int8
  //http请求的全路径地址
	fullPath string

  //gin框架的Engine结构体指针
	engine *Engine

	// Keys 读写锁
	mu sync.RWMutex
  // 每个请求的context中的唯一键值对
	Keys map[string]interface{}

	// Errors is a list of errors attached to all the handlers/middlewares who used this context.
  // 绑定到所有使用该context的handler/middlewares的错误列表
	Errors errorMsgs

	// Accepted defines a list of manually accepted formats for content negotiation.
  // 定义了允许的格式被用于内容协商(content)
	Accepted []string

	// queryCache use url.ParseQuery cached the param query result from c.Request.URL.Query()
  // queryCache 使用url.ParseQuery来缓存参数查询结果(c.Request.URL.Query())
	queryCache url.Values

	// formCache use url.ParseQuery cached PostForm contains the parsed form data from POST, PATCH,
	// or PUT body parameters.
  // formCache 使用url.ParseQuery来缓存PostForm包含的表单数据(来自POST,PATCH,PUT请求体参数)
	formCache url.Values

	// SameSite allows a server to define a cookie attribute making it impossible for
	// the browser to send this cookie along with cross-site requests.
  // 通过cookie 
	sameSite http.SameSite
}

```

查看源码发现其实`gin.Context`在整个框架处理的地方只有下面这段

```go
// ServeHTTP conforms to the http.Handler interface.
func (engine *Engine) ServeHTTP(w http.ResponseWriter, req *http.Request) {
  // 从资源池里获取一个Context
	c := engine.pool.Get().(*Context)
	// 初始化 writemem 
  c.writermem.reset(w)
  // 设置req 
	c.Request = req
  // 初始化 Context 
	c.reset()
 // 处理HTTP 请求
	engine.handleHTTPRequest(c)
	// 释放Context 
	engine.pool.Put(c)
}

func (w *responseWriter) reset(writer http.ResponseWriter) {
	w.ResponseWriter = writer
	w.size = noWritten
	w.status = defaultStatus
}

func (c *Context) reset() {
	c.Writer = &c.writermem
	c.Params = c.Params[0:0]
	c.handlers = nil
	c.index = -1

	c.fullPath = ""
	c.Keys = nil
	c.Errors = c.Errors[0:0]
	c.Accepted = nil
	c.queryCache = nil
	c.formCache = nil
}
```

# gin.Context 一些重要部分分析

# Keys 

这个模块比较简单, 就是从gin.Context中Set Key-Value, 以及各种个样的Get方法, 如GetBool, GetString等

实现这些功能也很简单, 其实就是一个map

```go
// Keys 读写锁
mu sync.RWMutex
// 每个请求的context中的唯一键值对
Keys map[string]interface{}


// Set is used to store a new key/value pair exclusively for this context.
// It also lazy initializes  c.Keys if it was not used previously.
func (c *Context) Set(key string, value interface{}) {
	c.mu.Lock()
	if c.Keys == nil {
		c.Keys = make(map[string]interface{})
	}

	c.Keys[key] = value
	c.mu.Unlock()
}

// Get returns the value for the given key, ie: (value, true).
// If the value does not exists it returns (nil, false)
func (c *Context) Get(key string) (value interface{}, exists bool) {
	c.mu.RLock()
	value, exists = c.Keys[key]
	c.mu.RUnlock()
	return
}
```



# Parameters in path 

这个方法实现也很简单, 就是在tree.go里面根据路由相关规则解析出来然后赋值给gin.Context的Params.

```go
/ Params is a Param-slice, as returned by the router.
// The slice is ordered, the first URL parameter is also the first slice value.
// It is therefore safe to read values by the index.
type Params []Param

// Get returns the value of the first Param which key matches the given name.
// If no matching Param is found, an empty string is returned.
func (ps Params) Get(name string) (string, bool) {
	for _, entry := range ps {
		if entry.Key == name {
			return entry.Value, true
		}
	}
	return "", false
}

// ByName returns the value of the first Param which key matches the given name.
// If no matching Param is found, an empty string is returned.
func (ps Params) ByName(name string) (va string) {
	va, _ = ps.Get(name)
	return
}

func (engine *Engine) handleHTTPRequest(c *Context) {
	httpMethod := c.Request.Method
	rPath := c.Request.URL.Path
	unescape := false
	if engine.UseRawPath && len(c.Request.URL.RawPath) > 0 {
		rPath = c.Request.URL.RawPath
		unescape = engine.UnescapePathValues
	}

	if engine.RemoveExtraSlash {
		rPath = cleanPath(rPath)
	}

	// Find root of the tree for the given HTTP method
	t := engine.trees
	for i, tl := 0, len(t); i < tl; i++ {
		if t[i].method != httpMethod {
			continue
		}
		root := t[i].root
		// Find route in tree
    // 看这个
		value := root.getValue(rPath, c.Params, unescape)
		if value.handlers != nil {
			c.handlers = value.handlers
			c.Params = value.params
			c.fullPath = value.fullPath
			c.Next()
			c.writermem.WriteHeaderNow()
			return
		}
		if httpMethod != "CONNECT" && rPath != "/" {
			if value.tsr && engine.RedirectTrailingSlash {
				redirectTrailingSlash(c)
				return
			}
			if engine.RedirectFixedPath && redirectFixedPath(c, root, engine.RedirectFixedPath) {
				return
			}
		}
		break
	}

	if engine.HandleMethodNotAllowed {
		for _, tree := range engine.trees {
			if tree.method == httpMethod {
				continue
			}
			if value := tree.root.getValue(rPath, nil, unescape); value.handlers != nil {
				c.handlers = engine.allNoMethod
				serveError(c, http.StatusMethodNotAllowed, default405Body)
				return
			}
		}
	}
	c.handlers = engine.allNoRoute
	serveError(c, http.StatusNotFound, default404Body)
}

```



## Bind 

要将请求体绑定到结构体中，使用模型绑定。 Gin 目前支持 JSON、XML、YAML 和标准表单值的绑定（foo=bar＆boo=baz）。

```go
func (c *Context) Bind(obj interface{}) error {
	b := binding.Default(c.Request.Method, c.ContentType())
	return c.MustBindWith(obj, b)
}

func (c *Context) MustBindWith(obj interface{}, b binding.Binding) error {
	if err := c.ShouldBindWith(obj, b); err != nil {
		c.AbortWithError(http.StatusBadRequest, err).SetType(ErrorTypeBind) // nolint: errcheck
		return err
	}
	return nil
}

// Default returns the appropriate Binding instance based on the HTTP method
// and the content type.
func Default(method, contentType string) Binding {
	if method == http.MethodGet {
		return Form
	}

	switch contentType {
	case MIMEJSON:
		return JSON
	case MIMEXML, MIMEXML2:
		return XML
	case MIMEPROTOBUF:
		return ProtoBuf
	case MIMEMSGPACK, MIMEMSGPACK2:
		return MsgPack
	case MIMEYAML:
		return YAML
	case MIMEMultipartPOSTForm:
		return FormMultipart
	default: // case MIMEPOSTForm:
		return Form
	}
}
```

## Cookie和Session 

提供对session, cookie的支持 

## Render 

做api常用到的其实就是gin封装的各种render. 目前支持的有:

- func (c *Context) JSON(code int, obj interface{})
- func (c *Context) Protobuf(code int, obj interface{})
- func (c *Context) YAML(code int, obj interface{}) ...







# 参考

深入Gin框架内幕(二) https://juejin.im/post/6844904046336147470

gin源码阅读之三 – gin牛逼的contexthttps://www.haohongfan.com/2019/02/gin

Gin框架源码解析 https://www.cnblogs.com/yjf512/p/9670990.html





