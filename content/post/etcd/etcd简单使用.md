---
title: "Etcd简单使用"
date: 2021-04-20T10:23:58+08:00
draft: true
---

# ETCD 介绍

[etcd](https://etcd.io/)是使用Go语言开发的一个开源的、高可用的分布式key-value存储系统，可以用于配置共享和服务的注册和发现。

类似项目有zookeeper和consul。

etcd具有以下特点：

- 完全复制：集群中的每个节点都可以使用完整的存档
- 高可用性：Etcd可用于避免硬件的单点故障或网络问题
- 一致性：每次读取都会返回跨多主机的最新写入
- 简单：包括一个定义良好、面向用户的API（gRPC）
- 安全：实现了带有可选的客户端证书身份验证的自动化TLS
- 快速：每秒10000次写入的基准速度
- 可靠：使用Raft算法实现了强一致、高可用的服务存储目录



# KV服务

## 简单的使用

`etcd` 用 `PUT` 命令来设置键值对数据，`GET`命令用来根据key获取值,用DELETE来删除Key 

```go
func getClient() *clientv3.Client  {
	cli,err := clientv3.New(clientv3.Config{
		Endpoints:   []string{"127.0.0.1:2379"},
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		// handle error!
		log.Fatal(fmt.Errorf("Connect to etcd failed, err:%v \n"), err)
	}
	return cli
}

func main() {
	cli := getClient()
	defer cli.Close()


	ctx,cancel := context.WithTimeout(context.Background(),time.Second)
	_,err := cli.Put(ctx,"Language","Go")
	cancel()
	if err != nil {
		fmt.Printf("Put to etcd failed, err:%v\n", err)
		return
	}
	fmt.Println("Put value successes ")

	// get
	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	resp, err := cli.Get(ctx, "Language")
	cancel()
	if err != nil {
		fmt.Printf("Get from etcd failed, err:%v\n", err)
		return
	}
	for _, ev := range resp.Kvs {
		fmt.Printf("%s:%s\n", ev.Key, ev.Value)
	}
	fmt.Println("Get value successes ")


	// get
	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	_, err = cli.Delete(ctx, "Language")
	cancel()
	if err != nil {
		fmt.Printf("Delete from etcd failed, err:%v\n", err)
		return
	}
	fmt.Println("Delete value successes ")

}
```

## 其他的KV 接口

```go
type KV interface {
	// Put puts a key-value pair into etcd.
	// Note that key,value can be plain bytes array and string is
	// an immutable representation of that bytes array.
	// To get a string of bytes, do string([]byte{0x10, 0x20}).
	Put(ctx context.Context, key, val string, opts ...OpOption) (*PutResponse, error)

	// Get retrieves keys.
	// By default, Get will return the value for "key", if any.
	// When passed WithRange(end), Get will return the keys in the range [key, end).
	// When passed WithFromKey(), Get returns keys greater than or equal to key.
	// When passed WithRev(rev) with rev > 0, Get retrieves keys at the given revision;
	// if the required revision is compacted, the request will fail with ErrCompacted .
	// When passed WithLimit(limit), the number of returned keys is bounded by limit.
	// When passed WithSort(), the keys will be sorted.
	Get(ctx context.Context, key string, opts ...OpOption) (*GetResponse, error)

	// Delete deletes a key, or optionally using WithRange(end), [key, end).
	Delete(ctx context.Context, key string, opts ...OpOption) (*DeleteResponse, error)

	// Compact compacts etcd KV history before the given rev.
	Compact(ctx context.Context, rev int64, opts ...CompactOption) (*CompactResponse, error)

	// Do applies a single Op on KV without a transaction.
	// Do is useful when creating arbitrary operations to be issued at a
	// later time; the user can range over the operations, calling Do to
	// execute them. Get/Put/Delete, on the other hand, are best suited
	// for when the operation should be issued at the time of declaration.
	Do(ctx context.Context, op Op) (OpResponse, error)

	// Txn creates a transaction.
	Txn(ctx context.Context) Txn
}
```



# Lease 

Lease 是一种检测客户端存活状况的机制。群集授予具有生存时间的租约。如果 etcd 群集在给定的 TTL 时间内未收到 keepAlive，则租约到期。为了将租约绑定到键值存储中，每个 key 最多可以附加一个租约。当租约到期或被撤销时，该租约所附的所有 key 都将被删除。每个过期的密钥都会在事件历史记录中生成一个删除事件。

## 简单的使用



```go
func getClient() *clientv3.Client  {
	cli,err := clientv3.New(clientv3.Config{
		Endpoints:   []string{"127.0.0.1:2379"},
		DialTimeout: 5 * time.Second,
	})
	log.Println(err)
	if err != nil {
		// handle error!
		log.Fatal(fmt.Errorf("Connect to etcd failed, err:%v \n"), err)
	}
	return cli
}

func main() {
	cli := getClient()
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	// 创建一个1秒的租约
	resp, err := cli.Grant(context.TODO(), 1)
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Lease ID ",resp.String())

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	_, err = cli.Put(context.TODO(), "Language", "Go", clientv3.WithLease(resp.ID))
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	// get
	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	getResp, err := cli.Get(ctx, "Language")
	cancel()
	if err != nil {
		fmt.Printf("Get from etcd failed, err:%v\n", err)
		return
	}

	for _, ev := range getResp.Kvs {
		fmt.Printf("%s:%s\n", ev.Key, ev.Value)
	}
	fmt.Println("Get value successes ")

	time.Sleep(time.Second * 2)
	fmt.Println("After 2 second ")

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	getResp2, err := cli.Get(ctx, "Language")
	cancel()
	if err != nil {
		fmt.Printf("Get from etcd failed, err:%v\n", err)
		return
	}

	for _, ev := range getResp2.Kvs {
		fmt.Printf("%s:%s\n", ev.Key, ev.Value)
	}
	fmt.Println("Get value successes ")

}
```

## 其他的Lease 接口

Lease

```go
type Lease interface {
	// Grant creates a new lease.
	Grant(ctx context.Context, ttl int64) (*LeaseGrantResponse, error)

	// Revoke revokes the given lease.
	Revoke(ctx context.Context, id LeaseID) (*LeaseRevokeResponse, error)

	// TimeToLive retrieves the lease information of the given lease ID.
	TimeToLive(ctx context.Context, id LeaseID, opts ...LeaseOption) (*LeaseTimeToLiveResponse, error)

	// Leases retrieves all leases.
	Leases(ctx context.Context) (*LeaseLeasesResponse, error)

	// KeepAlive keeps the given lease alive forever. If the keepalive response
	// posted to the channel is not consumed immediately, the lease client will
	// continue sending keep alive requests to the etcd server at least every
	// second until latest response is consumed.
	//
	// The returned "LeaseKeepAliveResponse" channel closes if underlying keep
	// alive stream is interrupted in some way the client cannot handle itself;
	// given context "ctx" is canceled or timed out. "LeaseKeepAliveResponse"
	// from this closed channel is nil.
	//
	// If client keep alive loop halts with an unexpected error (e.g. "etcdserver:
	// no leader") or canceled by the caller (e.g. context.Canceled), the error
	// is returned. Otherwise, it retries.
	//
	// TODO(v4.0): post errors to last keep alive message before closing
	// (see https://github.com/coreos/etcd/pull/7866)
	KeepAlive(ctx context.Context, id LeaseID) (<-chan *LeaseKeepAliveResponse, error)

	// KeepAliveOnce renews the lease once. The response corresponds to the
	// first message from calling KeepAlive. If the response has a recoverable
	// error, KeepAliveOnce will retry the RPC with a new keep alive message.
	//
	// In most of the cases, Keepalive should be used instead of KeepAliveOnce.
	KeepAliveOnce(ctx context.Context, id LeaseID) (*LeaseKeepAliveResponse, error)

	// Close releases all resources Lease keeps for efficient communication
	// with the etcd server.
	Close() error
}
```



# Watch 



# 参考 

 etcd watch机制 http://liangjf.top/2019/12/31/110.etcd-watch%E6%9C%BA%E5%88%B6%E5%88%86%E6%9E%90/