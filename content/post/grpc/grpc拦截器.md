---
title: "Grpc拦截器"
date: 2021-04-30T14:24:20+08:00
draft: true
---

grpc服务端和客户端都提供了interceptor功能，功能类似middleware，很适合在这里处理验证、日志等流程。



利用拦截器，可以对gRPC进行扩展，利用社区的力量将gRPC发展壮大，也可以让开发者更灵活地处理gRPC流程中的业务逻辑。下面列出了利用拦截器实现的一些功能框架：



1. [Go gRPC Middleware](https://github.com/grpc-ecosystem/go-grpc-middleware):提供了拦截器的interceptor链式的功能，可以将多个拦截器组合成一个拦截器链，当然它还提供了其它的功能，所以以gRPC中间件命名。
2. [grpc-multi-interceptor](https://github.com/kazegusuri/grpc-multi-interceptor): 是另一个interceptor链式功能的库，也可以将单向的或者流式的拦截器组合。
3. [grpc_auth](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/auth): 身份验证拦截器
4. [grpc_ctxtags](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/tags): 为上下文增加`Tag` map对象
5. [grpc_zap](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/logging/zap): 支持`zap`日志框架
6. [grpc_logrus](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/logging/logrus): 支持`logrus`日志框架
7. [grpc_prometheus](https://github.com/grpc-ecosystem/go-grpc-prometheus): 支持 `prometheus`
8. [otgrpc](https://github.com/grpc-ecosystem/grpc-opentracing/tree/master/go/otgrpc): 支持opentracing/zipkin
9. [grpc_opentracing](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/tracing/opentracing):支持opentracing/zipkin
10. [grpc_retry](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/retry): 为客户端增加重试的功能
11. [grpc_validator](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/validator): 为服务器端增加校验的功能
12. [xrequestid](https://github.com/mercari/go-grpc-interceptor/tree/master/xrequestid): 将request id 设置到context中
13. [go-grpc-interceptor](https://github.com/mercari/go-grpc-interceptor/tree/master/acceptlang): 解析`Accept-Language`并设置到context
14. [requestdump](https://github.com/mercari/go-grpc-interceptor/tree/master/requestdump): 输出request/response



##  拦截器的种类

服务端链式拦截器

```go
func ChainUnaryInterceptor(interceptors ...UnaryServerInterceptor) ServerOption 
```









