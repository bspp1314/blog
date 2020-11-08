---
title: "Redis源码阅读之sds"
date: 2020-11-06T17:50:42+08:00
draft: false
---

## 什么是sds

字符串是Redis中最为常见的数据存储类型，其底层实现是简单动态字符串sds(simple dynamic string)，是可以修改的字符串。

它类似于Golang中的Slice，它采用预分配冗余空间的方式来减少内存的频繁分配。

# sds 的结构

```c
/* Note: sdshdr5 is never used, we just access the flags byte directly.
 * However is here to document the layout of type 5 SDS strings. */
struct __attribute__ ((__packed__)) sdshdr5 {
    unsigned char flags; /* 3 lsb of type, and 5 msb of string length */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr8 {
    uint8_t len; /* used 已用容量 */ 
    uint8_t alloc; /* excluding the header and null terminator 已经分配的容量 */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr16 {
    uint16_t len; /* used */
    uint16_t alloc; /* excluding the header and null terminator */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr32 {
    uint32_t len; /* used */
    uint32_t alloc; /* excluding the header and null terminator */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
struct __attribute__ ((__packed__)) sdshdr64 {
    uint64_t len; /* used */
    uint64_t alloc; /* excluding the header and null terminator */
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};

#define SDS_TYPE_5  0
#define SDS_TYPE_8  1
#define SDS_TYPE_16 2
#define SDS_TYPE_32 3
#define SDS_TYPE_64 4
```

SDS一共有5种类型的header。目的是节省内存。

一个SDS字符串的完整结构，由在内存地址上前后相邻的两部分组成：

- 一个header。通常包含字符串的长度(len)、最大容量(alloc)和flags。sdshdr5有所不同。

- len: 表示字符串的真正长度（不包含NULL结束符在内）。

- alloc: 表示字符串的最大容量（不包含最后多余的那个字节）。

- flags: 总是占用一个字节。其中的最低3个bit用来表示header的类型。

- char:字符数组。这个字符数组的长度等于最大容量+1。真正有效的字符串数据，其长度通常小于最大容量。在真正的字符串数据之后，是空余未用的字节（一般以字节0填充），允许在不重新分配内存的前提下让字符串数据向后做有限的扩展。在真正的字符串数据之后，还有一个NULL结束符，即ASCII码为0的’\0’字符。这是为了和传统C字符串兼容。之所以字符数组的长度比最大容量多1个字节，就是为了在字符串长度达到最大容量时仍然有1个字节存放NULL结束符。

  

`__attribute__ ((__packed__))`这个声明就是用来告诉编译器取消内存对齐优化，按照实际的占用字节数进行对齐

```c
printf("%ld\n", sizeof(struct sdshdr8));  // 3
printf("%ld\n", sizeof(struct sdshdr16)); // 5
printf("%ld\n", sizeof(struct sdshdr32)); // 9
printf("%ld\n", sizeof(struct sdshdr64)); // 17
```

通过加上`__attribute__ ((__packed__))`声明，sdshdr16节省了1个字节，sdshdr32节省了3个字节，sdshdr64节省了7个字节。

**但是内存不对齐怎么办呢，不能为了一点内存大大拖慢cpu的寻址效率啊？redis 通过自己在malloc等c语言内存分配函数上封装了一层zmalloc，将内存分配收敛，并解决了内存对齐的问题**。在内存分配前有这么一段代码：

```c
if (_n&(sizeof(long)-1)) _n += sizeof(long)-(_n&(sizeof(long)-1)); \    // 确保内存对齐！
```



# 创建一个sds 

```c
sds sdsnewlen(const void *init, size_t initlen) {
    void *sh;
    sds s;
    char type = sdsReqType(initlen); //获取需要分配的类型
    /* Empty strings are usually created in order to append. Use type 8
     * since type 5 is not good at this. */
 
    if (type == SDS_TYPE_5 && initlen == 0) type = SDS_TYPE_8;
    // 获取sds 头部的大小
    int hdrlen = sdsHdrSize(type);
    unsigned char *fp; /* flags pointer. */
    // 分配内存 
    sh = s_malloc(hdrlen+initlen+1);   // 分配空间大小为 sdshdr大小+字符串长度+1
    if (sh == NULL) return NULL;
  if (!init)
        memset(sh, 0, hdrlen+initlen+1);// 初始化内存空间
    s = (char*)sh+hdrlen;
    fp = ((unsigned char*)s)-1;// 获取flags指针
    switch(type) {
        case SDS_TYPE_5: {
            *fp = type | (initlen << SDS_TYPE_BITS);
            break;
        }
        case SDS_TYPE_8: {
            SDS_HDR_VAR(8,s);// 表示根据s，定义指针sh，并初始化指向实际sds的起始地址
            sh->len = initlen; // 设置len
            sh->alloc = initlen;// 设置alloc
            *fp = type;// 设置type
            break;
        }
        case SDS_TYPE_16: {
            SDS_HDR_VAR(16,s);
            sh->len = initlen;
            sh->alloc = initlen;
            *fp = type;
            break;
        }
        case SDS_TYPE_32: {
            SDS_HDR_VAR(32,s);
            sh->len = initlen;
            sh->alloc = initlen;
            *fp = type;
            break;
        }
        case SDS_TYPE_64: {
            SDS_HDR_VAR(64,s);
            sh->len = initlen;
            sh->alloc = initlen;
            *fp = type;
            break;
        }
    }
    if (initlen && init)
        memcpy(s, init, initlen);//// 内存拷贝字字符数组赋值
    s[initlen] = '\0';// 字符数组最后一位设为\0
    return s;
}

```



# 参考 

关于redis中SDS简单动态字符串 https://www.cnblogs.com/chenpingzhao/p/7292182.html

Redis 源码分析(一) ：sds https://www.jianshu.com/p/62a7cb9c3474

