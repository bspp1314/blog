---
title: "Pprof"
date: 2021-01-29T18:09:29+08:00
draft: true
---

## 使用生成火焰图优化

获取最近10秒程序运行的cpuprofile,-seconds参数不填默认为30。

```text
go tool pprof http://127.0.0.1:8080/debug/pprof/profile -seconds 10
```

等10s后会生成一个: pprof.samples.cpu.001.pb.gz文件

**2. 生成火焰图**

```text
go tool pprof -http=:8081 ~/pprof/pprof.samples.cpu.001.pb.gz
```

其中-http=:8081会启动一个http服务,端口为8081,然后浏览器会弹出此文件的图解:

