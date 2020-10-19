---

title: "Gin的学习笔记1-简单的使用"
date: 2020-10-09T18:49:19+08:00
draft: false
---

# gin 是什么

> Gin is a web framework written in Go (Golang). It features a martini-like API with much better performance, up to 40 times faster thanks to httprouter



# 简单的使用

```go
func main() {
	r := gin.Default()

	r.GET("/hello", HelloAction)
	r.Run() // listen and serve on 0.0.0.0:8080}
}


func HelloAction(c *gin.Context)  {
	name := c.Query("name")
	c.JSON(200, gin.H{
		"message": fmt.Sprintf("hello %s ",name),
	})
}
```

然后我们运行它,用curl 命名访问该服务器

```shell
curl -X GET 'http://0.0.0.0:8080/hello?name=bspp'
{"message":"hello bspp "}
```



# HTTP Method 

最开始的HTTP 0.9版本只有一个`GET`方法，也就是我们在浏览器中直接输入网址回车请求的方法，这是一个幂等方法，用于获取服务器上的资源。

在HTTP 1.0的时候又增加了`HEAD`和`POST`方法，其中常用的就是`POST`方法，一般用于我们给服务端提交一个资源，导致服务器的资源发生变化。

在HTTP1.1版本，也就是HTTP 1系列的最后一个版本中，也是我们当下比较常用的HTTP版本，增加了更多的HTTP 方法。比如`OPTIONS`, `PUT`, `DELETE`, `TRACE`和`CONNECT`，这样在HTTP 1.1 版本中，HTTP的方法达到了8个。



具体每个方法用处可以参考 https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Methods



## Gin RESTful API 实现

