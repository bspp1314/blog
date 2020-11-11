---
title: "Redis源码阅读之sds"
date: 2020-11-06T17:50:42+08:00
draft: true
categories: ["redis"]
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



sds 扩容

```c
/* Enlarge the free space at the end of the sds string so that the caller
 * is sure that after calling this function can overwrite up to addlen
 * bytes after the end of the string, plus one more byte for nul term.
 *
 * Note: this does not change the *length* of the sds string as returned
 * by sdslen(), but only the free buffer space we have. */
sds sdsMakeRoomFor(sds s, size_t addlen) {
    void *sh, *newsh;
    size_t avail = sdsavail(s);
    size_t len, newlen;
    char type, oldtype = s[-1] & SDS_TYPE_MASK;
    int hdrlen;

    /* Return ASAP if there is enough space left. */
    if (avail >= addlen) return s;

    len = sdslen(s);
    sh = (char*)s-sdsHdrSize(oldtype);
    newlen = (len+addlen);
    // 计算需要扩容的大小，如果不超过1M，直接newlen * 2,如果超过1M newLen += 1M
    if (newlen < SDS_MAX_PREALLOC)
        newlen *= 2;
    else
        newlen += SDS_MAX_PREALLOC;

    //计算扩容后的sds的类型
    type = sdsReqType(newlen);

    /* Don't use type 5: the user is appending to the string and type 5 is
     * not able to remember empty space, so sdsMakeRoomFor() must be called
     * at every appending operation. */
    if (type == SDS_TYPE_5) type = SDS_TYPE_8;

    hdrlen = sdsHdrSize(type);
    if (oldtype==type) {
        //扩容
        newsh = s_realloc(sh, hdrlen+newlen+1);
        if (newsh == NULL) {
            s_free(sh);
            return NULL;
        }
        s = (char*)newsh+hdrlen;
    } else {
        //重新分配
        /* Since the header size changes, need to move the string forward,
         * and can't use realloc */
        newsh = s_malloc(hdrlen+newlen+1);
        if (newsh == NULL) return NULL;
        memcpy((char*)newsh+hdrlen, s, len+1);
        s_free(sh);
        s = (char*)newsh+hdrlen;
        s[-1] = type;
        sdssetlen(s, len);
    }
    sdssetalloc(s, newlen);
    return s;
}
```

库容的策略

- 计算剩余容量
  剩余容量等于`sh->alloc - sh->len` 如果剩余长度大于需要增加的长度，则直接返回
- 计算扩容大小
  新的空间和 `SDS_MAX_PREALLOC` 1024*1024进行比较
  如果没超过1Mb ，则扩容空间大小为 该字符串长度的2倍 `2 * newlen`
  如果超过1Mb，则增加1Mb大小。
  所以字符串扩容最大只能更增加1Mb
- 内存分配
  `newLen` = 新增`addLen` + 原长度`len` 算出sds的类型
  如果新类型=原类型，则进行调整内存大小 为`hdrlen+newlen+1`
  如果新类型 不等于 原类型 内存进行重新分配，创建新的内存块 大小为`hdrlen+newlen+1`，释放旧的地址空间，将新的字符串写入新空间
  设置字符串的容量`sdssetalloc`

释放sds未使用的内存

```c
/* Reallocate the sds string so that it has no free space at the end. The
 * contained string remains not altered, but next concatenation operations
 * will require a reallocation.
 *
 * After the call, the passed sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call. */
sds * Reallocate the sds string so that it has no free space at the end. The
 * contained string remains not altered, but next concatenation operations
 * will require a reallocation.
 *
 * After the call, the passed sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call. */
sds sdsRemoveFreeSpace(sds s) {
    void *sh, *newsh;
  	// 获取sds的type,sds 指针指向 char 数组
    char type, oldtype = s[-1] & SDS_TYPE_MASK;
    int hdrlen, oldhdrlen = sdsHdrSize(oldtype);
    size_t len = sdslen(s);
    size_t avail = sdsavail(s);
    sh = (char*)s-oldhdrlen;

    /* Return ASAP if there is no space left. */
  	//可用区域为0 
    if (avail == 0) return s;

    /* Check what would be the minimum SDS header that is just good enough to
     * fit this string. */
    type = sdsReqType(len);
    hdrlen = sdsHdrSize(type);

    /* If the type is the same, or at least a large enough type is still
     * required, we just realloc(), letting the allocator to do the copy
     * only if really needed. Otherwise if the change is huge, we manually
     * reallocate the string to use the different header type. */
 
   //如果类型一样，则调整sds的大小为len+hrdlen+1
    if (oldtype==type || type > SDS_TYPE_8) {
        newsh = s_realloc(sh, oldhdrlen+len+1);
        if (newsh == NULL) return NULL;
        s = (char*)newsh+oldhdrlen;
    } else {
        newsh = s_malloc(hdrlen+len+1);
        if (newsh == NULL) return NULL;
        memcpy((char*)newsh+hdrlen, s, len+1);
        s_free(sh);
        s = (char*)newsh+hdrlen;
        s[-1] = type;
        sdssetlen(s, len);
    }
    sdssetalloc(s, len);
    return s;
}
```

在上面的分配内存，我们看到，扩容的时候，会产生`newlen*2` 或者`newlen+1Mb` 大小的内存块，但是可能会产生大量的内存浪费，在内存紧张的情况，redis 会通过`sdsRemoveFreeSpace`释放掉这些内存。

如果`sds` 实际大小 未超过 `sds` type的范围大小。则需要调整内存，否则进行创建新的内存区域，进行复制。

# 参考 

关于redis中SDS简单动态字符串 https://www.cnblogs.com/chenpingzhao/p/7292182.html

Redis 源码分析(一) ：sds https://www.jianshu.com/p/62a7cb9c3474

