---
title: "Go常见库之validator"
date: 2020-10-09T13:58:10+08:00
draft: false
categories: ["golang","golang常见库"]
---

# 简介

`Validator`是一个基于结构体tag用于对数据进行校验库，在 Web 开发中，对用户传过来的数据我们都需要进行严格校验，防止用户的恶意请求。<!--more-->



# 简单的使用

```go
type User struct {
	UserName string `validate:"required,max=16"`
	ID       int64  `validate:"required"`
}

func main() {
	v := validator.New()
	err := v.Struct(&User{
		UserName: "test0001",
		ID:       10,
	})
	if err != nil {
		fmt.Println(err)
	}

	err = v.Struct(&User{
		UserName: "test000000000000000000000002",
		ID:       10,
	})
	if err != nil {
		fmt.Println(err)
	}

	err = v.Struct(&User{
		UserName: "test0003",
		ID:       0,
	})
	if err != nil {
		fmt.Println(err)
	}

}
```

out

```
Key: 'User.UserName' Error:Field validation for 'UserName' failed on the 'max' tag
Key: 'User.ID' Error:Field validation for 'ID' failed on the 'required' tag
```

`validator`在结构体标签（`struct tag`）中定义字段的**约束**。使用`validator`验证数据之前，我们需要调用`validator.New()`创建一个**验证器**，然后通过调用它的`Struct()`方法来验证各种结构对象的字段是否符合定义的约束。

上面的代码中 对 User 做了以下的约束

- UserName 不能为空，且最大长度不超过16。
- ID 必须存在



属于出现了两个错误，第一个错误违反了UserName最大长度不超过16约束，第二个错误违反了ID必须存在的约束。

# 约束

validator中提供了非常丰富的约束，这里我们来介绍一些非常常见的约束

##  常见的约束单字段



| Tag      | Description           | example                               |
| :------- | --------------------- | ------------------------------------- |
| eq       | Equals                | ID       int64  `validate:"eq=10"`    |
| gt       | Greater than          | ID       int64  `validate:"gt=10"`    |
| gte      | Greater than or equal | ID       int64  `validate:"gte=10"`   |
| lt       | Less Than             | ID       int64  `validate:"lt=10"`    |
| lte      | Less Than or Equal    | ID       int64  `validate:"lte=10"`   |
| ne       | Not Equal             | ID       int64  `validate:"ne=10"`    |
| max      | Maximum               | ID       int64  `validate:"max=100"`  |
| min      | Minimum               | ID       int64  `validate:"min=10"`   |
| required | Required              | ID       int64  `validate:"required"` |



## 跨字段约束
validator允许定义跨字段的约束，即该字段与其他字段之间的关系。这种约束实际上分为两种，一种是参数字段就是同一个结构中的平级字段，另一种是参数字段为结构中其他字段的字段。


###  跨字段约束-平级字段
跨字段约束-平级字段约束语法很简单，只要在单个字段里面加上field上即可。

```go
type User struct {
	UserName  string `validate:"required,max=16"`
	UserName2 string `validate:"required,eqfield=UserName"`
	ID        int64  `validate:"required"`
}

func main() {
	v := validator.New()
	err := v.Struct(&User{
		UserName:  "test0001",
		UserName2: "test001",
		ID:        10,
	})
	if err != nil {
		fmt.Println(err)
	}

	err = v.Struct(&User{
		UserName:  "test0002",
		UserName2: "test0002",
		ID:        10,
	})
	if err != nil {
		fmt.Println(err)
	}
}
```

out 
```shell
Key: 'User.UserName2' Error:Field validation for 'UserName2' failed on the 'eqfield' tag
```

### 跨字段约束-非平级字段

跨字段约束-非平级字段在`field`之前还需要加上`cs`（可以理解为`cross-struct`），`eq`就变为`eqcsfield`。

```go
type User struct {
	UserName  string `validate:"required,max=16"`
	ID        int64  `validate:"required"`
	Class     Class  `validate:"required"`
	ClassName string `validate:"eqcsfield=Class.Name"`
}

type Class struct {
	Name string `json:"name"`
}

func main() {
	v := validator.New()
	err := v.Struct(&User{
		UserName:  "test0001",
		ClassName: "class1",
		Class: Class{Name: "class1"},
		ID:        1,
	})
	if err != nil {
		fmt.Println("test1 failed :",err)
	}

	err = v.Struct(&User{
		UserName:  "test0002",
		ID:        2,
		ClassName: "class1",
		Class: Class{Name: "class2"},
	})
	if err != nil {
		fmt.Println("test2 failed :",err)
	}
}
```

out 

```go
test2 failed : Key: 'User.ClassName' Error:Field validation for 'ClassName' failed on the 'eqcsfield' tag
```

## 字符串

`validator`中关于字符串的约束有很多，我们这里介绍一些常用的。

