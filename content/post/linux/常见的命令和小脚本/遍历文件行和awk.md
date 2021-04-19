---
title: "重组字符串"
date: 2021-03-04T14:48:25+08:00
draft: false
---



```shell
#!/bin/bash 
 
lines="1,linyuanpeng1,林远鹏\n2,linyuanpeng2,林远鹏2"
 
echo -e $lines | while read line
do
    echo $line | awk -F ',' '{print $2}'
done             
```

out 

```shell
linyuanpeng1
linyuanpeng2
```



# awk 

awk 是一种处理文本文件的语言，是一个强大的文本分析工具。

　　awk 其实不仅仅是工具软件，还是一种编程语言。

　　awk 是以文件的一行内容为处理单位的。awk读取一行内容，然后根据指定条件判断是否处理此行内容，若此行文本符合条件，则按照动作处理文本，否则跳过此行文本，读取下一行进行判断。



# 基本用法

　condition：条件。若此行文本符合该条件，则按照 action 处理此行文本。不添加条件时则处理每一行文本；

　action：动作。按照动作处理符合要求的内容。一般用于打印指定的内容信息；





## 处理指定文件的内容

　　awk  'condition { action }'  filename



##  处理某个命令的执行结果

　　command | awk ' condition { action }'



##  常用参数

####  F（指定字段分隔符）

　　默认使用空格作为分隔符。

```shell
[root@localhost awk]# echo "aa bb  cc dd  ee ff" | awk  '{print $1}'
aa
[root@localhost awk]# echo "aa bb l cc dd l ee ff" | awk -F 'l' '{print $1}'
aa bb 
[root@localhost awk]# echo "aa bb  cc : dd  ee ff" | awk -F ':' '{print $1}'
aa bb  cc 
```



# 变量

### FS（字段分隔符）　

　　默认是空格和制表符。

　　\$0 表示当前整行内容，\$1，\$2 表示第一个字段，第二个字段

```shell
[root@localhost zabbix_agentd.d]# echo "aa bb cc  dd" | awk '{ print $0}'
aa bb cc  dd
[root@localhost zabbix_agentd.d]# echo "aa bb cc  dd" | awk '{ print $1}'
aa
[root@localhost zabbix_agentd.d]# echo "aa bb cc  dd" | awk '{ print $2}'
bb
```



## NF (当前行的段个数)

$NF就代表最后一个字段，$(NF-1)代表倒数第二个字段

```shell
[root@localhost zabbix_agentd.d]# echo "aa bb cc  dd" | awk '{ print $NF}'
dd
[root@localhost zabbix_agentd.d]# echo "aa bb cc  dd" | awk '{ print $(NF-1)}'
cc
```

不打印某一行

不打某一行时，将对应列设置为空字符串即可，用 $NF=""，设置多列时用分号分隔开

```shell
[root@VM_4_9_centos ~]# cat aa.txt 
a285wkdp5dcxm-lrst-7b97f79c5c-rwqrw                               2/2     Running                0          4d
a2csvhvnqlld2-zmsp-7df5499f79-r9plz                               2/2     Running                75         41d
a42fz6kc9wzsp-8bc8-5799c7d977-h69nt                               2/2     Running                0          5d2h// 不打印最后一行
[root@VM_4_9_centos ~]# cat aa.txt | awk '{$NF="";print $0}'
a285wkdp5dcxm-lrst-7b97f79c5c-rwqrw 2/2 Running 0 
a2csvhvnqlld2-zmsp-7df5499f79-r9plz 2/2 Running 75 
a42fz6kc9wzsp-8bc8-5799c7d977-h69nt 2/2 Running 0 // 不打印最后两行
[root@VM_4_9_centos ~]# cat aa.txt | awk '{$(NF-1)="";$NF="";print $0}'
a285wkdp5dcxm-lrst-7b97f79c5c-rwqrw 2/2 Running  
a2csvhvnqlld2-zmsp-7df5499f79-r9plz 2/2 Running  
a42fz6kc9wzsp-8bc8-5799c7d977-h69nt 2/2 Running
```



## NR(当前处理的是第几行)

```shell
echo -e "aa ss\ndd ff" | awk '{print NR"===>"$0}'
1===>aa ss
2===>dd ff
```





```shell
$ echo -e "aa ss\ndd ff\nzz kk\npp mm" | awk 'NR>2 {print NR"===>"$0}'
3===>zz kk
4===>pp mm
```





更多用法可以查询 awk 官方文档 https://www.gnu.org/software/gawk/manual/gawk.html

