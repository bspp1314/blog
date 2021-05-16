---
title: "Grpc简单的使用"
date: 2021-04-27T17:54:06+08:00
draft: true
---

# 简单入门

```shell
go get -u github.com/golang/protobuf/proto
go get -u github.com/golang/protobuf/protoc-gen-go
go get -u google.golang.org/grpc
```



### 创建并编译proto文件

```protobuf
syntax = "proto3";

package pb;


// 定义一个打招呼服务
service Greeter {
  // SayHello 方法
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}

// 包含人名的一个请求消息
message HelloRequest {
  string name = 1;
}

// 包含问候语的响应消息
message HelloReply {
  string message = 1;
}

```



生成对应 的go 文件

```shell 
 protoc --go_out=plugins=grpc:. *.proto
```





# 简单使用

gRPC主要有4种请求和响应模式，分别是`简单模式(Simple RPC)`、`服务端流式（Server-side streaming RPC）`、`客户端流式（Client-side streaming RPC）`、和`双向流式（Bidirectional streaming RPC）`。

- `简单模式(Simple RPC)`：客户端发起请求并等待服务端响应。
- `服务端流式（Server-side streaming RPC）`：客户端发送请求到服务器，拿到一个流去读取返回的消息序列。 客户端读取返回的流，直到里面没有任何消息。
- `客户端流式（Client-side streaming RPC）`：与服务端数据流模式相反，这次是客户端源源不断的向服务端发送数据流，而在发送结束后，由服务端返回一个响应。
- `双向流式（Bidirectional streaming RPC）`：双方使用读写流去发送一个消息序列，两个流独立操作，双方可以同时发送和同时接收。



## Simpe RPC 

定义Request

```
message HelloRequest {
  string name = 1; //请求参数
}
```

 

定义Response

```
message HelloReply {
  string message = 1;
}
```

定义服务方法

```
// 定义一个打招呼服务
service Greeter {
  // SayHello 方法
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}
```



通过 protoc 生成相应的文件

```
 protoc --go_out=plugins=grpc:. *.proto
```

### 服务端代码

```go
type SearchService struct{}
//实现我们在 proto 里定义的服务接口
func (s *SearchService) SayHello(ctx context.Context, r *pb.HelloRequest) (*pb.HelloReply, error) {
	return &pb.HelloReply{
		Message: "hello reply",
	}, nil
}

const (
	// Address 监听地址
	Address string = ":8000"
	// Network 网络通信协议
	Network string = "tcp"
)

func main() {
	// 监听本地的8972端口
	lis, err := net.Listen(Network, Address)
	if err != nil {
		fmt.Printf("failed to listen: %v", err)
		return
	}
	s := grpc.NewServer()                         // 创建gRPC服务器
	pb.RegisterGreeterServer(s, &SearchService{}) // 在gRPC服务端注册服务

	// 在给定的gRPC服务器上注册服务器反射服务
	// Serve方法在lis上接受传入连接，为每个连接创建一个ServerTransport和server的goroutine。
	// 该goroutine读取gRPC请求，然后调用已注册的处理程序来响应它们。
	err = s.Serve(lis)
	if err != nil {
		fmt.Printf("failed to serve: %v", err)
		return
	}
}
```



### 客户端代码

```go
const (
	// Address 连接地址
	Address string = ":8000"
)

func main() {
	// 连接服务器
	conn, err := grpc.Dial(Address, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("net.Connect err: %v", err)
	}
	defer conn.Close()

	// 建立gRPC连接
	grpcClient := pb.NewGreeterClient(conn)
	// 创建发送结构体
	req := pb.HelloRequest{
		Name: "hello",
	}
	
	//调用服务端方法
	res, err := grpcClient.SayHello(context.Background(), &req)
	if err != nil {
		log.Fatalf("Call Route err: %v", err)
	}

	log.Println(res)
}
```





## 服务端流式RPC