| Tag         | Description                                  | example          |
| ----------- | -------------------------------------------- | ---------------- |
| contains    | Contains                                     | contains=zz      |
| containsany | Contains Any (包含参数中任意的 UNICODE 字符) | containsany=abcd |
| endswith    | Ends With                                    |                  |
| lowercase   | Lowercase                                    |                  |
| startswith  | Starts With                                  |                  |
| uppercase   | Uppercase                                    |                  |

### 唯一性

使用`unqiue`来指定唯一性约束，对不同类型的处理如下：

- 对于数组和切片，`unique`约束没有重复的元素；
- 对于`map`，`unique`约束没有重复的**值**；
- 对于元素类型为结构体的切片，`unique`约束结构体对象的某个字段不重复，通过`unqiue=field`指定这个字段名。



## 更多约束

`validator`提供了大量的、各个方面的、丰富的约束，如`ASCII/UNICODE`字母、数字、十六进制、十六进制颜色值、大小写、RBG 颜色值，HSL 颜色值、HSLA 颜色值、JSON 格式、文件路径、URL、base64 编码串、ip 地址、ipv4、ipv6、UUID、经纬度等等。可以直接参考官方文档。



# 自定义约束

除了使用`validator`提供的约束外，还可以定义自己的约束。比如用户必须使用回文串作为用户名。

```go
type User struct {
	UserName string `validate:"required,palindrome"`
	ID       int64  `validate:"required"`
}

func IsPalindrome(s string) bool  {
	left := 0
	right := len(s) -1

	for left < right {
		if s[left] != s[right] {
			return false
		}

		left++
		right--
	}

	return true
}


func main() {
	v := validator.New()
	v.RegisterValidation("palindrome", func(fl validator.FieldLevel) bool {
		return IsPalindrome(fl.Field().String())
	})

	u := User{
		UserName: "test0001",
		ID:       1,
	}

	err := v.Struct(&u)
	if err != nil {
		fmt.Printf("test1 failed %v \n",err)
	}

	u2 := User{
		UserName: "test00022000tset",
		ID:       2,
	}

	err = v.Struct(&u2)
	if err != nil {
		fmt.Printf("test2 failed %v \n",err)
	}

}
```

out 

```shell
test1 failed Key: 'User.UserName' Error:Field validation for 'UserName' failed on the 'palindrome' tag 
```



# 错误翻译

在使用`validator`进行约束的时候，返回的错误都是英文的信息，而且字段名字也是英文，有时候我们不想要用户知道字段或错误的信息，就需要进行翻译。其代码如下

```go
package main

import (
	"fmt"
	"github.com/go-playground/validator/v10/translations/en"
	"github.com/go-playground/validator/v10/translations/zh"
	"reflect"
	"strings"

	et "github.com/go-playground/locales/en"
	zt "github.com/go-playground/locales/zh"
	ut "github.com/go-playground/universal-translator"
	"github.com/go-playground/validator/v10"
)

type User struct {
	UserName string `validate:"required,max=16" label:"用户名"`
	ID       int64  `validate:"required" label:"用户ID"`
}

// 定义一个全局翻译器T
var trans ut.Translator

// InitTrans 初始化翻译器
func InitTrans(v *validator.Validate, locale string) (err error) {
	v.RegisterTagNameFunc(func(fld reflect.StructField) string {
		name := strings.SplitN(fld.Tag.Get("label"), ",", 2)[0]
		if name == "-" {
			return ""
		}
		return name
	})

	zhT := zt.New() // 中文翻译器
	enT := et.New() // 英文翻译器

	// 第一个参数是备用（fallback）的语言环境
	// 后面的参数是应该支持的语言环境（支持多个）
	// uni := ut.New(zhT, zhT) 也是可以的
	uni := ut.New(enT, zhT, enT)

	// locale 通常取决于 http 请求头的 'Accept-Language'
	var ok bool
	// 也可以使用 uni.FindTranslator(...) 传入多个locale进行查找
	trans, ok = uni.GetTranslator(locale)
	if !ok {
		return fmt.Errorf("uni.GetTranslator(%s) failed", locale)
	}

	// 注册翻译器
	switch locale {
	case "en":
		err = en.RegisterDefaultTranslations(v, trans)
	case "zh":
		err = zh.RegisterDefaultTranslations(v, trans)
	default:
		err = en.RegisterDefaultTranslations(v, trans)
	}
	return
}

func fmtValidateErr(fields map[string]string) string {
	var res string
	for _,err := range fields {
		res += fmt.Sprintf("%s\n",err)
	}

	return res
}

func main() {
	v := validator.New()
	err := InitTrans(v,"zh")
	if err != nil {
		fmt.Printf("init trans failed, err:%v\n", err)
		return
	}

	u := User{
		UserName: "test0000000000000000000001",
		ID:       0,
	}

	err = v.Struct(&u)
	if err != nil {
		errs, ok := err.(validator.ValidationErrors)
		if ok {
			fmt.Println(fmtValidateErr(errs.Translate(trans)))
		}

	}

}

```

out 

```
用户ID为必填字段
用户名长度不能超过16个字符
```

















# 参考连接

源码 github.com/go-playground/validator/v10