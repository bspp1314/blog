---
title: "Map相关"
date: 2021-03-01T16:53:09+08:00
draft: true
---

- float 类型可以作为 map 的 key 吗

从语法上看，是可以的。但是从最好不要使用，英文float会有一些精度为。

还是NaN的问题。

https://www.bookstack.cn/read/qcrao-Go-Questions/map-float%20%E7%B1%BB%E5%9E%8B%E5%8F%AF%E4%BB%A5%E4%BD%9C%E4%B8%BA%20map%20%E7%9A%84%20key%20%E5%90%97.md

- map key 为什么是无序的

  1. 当map 进行扩容操作之后，key值的相对位置就会发生改变

  2. 当我们在Go遍历 map 时，并不是固定地从 0 号 bucket 开始遍历，每次都是从一个随机值序号的 bucket 开始遍历，并且是从这个 bucket 的一个随机序号的 cell 开始遍历。

- map 不是线程安全的。

  1. 在查找、赋值、遍历、删除的过程中都会检测写标志，一旦发现写标志置位（等于1），则直接 panic。赋值和删除函数在检测完写标志是复位之后，先将写标志位置位，才会进行之后的操作。
- map 的扩容过程是怎样的

  1. `装载因子超过 6.5`  扩容
  2. overflow buckets 太多 扩容
- 可以对 map 的元素取地址吗
  1. 无法对 map 的 key 或 value 进行取址，如果通过其他 hack 的方式，例如 unsafe.Pointer 等获取到了 key 或 value 的地址，也不能长期持有，因为一旦发生扩容，key 和 value 的位置就会改变，之前保存的地址也就失效了。

- 可以边遍历边删除吗
  1. 理论上可以，但是，遍历的结果就可能不会是相同的了，有可能结果遍历结果集中包含了删除的 key，也有可能不包含，这取决于删除 key 的时间：是在遍历到 key 所在的 bucket 时刻前或者后。建议不要这么操作。



[Go 语言问题集(Go Questions)](https://www.bookstack.cn/books/qcrao-Go-Questions)

