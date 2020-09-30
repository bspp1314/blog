---
title: "Golang反射的常见操作"
date: 2020-09-29T18:13:22+08:00
draft: false
categories: ["golang"]
tags: ["反射"]
---

<!--more-->

# 获取所有结构体的字段名字

```go
func GetFieldName(structName interface{}) []string {
	t := reflect.TypeOf(structName)
	if t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	if t.Kind() != reflect.Struct {
		log.Println("Check type error not Struct")
		return nil
	}
	fieldNum := t.NumField()
	result := make([]string, 0, fieldNum)
	for i := 0; i < fieldNum; i++ {
		result = append(result, t.Field(i).Name)
	}
	return result
}
```





# 获取结构体的Tag名字

```go
func GetFieldTag(structName interface{},v string) []string {
	t := reflect.TypeOf(structName)
	if t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	if t.Kind() != reflect.Struct {
		log.Println("Check type error not Struct")
		return nil
	}
	fieldNum := t.NumField()
	result := make([]string, 0, fieldNum)
	for i := 0; i < fieldNum; i++ {
		result = append(result, t.Field(i).Tag.Get(v))
	}
	return result
}
```

