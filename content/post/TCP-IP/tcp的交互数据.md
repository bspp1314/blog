---
title: "Tcp的交互数据"
date: 2020-11-05T10:06:51+08:00
tags: ["tcp","网络"]   #[]前面要有空格
draft: false
---

在使用一些协议通讯的时候，比如Telnet，会有一个字节字节的发送的情景，每次发送一个字节的有用数据，就会产生41个字节长的分组，20个字节的IP Header 和 20个字节的TCP Header，这就导致了1个字节的有用信息要浪费掉40个字节的头部信息，这是一笔巨大的字节开销，而且这种Small packet在广域网上会增加拥塞的出现。



为了避免出现这些 Small packet 导致出现的网络拥塞，一种简单和好的方法就是采用RFC 896 [Nagle 1984]中所建议的Nagle算法。



# Nagle 算法

> 该算法要求一个TCP连接上最多只能有一个未被确认的未完成的小分组，在该分组的确认到达之前不能发送其他的小分组。相反，TCP收集这些少量的分组，并在确认到来时以一个分组的方式发出去。该算法的优越之处在于它是自适应的：确认到达得越快，数据也就发送得越快。而在希望减少微小分组数目的低速广域网上，则会发送更少的分组。
>

意思就是说当TCP发送了一个小的 Segment(小于MSS),它必须等待接收了对方的 ACK 之后，才能继续发送另一个小的 segment 。那么在等待的过程中(一个 RTT 时间)， TCP 就能尽量多地将要发送的数据收集在一起，从而减少要发送的 segment 的数量。