`简单模式RPC`，当数据量大或者需要不断传输数据时候，我们应该使用流式RPC，它允许我们边处理边传输数据。grpc 提供了`流式RPC`。这里我们先看一下`服务端流式RPC`

`服务端流式RPC`：客户端发送请求到服务器，拿到一个流去读取返回的消息序列。 客户端读取返回的流，直到里面没有任何消息。



### protoc  文件定义

```
syntax = "proto3";

package pb;

//服务端流式RPC：客户端发送请求到服务器，拿到一个流去读取返回的消息序列。 客户端读取返回的流，直到里面没有任何消息。
service Greeter {
  // SayHello 方法
  rpc SayHello(HelloRequest)returns(stream HelloStreamReply){};
}


// 包含人名的一个请求消息
message HelloRequest {
  string name = 1;
}


// 定义流式响应信息
message HelloStreamReply{
  // 流式响应数据
  string message = 1;
}

```



可以看到服务端流式RPC只要在Reply 之前在一个stream 即可



### 服务端代码

```go
//服务端流式RPC
type SearchService struct{}

func (s *SearchService) SayHello(req *pb.HelloRequest, server pb.Greeter_SayHelloServer) error {
	for n := 0; n < 5; n++ {
		err := server.Send(&pb.HelloStreamReply{Message: fmt.Sprintf("%s-%d", req.Name, n)})
		if err != nil {
			return err
		}
	}
	return nil
}

const (
	// Address 监听地址
	Address string = ":8000"
	// Network 网络通信协议
	Network string = "tcp"
)

func main() {
	// 监听本地的8000端口
	lis, err := net.Listen(Network, Address)
	if err != nil {
		fmt.Printf("failed to listen: %v", err)
		return
	}
	s := grpc.NewServer()                         // 创建gRPC服务器
	pb.RegisterGreeterServer(s, &SearchService{}) // 在gRPC服务端注册服务

	reflection.Register(s)
	//在给定的gRPC服务器上注册服务器反射服务
	//Serve方法在lis上接受传入连接，为每个连接创建一个ServerTransport和server的goroutine。
	//该goroutine读取gRPC请求，然后调用已注册的处理程序来响应它们。
	err = s.Serve(lis)
	if err != nil {
		fmt.Printf("failed to serve: %v", err)
		return
	}
}
```



## 客户端流式RPC

### protoc 文件定义

```
syntax = "proto3";

package pb;

//服务端流式RPC：客户端发送请求到服务器，拿到一个流去读取返回的消息序列。 客户端读取返回的流，直到里面没有任何消息。

service Greeter {
  // SayHello 方法
  rpc SayHello(stream HelloStreamRequest)returns(HelloReply){};
}


// 包含人名的一个请求消息
message HelloStreamRequest {
  string name = 1;
}


// 定义流式响应信息
message HelloReply{
  // 流式响应数据
  string message = 1;
}
```

可以看到服务端流式RPC只要在Request 之前在一个stream 即可



###  客户端

```go
const (
	// Address 连接地址
	Address string = ":8000"
)

func main() {
	// 连接服务器
	conn, err := grpc.Dial(Address, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("net.Connect err: %v", err)
	}
	defer conn.Close()

	// 建立gRPC连接
	grpcClient := pb.NewGreeterClient(conn)

	stream,err := grpcClient.SayHello(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	for i := 0; i < 5; i++ {
		err = stream.Send(&pb.HelloStreamRequest{Name: fmt.Sprintf("hello %d ",i)})
		if err != nil {
			log.Printf("send %d err %v \n",i,err)
			continue
		}
	}

	res,err := stream.CloseAndRecv()
	if err != nil {
		log.Fatalf("Get response err: %v", err)
	}

	log.Println(res.Message)
}

```



### 服务端

