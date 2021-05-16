---
title: "sed"
date: 2021-04-22T14:48:25+08:00
draft: true 
---









# 概述

`sed`是`stream editor`的简称，也就是流编辑器。它一次处理一行内容，处理时，把当前处理的行存储在临时缓冲区中，称为`"pattern space"`，接着用`sed`命令处理缓冲区中的内容，处理完成后，把缓冲区的内容送往屏幕。接着处理下一行，这样不断重复，直到文件末尾。文件内容并没有 改变，除非你使用重定向存储输出。



# 语法

#### 命令格式

```
sed [option] 'command' input_file
```

#### 常用选项

- `-n` 使用安静`silent`模式。在一般`sed`的用法中，所有来自`stdin`的内容一般都会被列出到屏幕上。但如果加上`-n`参数后，则只有经过`sed`特殊处理的那一行(或者动作)才会被列出来
- `-e` 直接在指令列模式上进行 `sed` 的动作编辑
- `-f` 直接将 `sed` 的动作写在一个文件内，`-f filename`则可以执行`filename`内的`sed`命令
- `-r` 让`sed`命令支持扩展的正则表达式(默认是基础正则表达式)
- `-i` 直接修改读取的文件内容，而不是由屏幕输出



# 常见例子

## 使用s 命令

```shell
$ echo "hello word hello\nHello world\nhelloworld" |  sed  "s/hello/HELLO/g"    
HELLO word HELLO
Hello world
HELLOworld

$echo "hello word hello\nHello world\nhelloworld" |  sed  "s/hello/HELLO/" 
HELLO word hello
Hello world
HELLOworld

```



其中 s 表示替换，/hello/ 表示匹配hello,/HELLO/表示把匹配替换成 HELLO /g 表示一行上的替换所有的匹配）



### 在行首添加

```shell
echo "hello word hello\nHello world\nhelloworld" |  sed  "s/^/##/g"   
##hello word hello
##Hello world
##helloworld
```

### 在行尾添加

```shell
$ echo "hello word hello\nHello world\nhelloworld" |  sed  "s/$/##/g" 
hello word hello##
Hello world##
helloworld##
```

正则表达式的一些最基本的东西：

- `^` 表示一行的开头。如：`/^#/` 以#开头的匹配。
- `$` 表示一行的结尾。如：`/}$/` 以}结尾的匹配。
- `\<` 表示词首。 如：`\<abc` 表示以 abc 为首的詞。
- `\>` 表示词尾。 如：`abc\>` 表示以 abc 結尾的詞。
- `.` 表示任何单个字符。
- `*` 表示某个字符出现了0次或多次。
- `[ ]` 字符集合。 如：`[abc]` 表示匹配a或b或c，还有 `[a-zA-Z]` 表示匹配所有的26个字符。如果其中有^表示反，如 `[^a]` 表示非a的字符

去掉 html 中的tag 

```
echo '<b>This</b> is what <span style="text-decoration: underline;">I</span> meant. Understand?' | sed 's/<[^>]*>//g'
This is what I meant. Understand?
```



### 指定行

只在第一行到第二行

```
echo "hello word hello\nHello world\nhelloworld" |  sed  "1,2s/$/##/g" 
hello word hello##
Hello world##
helloworld
```



### 只替换每一行的第一个h 

```shell
echo "hello word hello\nHello world\nhelloworld" |  sed  "s/h/H/1"  
Hello word hello
Hello world
Helloworld

```





###  只替换每一行的第二个h 
```shell
echo "hello word hello\nHello world\nhelloworld" |  sed  "s/h/H/2" 
hello word Hello
Hello world
helloworld
```

### 只替换每一行的第3个以后的l：

```go
echo "hello word hello\nHello world\nhelloworld" |  sed  "s/l/L/3g"
hello word heLLo
Hello worLd
helloworLd
```



### 多个匹配

如果我们需要一次替换多个模式，可参看下面的示例：

```
echo "hello word hello\nHello world\nhelloworld" |  sed '1,3s/h/H/g; 2,$s/l/L/g'
Hello word Hello
HeLLo worLd
HeLLoworLd
```

或者

```
$ echo "hello word hello\nHello world\nhelloworld" |  sed -e '1,3s/h/H/g' -e '3,$s/l/L/g'
Hello word Hello
Hello world
HeLLoworLd
```





更多用法可以查询 sed 官方文档https://www.gnu.org/software/sed/

