---
title: "Redis源码阅读之整数集合"
date: 2020-12-09T18:25:20+08:00
draft: false
---

Set 集合采用了整数集合和字典两种方式来实现的，当满足如下两个条件的时候，采用整数集合实现；一旦有一个条件不满足时则采用字典来实现。

- **Set 集合中的所有元素都为整数**
- **Set 集合中的元素个数不大于 512（默认 512，可以通过修改 set-max-intset-entries 配置调整集合大小）** 实际不建议把 set-max-intset-entries 设置的过大，设置过大会导致集合的查询效率减低。



# 结构

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



# 插入新数据

```c
* Insert an integer in the intset */
intset *intsetAdd(intset *is, int64_t value, uint8_t *success) {
  	//获取编码格式
    uint8_t valenc = _intsetValueEncoding(value);
    uint32_t pos;
    if (success) *success = 1;

    /* Upgrade encoding if necessary. If we need to upgrade, we know that
     * this value should be either appended (if > 0) or prepended (if < 0),
     * because it lies outside the range of existing values. */
  	//需要插入的值超过现有编码的范围
    if (valenc > intrev32ifbe(is->encoding)) {
        /* This always succeeds, so we don't need to curry *success. */
        return intsetUpgradeAndAdd(is,value);
    } else {
        /* Abort if the value is already present in the set.
         * This call will populate "pos" with the right position to insert
         * the value when it cannot be found. */
      	// 集合is中已经存在value 
        if (intsetSearch(is,value,&pos)) {
            if (success) *success = 0;
            return is;
        }
			
      	//为 value 在集合中分配空间
        is = intsetResize(is,intrev32ifbe(is->length)+1);
        // 在content插入 values 
        if (pos < intrev32ifbe(is->length)) intsetMoveTail(is,pos,pos+1);
    }

  // 将新值设置到底层数组的指定位置中
    _intsetSet(is,pos,value);
  // 增一集合元素数量的计数器
    is->length = intrev32ifbe(intrev32ifbe(is->length)+1);
    return is;
}

// 升级编码且插入
static intset *intsetUpgradeAndAdd(intset *is, int64_t value) {
  	// 当前编码
    uint8_t curenc = intrev32ifbe(is->encoding);
  	// 新的编码
    uint8_t newenc = _intsetValueEncoding(value);
  	// 当前集合的元素数量
    int length = intrev32ifbe(is->length);
    // 根据 value 的值，决定是将它添加到底层数组的最前端还是最后端
    // 注意，因为 value 的编码比集合原有的其他元素的编码都要大
    // 所以 value 要么大于集合中的所有元素，要么小于集合中的所有元素
    // 因此，value 只能添加到底层数组的最前端或最后端
    int prepend = value < 0 ? 1 : 0;

    /* First set new encoding and resize */
    is->encoding = intrev32ifbe(newenc);
 	 // 根据新编码对集合（的底层数组）进行空间调整
    is = intsetResize(is,intrev32ifbe(is->length)+1);

    /* Upgrade back-to-front so we don't overwrite values.
     * Note that the "prepend" variable is used to make sure we have an empty
     * space at either the beginning or the end of the intset. */
    //移动数组
    while(length--)
        _intsetSet(is,length+prepend,_intsetGetEncoded(is,length,curenc));

    /* Set the value at the beginning or the end. */
    // 设置新值，根据 prepend 的值来决定是添加到数组头还是数组尾
  	if (prepend)
        _intsetSet(is,0,value);
    else
        _intsetSet(is,intrev32ifbe(is->length),value);
    is->length = intrev32ifbe(intrev32ifbe(is->length)+1);
    return is;
}
```




# 参考
Redis 系列（二）: 连集合底层实现原理都不知道，你敢说 Redis 用的很溜？ https://xie.infoq.cn/article/98c984f6462aec99ffc0c3b42