```
type SearchService struct{}

func (s *SearchService) SayHello(server pb.Greeter_SayHelloServer) error {
	n := 1

	for  {
		req,err := server.Recv()
		if err == io.EOF {
			return nil
		}

		log.Println("server recv value is ",req.Name)
		time.Sleep(time.Second)
		err = server.Send(&pb.HelloStreamReply{
			Message: fmt.Sprintf("%s %d",req.Name,n),
		})
		if err != nil {
			log.Printf("Send Msg %d failed \n",n)
			continue
		}
		n++
	}

}

const (
	// Address 监听地址
	Address string = ":8000"
	// Network 网络通信协议
	Network string = "tcp"
)

func main() {
	lis, err := net.Listen(Network, Address)
	if err != nil {
		fmt.Printf("failed to listen: %v", err)
		return
	}
	s := grpc.NewServer()                         // 创建gRPC服务器
	pb.RegisterGreeterServer(s, &SearchService{}) // 在gRPC服务端注册服务

	reflection.Register(s)
	err = s.Serve(lis)
	if err != nil {
		fmt.Printf("failed to serve: %v", err)
		return
	}

}
```



## 双向流式（Bidirectional streaming RPC）

### Protoc 代码

```
syntax = "proto3";

package pb;

service Greeter {
  // SayHello 方法
  rpc SayHello(stream HelloStreamRequest)returns(stream HelloStreamReply){};
}


// 包含人名的一个请求消息
message HelloStreamRequest {
  string name = 1;
}


// 定义流式响应信息
message HelloStreamReply{
  // 流式响应数据
  string message = 1;
}
```



### 客户端代码

```go
import (
	"context"
	"fmt"
	"log"

	"github.com/bspp1314/go-common-lib/grpc-lib/ex4/pb"
	"google.golang.org/grpc"
)

const (
	// Address 连接地址
	Address string = ":8000"
)

func main() {
	// 连接服务器
	conn, err := grpc.Dial(Address, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("net.Connect err: %v", err)
	}
	defer conn.Close()

	// 建立gRPC连接
	grpcClient := pb.NewGreeterClient(conn)

	stream, err := grpcClient.SayHello(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	for i := 0; i < 5; i++ {
		err = stream.Send(&pb.HelloStreamRequest{Name: fmt.Sprintf("hello %d ", i)})
		if err != nil {
			log.Printf("send %d err %v \n", i, err)
			continue
		}

		//get response value

		resp,err := stream.Recv()
		if err != nil {
			log.Printf("recv %d value failed %v ",i,err)
		}

		log.Println(resp.Message)
	}

	//最后关闭流
	err = stream.CloseSend()
	if err != nil {
		log.Fatalf("close stream err: %v", err)
	}
}

```



### 服务端的代码

```go
type SearchService struct{}

func (s *SearchService) SayHello(server pb.Greeter_SayHelloServer) error {
	n := 1

	for  {
		req,err := server.Recv()
		if err == io.EOF {
			return nil
		}

		log.Println("server recv value is ",req.Name)
		time.Sleep(time.Second)
		err = server.Send(&pb.HelloStreamReply{
			Message: fmt.Sprintf("%s %d",req.Name,n),
		})
		if err != nil {
			log.Printf("Send Msg %d failed \n",n)
			continue
		}
		n++
	}

}

const (
	// Address 监听地址
	Address string = ":8000"
	// Network 网络通信协议
	Network string = "tcp"
)

func main() {
	lis, err := net.Listen(Network, Address)
	if err != nil {
		fmt.Printf("failed to listen: %v", err)
		return
	}
	s := grpc.NewServer()                         // 创建gRPC服务器
	pb.RegisterGreeterServer(s, &SearchService{}) // 在gRPC服务端注册服务

	reflection.Register(s)
	err = s.Serve(lis)
	if err != nil {
		fmt.Printf("failed to serve: %v", err)
		return
	}

}

```







https://zhuanlan.zhihu.com/p/161277955 深入了解服务注册与发现