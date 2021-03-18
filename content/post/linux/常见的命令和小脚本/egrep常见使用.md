---
title: "递归替换特地文件中的字符串"
date: 2021-03-17T14:48:25+08:00
draft: true
---

egrep 遍历文件查询，并排除某些需要要的文件

```shell
egrep  --exclude="*.log" -rn "AddSlaveInstanceReq" ./
```



