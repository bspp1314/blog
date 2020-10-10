---
title: "Gin的学习笔记1"
date: 2020-10-09T18:49:19+08:00
draft: true
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







参考连接

Gin 源码以及官方文档  https://github.com/gin-gonic/gin

Golang Gin 实战（一）| 快速安装入门  https://www.flysnow.org/2019/12/10/golang-gin-quick-start.html#%E5%85%A5%E9%97%A8%E8%A6%81%E6%B1%82



