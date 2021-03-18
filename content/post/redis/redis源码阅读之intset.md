---
title: "Redis源码阅读之整数集合"
date: 2020-12-09T18:25:20+08:00
draft: true 
---

# intset数据结构简介



intset顾名思义，是由整数组成的集合。实际上，intset是一个由整数组成的有序集合，从而便于在上面进行二分查找，用于快速地判断一个元素是否属于这个集合。它在内存分配上与ziplist有些类似，是连续的一整块内存空间，而且对于大整数和小整数（按绝对值）采取了不同的编码，尽量对内存的使用进行了优化。


```c
typedef struct intset {
  	//编码方法
    uint32_t encoding;
  	//集合的长度
    uint32_t length;
  	//存储集合的值
    int8_t contents[];
} intset;
```

- `encoding`: 数据编码，表示intset中的每个数据元素用几个字节来存储。它有三种可能的取值：INTSET_ENC_INT16表示每个元素用2个字节存储，INTSET_ENC_INT32表示每个元素用4个字节存储，INTSET_ENC_INT64表示每个元素用8个字节存储。因此，intset中存储的整数最多只能占用64bit。
- `length`: 表示intset中的元素个数。`encoding`和`length`两个字段构成了intset的头部（header）。
- `contents`: 是一个柔性数组（[flexible array member](https://en.wikipedia.org/wiki/Flexible_array_member)），表示intset的header后面紧跟着数据元素。这个数组的总长度（即总字节数）等于`encoding * length`。柔性数组在Redis的很多数据结构的定义中都出现过（例如sds, quicklist），用于表达一个偏移量。`contents`需要单独为其分配空间，这部分内存不包含在intset结构当中。



encoding 有三种编码方式如下

```go
/* Note that these encodings are ordered, so:
 * INTSET_ENC_INT16 < INTSET_ENC_INT32 < INTSET_ENC_INT64. */
#define INTSET_ENC_INT16 (sizeof(int16_t)) //16位
#define INTSET_ENC_INT32 (sizeof(int32_t)) //32位
#define INTSET_ENC_INT64 (sizeof(int64_t)) //64位

/* Return the required encoding for the provided value. */
static uint8_t _intsetValueEncoding(int64_t v) {
    if (v < INT32_MIN || v > INT32_MAX)
        return INTSET_ENC_INT64;
    else if (v < INT16_MIN || v > INT16_MAX)
        return INTSET_ENC_INT32;
    else
        return INTSET_ENC_INT16;
}
```



# ![](redis_intset_add_example.png)



# 关键操作

## intSetFind

由于intset是一个本质上是一个有序的数组，所以其查找是使用的二分法查询，其代码如下


```c
/* Determine whether a value belongs to this set */
uint8_t intsetFind(intset *is, int64_t value) {
    uint8_t valenc = _intsetValueEncoding(value);
  //如果value所需的数据编码比当前intset的编码要大，则它肯定在当前intset所能存储的数据范围之外（特别大或特别小），所以这时会直接返回0；否则调用intsetSearch执行一个二分查找算法。
    return valenc <= intrev32ifbe(is->encoding) && intsetSearch(is,value,NULL);
}

/* Search for the position of "value". Return 1 when the value was found and
 * sets "pos" to the position of the value within the intset. Return 0 when
 * the value is not present in the intset and sets "pos" to the position
 * where "value" can be inserted. */
static uint8_t intsetSearch(intset *is, int64_t value, uint32_t *pos) {
    int min = 0, max = intrev32ifbe(is->length)-1, mid = -1;
    int64_t cur = -1;

    /* The value can never be found when the set is empty */
    if (intrev32ifbe(is->length) == 0) {
        if (pos) *pos = 0;
        return 0;
    } else {
        /* Check for the case where we know we cannot find the value,
         * but do know the insert position. */
        if (value > _intsetGet(is,max)) {
            if (pos) *pos = intrev32ifbe(is->length);
            return 0;
        } else if (value < _intsetGet(is,0)) {
            if (pos) *pos = 0;
            return 0;
        }
    }

    while(max >= min) {
        mid = ((unsigned int)min + (unsigned int)max) >> 1;
        cur = _intsetGet(is,mid);
        if (value > cur) {
            min = mid+1;
        } else if (value < cur) {
            max = mid-1;
        } else {
            break;
        }
    }

    if (value == cur) {
        if (pos) *pos = mid;
        return 1;
    } else {
        if (pos) *pos = min;
        return 0;
    }
}

```



## intsetAdd 

```c
/* Insert an integer in the intset */
intset *intsetAdd(intset *is, int64_t value, uint8_t *success) {
    uint8_t valenc = _intsetValueEncoding(value);
    uint32_t pos;
  	// 
    if (success) *success = 1;

    /* Upgrade encoding if necessary. If we need to upgrade, we know that
     * this value should be either appended (if > 0) or prepended (if < 0),
     * because it lies outside the range of existing values. */
    if (valenc > intrev32ifbe(is->encoding)) {
      	// 
        /* This always succeeds, so we don't need to curry *success. */
        return intsetUpgradeAndAdd(is,value);
    } else {
        /* Abort if the value is already present in the set.
         * This call will populate "pos" with the right position to insert
         * the value when it cannot be found. */
        if (intsetSearch(is,value,&pos)) {
            if (success) *success = 0;
            return is;
        }

        is = intsetResize(is,intrev32ifbe(is->length)+1);
        if (pos < intrev32ifbe(is->length)) intsetMoveTail(is,pos,pos+1);
    }

    _intsetSet(is,pos,value);
    is->length = intrev32ifbe(intrev32ifbe(is->length)+1);
    return is;
}
```

1. intsetAdd在intset中添加新元素value。如果value在添加前已经存在，则不会重复添加，这时参数success被置为0；如果value在原来intset中不存在，则将value插入到适当位置，这时参数success被置为0。

2. 如果要添加的元素`value`所需的数据编码比当前intset的编码要大，那么则调用`intsetUpgradeAndAdd`将intset的编码进行升级后再插入`value`。
3. 调用`intsetSearch`，如果能查到，则不会重复添加。
4. 如果没查到，则调用`intsetResize`对intset进行内存扩充，使得它能够容纳新添加的元素。因为intset是一块连续空间，因此这个操作会引发内存的`realloc`（参见http://man.cx/realloc）。这有可能带来一次数据拷贝。同时调用`intsetMoveTail`将待插入位置后面的元素统一向后移动1个位置，这也涉及到一次数据拷贝。值得注意的是，在`intsetMoveTail`中是调用`memmove`完成这次数据拷贝的。`memmove`保证了在拷贝过程中不会造成数据重叠或覆盖，
5. `intsetUpgradeAndAdd`的实现中也会调用`intsetResize`来完成内存扩充。在进行编码升级时，`intsetUpgradeAndAdd`的实现会把原来intset中的每个元素取出来，再用新的编码重新写入新的位置。
6. 注意一下`intsetAdd`的返回值，它返回一个新的intset指针。它可能与传入的intset指针`is`相同，也可能不同。调用方必须用这里返回的新的intset，替换之前传进来的旧的intset变量。类似这种接口使用模式，在Redis的实现代码中是很常见的，比如我们之前在介绍[sds](http://zhangtielei.com/posts/blog-redis-sds.html)和[ziplist](http://zhangtielei.com/posts/blog-redis-ziplist.html)的时候都碰到过类似的情况。
7. 显然，这个`intsetAdd`算法总的时间复杂度为O(n)。




# 参考

Redis内部数据结构详解(7)——intset http://zhangtielei.com/posts/blog-redis-intset.html