我们可以查看一下tcp的[源码](https://elixir.bootlin.com/linux/v3.4.113/source/net/ipv4/tcp_output.c#L1393) 

```
/* Return 0, if packet can be sent now without violation Nagle's rules:
 * 1. It is full sized.
 * 2. Or it contains FIN. (already checked by caller)
 * 3. Or TCP_CORK is not set, and TCP_NODELAY is set.
 * 4. Or TCP_CORK is not set, and all sent packets are ACKed.
 *    With Minshall's modification: all sent small packets are ACKed.
 */
static inline int tcp_nagle_check(const struct tcp_sock *tp,
				  const struct sk_buff *skb,
				  unsigned mss_now, int nonagle)
{
	return skb->len < mss_now &&
		((nonagle & TCP_NAGLE_CORK) ||
		 (!nonagle && tp->packets_out && tcp_minshall_check(tp)));
}
```



# 实验

server 端代码

```go
func main() {
	address := "0.0.0.0:7099"

	// Create a listening socket.
	l, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatal(err)
	}
	defer l.Close()

	for {
		// Accept new connections.
		c, err := l.Accept()
		if err != nil {
			log.Println(err)
			return
		}

		// Process newly accepted connection.
		go handleConnection(c)
	}
}


func handleConnection(c net.Conn) {
	fmt.Printf("Serving %s\n", c.RemoteAddr().String())

	for {
		// Read what has been sent from the client.
		netData, err := ioutil.ReadAll(c)
		if err != nil {
			log.Println(err)
			return
		}

		if len(netData) == 0 {
			break
		}else{
			c.Write([]byte("Hello"))
			log.Printf("%s\n",string(netData))
		}
	}
	c.Close()
}
```

Client 端代码

```go
func main() {
	address := "0.0.0.0:7099"

	raddr, err := net.ResolveTCPAddr("tcp", address)
	if err != nil {
		log.Fatal(err)
	}

	// Establish a connection with the server.
	conn, err := net.DialTCP("tcp", nil, raddr)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	if err != nil {
		log.Println(err)
	}

	fmt.Println("Sending Gophers down the pipe...")

	for i := 0; i < 5; i++ {
		_, err = conn.Write([]byte("GOPHER"))
		if err != nil {
			log.Fatal(err)
		}else{
			log.Println("Send Data Success")
		}
	}
}

```



开启tcpdump 监控

```shell
tcpdump -X  -i lo0 'port 7099'
```

由于golang 的 Nagle 算法默认关闭的，所以我们可以看到报文都是一个一个发送的。

```shell
10:42:19.419422 IP localhost.60313 > localhost.lazy-ptop: Flags [P.], seq 13:19, ack 1, win 6379, options [nop,nop,TS val 802739245 ecr 802739245], length 6
        0x0000:  4500 003a 0000 4000 4006 0000 7f00 0001  E..:..@.@.......
        0x0010:  7f00 0001 eb99 1bbb a9ce 611a 88e2 a41a  ..........a.....
        0x0020:  8018 18eb fe2e 0000 0101 080a 2fd8 d42d  ............/..-
        0x0030:  2fd8 d42d 474f 5048 4552                 /..-GOPHER
10:42:19.419432 IP localhost.lazy-ptop > localhost.60313: Flags [.], ack 19, win 6379, options [nop,nop,TS val 802739245 ecr 802739245], length 0
        0x0000:  4500 0034 0000 4000 4006 0000 7f00 0001  E..4..@.@.......
        0x0010:  7f00 0001 1bbb eb99 88e2 a41a a9ce 6120  ..............a.
        0x0020:  8010 18eb fe28 0000 0101 080a 2fd8 d42d  .....(....../..-
        0x0030:  2fd8 d42d                                /..-
10:42:19.419451 IP localhost.60313 > localhost.lazy-ptop: Flags [P.], seq 19:25, ack 1, win 6379, options [nop,nop,TS val 802739245 ecr 802739245], length 6
        0x0000:  4500 003a 0000 4000 4006 0000 7f00 0001  E..:..@.@.......
        0x0010:  7f00 0001 eb99 1bbb a9ce 6120 88e2 a41a  ..........a.....
        0x0020:  8018 18eb fe2e 0000 0101 080a 2fd8 d42d  ............/..-
        0x0030:  2fd8 d42d 474f 5048 4552                 /..-GOPHER
10:42:19.419461 IP localhost.lazy-ptop > localhost.60313: Flags [.], ack 25, win 6379, options [nop,nop,TS val 802739245 ecr 802739245], length 0
        0x0000:  4500 0034 0000 4000 4006 0000 7f00 0001  E..4..@.@.......
        0x0010:  7f00 0001 1bbb eb99 88e2 a41a a9ce 6126  ..............a&
        0x0020:  8010 18eb fe28 0000 0101 080a 2fd8 d42d  .....(....../..-
        0x0030:  2fd8 d42d                                /..-
10:42:19.419479 IP localhost.60313 > localhost.lazy-ptop: Flags [P.], seq 25:31, ack 1, win 6379, options [nop,nop,TS val 802739245 ecr 802739245], length 6
        0x0000:  4500 003a 0000 4000 4006 0000 7f00 0001  E..:..@.@.......
        0x0010:  7f00 0001 eb99 1bbb a9ce 6126 88e2 a41a  ..........a&....
        0x0020:  8018 18eb fe2e 0000 0101 080a 2fd8 d42d  ............/..-
        0x0030:  2fd8 d42d 474f 5048 4552                 /..-GOPHER
10:42:19.419489 IP localhost.lazy-ptop > localhost.60313: Flags [.], ack 31, win 6379, options [nop,nop,TS val 802739245 ecr 802739245], length 0
        0x0000:  4500 0034 0000 4000 4006 0000 7f00 0001  E..4..@.@.......
        0x0010:  7f00 0001 1bbb eb99 88e2 a41a a9ce 612c  ..............a,
        0x0020:  8010 18eb fe28 0000 0101 080a 2fd8 d42d  .....(....../..-
        0x0030:  2fd8 d42d                                /..-

```

修改client 代码如下

```
func main() {
	address := "0.0.0.0:7099"

	raddr, err := net.ResolveTCPAddr("tcp", address)
	if err != nil {
		log.Fatal(err)
	}

	// Establish a connection with the server.
	conn, err := net.DialTCP("tcp", nil, raddr)
	if err != nil {
		log.Fatal(err)
	}
	conn.SetNoDelay(false)
	defer conn.Close()
	if err != nil {
		log.Println(err)
	}

	fmt.Println("Sending Gophers down the pipe...")

	for i := 0; i < 5; i++ {
		_, err = conn.Write([]byte("GOPHER"))
		if err != nil {
			log.Fatal(err)
		}else{
			log.Println("Send Data Success")
		}
	}
}

```

我们在运行client代码就会发送小数据被合并成一个包发送了

```
10:45:07.687059 IP localhost.60705 > localhost.lazy-ptop: Flags [P.], seq 19:31, ack 1, win 6379, options [nop,nop,TS val 802906389 ecr 802906389], length 12
        0x0000:  4500 0040 0000 4000 4006 0000 7f00 0001  E..@..@.@.......
        0x0010:  7f00 0001 ed21 1bbb 0cac c40f 0dc9 5c81  .....!........\.
        0x0020:  8018 18eb fe34 0000 0101 080a 2fdb 6115  .....4....../.a.
        0x0030:  2fdb 6115 474f 5048 4552 474f 5048 4552  /.a.GOPHERGOPHER
10:45:07.687064 IP localhost.lazy-ptop > localhost.60705: Flags [.], ack 31, win 6379, options [nop,nop,TS val 802906389 ecr 802906389], length 0
        0x0000:  4500 0034 0000 4000 4006 0000 7f00 0001  E..4..@.@.......
        0x0010:  7f00 0001 1bbb ed21 0dc9 5c81 0cac c41b  .......!..\.....
        0x0020:  8010 18eb fe28 0000 0101 080a 2fdb 6115  .....(....../.a.
        0x0030:  2fdb 6115                                /.a.
10:45:07.687068 IP localhost.60705 > localhost.lazy-ptop: Flags [F.], seq 31, ack 1, win 6379, options [nop,nop,TS val 802906389 ecr
```










参考 

TCP之Nagle算法&&延迟ACK  https://www.cnblogs.com/williamjie/p/9390308.html

 TCP Nagle算法&&延迟确认机制 (https://my.oschina.net/xinxingegeya/blog/485643) https://my.oschina.net/xinxingegeya/blog/485643

19章 TCP的交互数据流 http://docs.52im.net/extend/docs/book/tcpip/vol1/19/

TCP-IP详解：Nagle算法 https://blog.csdn.net/wdscq1234/article/details/52432095

什么是 Nagle 算法  https://www.zhuxiaodong.net/2018/tcp-nagle-tcp_nodelay-tcp_nopush-instruction/

一篇带你读懂TCP之“滑动窗口”协议 https://juejin.im/post/6844903809995505671