[RESTful API](http://en.wikipedia.org/wiki/Representational_state_transfer)是目前比较成熟的一套互联网应用程序的API设计理论。如果想了解更多关于RESTfule API，可以参考 http://www.ruanyifeng.com/blog/2014/05/restful_api.html，这里就不多说了。我们直接看一个例子

```go
func main() {
	r := gin.Default()

	r.GET("/users",)
	r.GET("/user/:id", UserInfo)


	r.Run()

}

type User struct {
	ID       string
	UserName string
}

var UsersMap = map[string]*User{
	"1":&User{"1","user1"},
	"2":&User{"2","user2"},
}

func Users(c *gin.Context)   {
	c.JSON(200,&UsersMap)
}

func UserInfo(c *gin.Context) {
	ID := c.Param("id")
	c.JSON(200, UsersMap[ID])
}

```



请求全部的users

```shell
 curl -X GET 'http://0.0.0.0:8080/users'         
{"1":{"ID":"1","UserName":"user1"},"2":{"ID":"2","UserName":"user2"}}
```



请假 user 1 

```go
curl -X GET 'http://0.0.0.0:8080/users/1'
{"ID":"1","UserName":"user1"}
```





# Url 参数

web提供的服务通常是client和server的交互。其中客户端向服务器发送请求，除了路由参数，其他的参数无非两种，URL 参数和报文体body参数。

URL 参数通过 DefaultQuery 或 Query 方法获取。

对于参数的处理，经常会出现参数不存在的情况，对于是否提供默认值，gin也考虑了，并且给出了一个优雅的方案，使用c.DefaultQuery方法读取参数，其中当参数不存在的时候，提供一个默认值。使用Query方法读取正常参数，当参数不存在的时候，返回空字串。

```go
func main() {
	r := gin.Default()

	r.GET("/users/info", UserInfoAction)


	r.Run()

}

type User struct {
	ID       string
	UserName string
}

var UsersMap = map[string]*User{
	"1":&User{"1","user1"},
	"2":&User{"2","user2"},
}

func UsersAction(c *gin.Context)   {
	c.JSON(200,&UsersMap)
}

func UserInfoAction(c *gin.Context) {
	userId := c.Query("user_id")
	c.JSON(200, UsersMap[userId])
}
```



```
curl -X GET 'http://0.0.0.0:8080/users/info?user_id=1'
{"ID":"1","UserName":"user1"}

```



以上两个获取查询参数值实际调用的都是`GetQuery`，这也是`gin.Context`的一个方法，它和`Query`唯一不同的是，它返回两个值，可以告诉我们要获取的`key`是否存在。

```go
//gin 框架里的源码
func (c *Context) GetQuery(key string) (string, bool) {
    if values, ok := c.GetQueryArray(key); ok {
        return values[0], ok
    }
    return "", false
}


func (c *Context) GetQueryArray(key string) ([]string, bool) {
    c.getQueryCache() //缓存所有的键值对
    if values, ok := c.queryCache[key]; ok && len(values) > 0 {
        return values, true
    }
    return []string{}, false
}

func (c *Context) getQueryCache() {
    if c.queryCache == nil {
        c.queryCache = c.Request.URL.Query()
    }
}

// go源码里的代码 net/http.go 
func (u *URL) Query() Values {
	v, _ := ParseQuery(u.RawQuery)
	return v
}
```

可以看到实际上最终在都会去调用分解Url参数的函数ParseQuery 来获取参数。当然gin里面还有其他的读取参数函数，比如QueryArray和QueryMap等，不过这些在个人的开发过程中不常用，所有这里就不写出来了，有兴趣的可以去看源码。



# Gin报文体body参数

HTTP 协议是以 ASCII 码传输，建立在 TCP/IP 协议之上的应用层规范。规范把 HTTP 请求分为三个部分：请求行、请求头、消息主体。类似于下面这样：’

```html
<method> <request-URL> <version>
<headers>

<entity-body>
```

协议规定 POST 提交的数据必须放在消息主体（entity-body）中，但协议并没有规定数据必须使用什么编码方式。实际上，开发者完全可以自己决定消息主体的格式，只要最后发送的 HTTP 请求满足上面的格式就可以。一般服务端语言以及它们的 framework，都内置了自动解析常见数据格式的功能。服务端通常是根据请求头（headers）中的 Content-Type 字段来获知请求中的消息主体是用何种方式编码，再对主体进行解析。所以说到 POST 提交数据方案，包含了 Content-Type 和消息主体编码方式两部分。常见的Content-Type 有以下4 中



| Content-Type                      | 说明                                                         |
| --------------------------------- | ------------------------------------------------------------ |
| application/x-www-form-urlencoded | 和Url参数的模式一样。如果不设置 `enctype` 属性，那么最终就会以 application/x-www-form-urlencoded 方式提交数据 |
| multipart/form-data               | 用于上传文件时使用                                           |
| application/json                  | Json                                                         |
| text/xml                          | xml                                                          |



##Gin 表单处理

我们直接来看一个小例子

```go
func main() {
	r := gin.Default()

	r.POST("/user/info", UserInfoAction)

	r.Run()

}
func UserInfoAction(c *gin.Context) {
	userId  := c.PostForm("user_id")
	userName := c.PostForm("user_name")
	fmt.Println(userId)
	fmt.Println(userName)
	c.String(200,"OK")
}
```



```shell
curl -d "user_id=1&user_name=user1" 'http://0.0.0.0:8080/user/info'
OK                                                                         
```



和查询参数方法一样，对于表单的参数接收，`Gin`也提供了一系列的方法，他们的用法和查询参数的一样。



| 查询参数      | Form表单         | 说明                                    |
| :------------ | :--------------- | :-------------------------------------- |
| Query         | PostForm         | 获取key对应的值，不存在为空字符串       |
| GetQuery      | GetPostForm      | 多返回一个key是否存在的结果             |
| QueryArray    | PostFormArray    | 获取key对应的数组，不存在返回一个空数组 |
| GetQueryArray | GetPostFormArray | 多返回一个key是否存在的结果             |
| QueryMap      | PostFormMap      | 获取key对应的map，不存在返回空map       |
| GetQueryMap   | GetPostFormMap   | 多返回一个key是否存在的结果             |
| DefaultQuery  | DefaultPostForm  | key不存在的话，可以指定返回的默认值     |

## Gin 文件上传

`multipart/form-data`用于文件上传。gin文件上传也很方便，和原生的net/http方法类似，不同在于gin把原生的request封装到c.Request中了。我们可以看一下以下的代码

```go
func main() {
	router := gin.Default()
	// Set a lower memory limit for multipart forms (default is 32 MiB)
	// router.MaxMultipartMemory = 8 << 20  // 8 MiB
	router.POST("/upload", func(c *gin.Context) {
		// single file
		file, err:= c.FormFile("file")
		if err != nil {
			c.JSON(200,fmt.Errorf("Get file failed %v \n",err))
		}

		// Upload the file to specific dst.
		fileName := fmt.Sprintf("%s%d",file.Filename,time.Now().Unix())
		c.SaveUploadedFile(file, fileName)

		/*
		   也可以直接使用io操作，拷贝文件数据。
		   out, err := os.Create(fileName)
		   defer out.Close()
		   _, err = io.Copy(out, file)
		*/

		c.String(http.StatusOK, fmt.Sprintf("'%s' uploaded!", file.Filename))
	})
	router.Run(":8080")
}

```



```go
$ curl -X POST http://0.0.0.0:8080/upload -F "file=@/Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/gin-lib/ex5/main.go" -H "Content-Type: multipart/form-data"
'main.go' uploaded!
```



## Gin 处理Json 

application/json 这个 Content-Type 几乎是最常用到的一种格式。实际上，现在越来越多的人把它作为请求头，用来告诉服务端消息主体是序列化后的 JSON 字符串。gin中当然也支持这种格式的解析了。我们直接来看代码

```go
func main() {
	r := gin.Default()

	r.POST("/user/create", UserCreateAction)
	r.Run()
}

type UserCreateReq struct {
	UserName  string `json:"user_name"`
	UserEmail string `json:"user_email"`
}
type User struct {
	ID        int64  `json:"id"`
	UserName  string `json:"user_name"`
	UserEmail string `json:"user_email"`
}

type RespData struct {
	ErrorNo  int64  `json:"err_no"`
	ErrorMsg string `json:"err_msg"`
	Data     interface{} `json:"data"`
}

func SetData(c *gin.Context,data interface{})  {
	c.JSON(http.StatusOK,&RespData{
		ErrorNo:  0,
		ErrorMsg: "",
		Data:     data,
	})
}

func SetError(c *gin.Context,err error, errNo int64)  {
	c.JSON(http.StatusOK,&RespData{
		ErrorNo:  errNo,
		ErrorMsg: err.Error(),
		Data:     nil,
	})
}


func UserCreateAction(c *gin.Context) {
	var req UserCreateReq
	err := c.ShouldBind(&req)
	if err != nil {
		SetError(c,err,1)
		return
	}

	c.JSON(200, &User{
		ID:        1,
		UserName:  req.UserName,
		UserEmail: req.UserEmail,
	})
}
```



```shell
curl -X POST http://0.0.0.0:8080/user/create -d '{"user_name": "张三", "user_email": "zhangsan@163.com"}' -H "Content-Type: applicatiojson"
{"id":1,"user_name":"张三","user_email":"zhangsan@163.com"}
```







参考连接

Gin 源码以及官方文档  https://github.com/gin-gonic/gin

Golang Gin 实战（一）| 快速安装入门  https://www.flysnow.org/2019/12/10/golang-gin-quick-start.html#%E5%85%A5%E9%97%A8%E8%A6%81%E6%B1%82

RESTful API 设计指南  http://www.ruanyifeng.com/blog/2014/05/restful_api.html

四种常见的 POST 提交数据方式  https://imququ.com/post/four-ways-to-post-data-in-http.html



