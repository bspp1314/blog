---
title: "Redis源码阅读之ziplist"
date: 2020-12-11T18:03:51+08:00
draft: true
---

# 什么是ziplist 

```
The ziplist is a specially encoded dually linked list that is designed
to be very memory efficient. It stores both strings and integer values,
where integers are encoded as actual integers instead of a series of
characters. It allows push and pop operations on either side of the list
in O(1) time. However, because every operation requires a reallocation of
the memory used by the ziplist, the actual complexity is related to the
amount of memory used by the ziplist.
```

ziplist 的内存结构
```
<zlbytes><zltail><zllen><entry>...<entry><zlend>
```
- zlbytes: ziplist 占用的字节总数
- zltail: 表示ziplist表中最后一项（entry）在ziplist中的偏移字节数。zltail的存在，使得我们可以很方便地找到最后一项（不用遍历整个ziplist），从而可以在ziplist尾端快速地执行push或pop操作。
- zlen entry 的数据
- entry 表示真正存放数据的数据项，长度不定。
- zlend: ziplist最后1个字节，是一个结束标记，值固定等于255。

entry 的结构
```
<prevlen> <encoding> <entry-data>
```
- prevlen 示前一个数据项占用的总字节数。相当于普通双向链表里的 pre pointer .
- encoding  表示当前数据项的数据长度（即entry-data部分的长度）。也采用变长编码。
-  entry-data 实际的数据

prevlen的编码格式

> The length of the previous entry, <prevlen>, is encoded in the following way:
> If this length is smaller than 254 bytes, it will only consume a single
> byte representing the length as an unsinged 8 bit integer. When the length
> is greater than or equal to 254, it will consume 5 bytes. The first byte is
> set to 254 (FE) to indicate a larger value is following. The remaining 4
> bytes take the length of the previous entry as value.
> So practically an entry is encoded in the following way:


```c
<prevlen from 0 to 253> <encoding> <entry>
```

prelen总共有两种编码方式

- 如果前一个entry的长度小于254，prelen英纳格1byte表示
- 如果前一个entry大于254，那就用5个byte 其中第一个字节的值为254。后4个字节表示长度。

为什么没有255？

255已经定义为ziplist结束标记`<zlend>`的值了。在ziplist的很多操作的实现中，都会根据数据项的第1个字节是不是255来判断当前是不是到达ziplist的结尾了，因此一个正常的数据的第1个字节（也就是`<prevrawlen>`的第1个字节）是不能够取255这个值的，否则就冲突了。



而`<len>`字段就更加复杂了，它根据第1个字节的不同，总共分为9种情况（下面的表示法是按二进制表示）：

```c
 /*
 * |00pppppp| - 1 byte
 *      String value with length less than or equal to 63 bytes (6 bits).
 *      "pppppp" represents the unsigned 6 bit length.
 * |01pppppp|qqqqqqqq| - 2 bytes
 *      String value with length less than or equal to 16383 bytes (14 bits).
 *      IMPORTANT: The 14 bit number is stored in big endian.
 * |10000000|qqqqqqqq|rrrrrrrr|ssssssss|tttttttt| - 5 bytes
 *      String value with length greater than or equal to 16384 bytes.
 *      Only the 4 bytes following the first byte represents the length
 *      up to 2^32-1. The 6 lower bits of the first byte are not used and
 *      are set to zero.
 *      IMPORTANT: The 32 bit number is stored in big endian.
 * |11000000| - 3 bytes
 *      Integer encoded as int16_t (2 bytes).
 * |11010000| - 5 bytes
 *      Integer encoded as int32_t (4 bytes).
 * |11100000| - 9 bytes
 *      Integer encoded as int64_t (8 bytes).
 * |11110000| - 4 bytes
 *      Integer encoded as 24 bit signed (3 bytes).
 * |11111110| - 2 bytes
 *      Integer encoded as 8 bit signed (1 byte).
 * |1111xxxx| - (with xxxx between 0001 and 1101) immediate 4 bit integer.
 *      Unsigned integer from 0 to 12. The encoded value is actually from
 *      1 to 13 because 0000 and 1111 can not be used, so 1 should be
 *      subtracted from the encoded 4 bit value to obtain the right value.
 * |11111111| - End of ziplist special entry.
 *
 * Like for the ziplist header, all the integers are represented in little
 * endian byte order, even when this code is compiled in big endian systems.
 *
 * EXAMPLES OF ACTUAL ZIPLISTS
 * ===========================
 **/
```



- |00pppppp| 如果第一个字节最高两位是00,那么len只有一个字节，，剩余的6个bit用来表示长度值，最高可以表示63 $ (2^6-1) $。
- |01pppppp|qqqqqqqq| 如果第一个字节最高位是01，那么len可以有2个字节，剩余的14个bit用来表示长度值，最高可以表示16383 $ (2^{14}-1) $。
- |10000000|qqqqqqqq|rrrrrrrr|ssssssss|tttttttt| 如果第一个字节最高位是10000000，那len可以有4个字节，剩余的32个bit用来表示长度值，最高可以表示$ (2^{32}-1) $。
- |11000000|  len字段占用1个字节,，后面的数据data存储为2个字节的int16_t类型。
- |11010000| len字段占用1个字节,，后面的数据data存储为4个字节的int32_t类型。
- |111100000| len字段占用1个字节,，后面的数据data存储为4个字节的int64_t类型。
- |11110000|   len字段占用1个字节,，后面的数据data存储为3个字节的整数类型。
- |11111110|    len字段占用1个字节,，后面的数据data存储为1个字节的整数类型。
- |1111xxxx| - - (xxxx的值在0001和1101之间)。这是一种特殊情况，xxxx从1到13一共13个值，这时就用这13个值来表示真正的数据。

# ziplist的接口实现

```c
unsigned char *ziplistNew(void);
unsigned char *ziplistMerge(unsigned char **first, unsigned char **second);
unsigned char *ziplistPush(unsigned char *zl, unsigned char *s, unsigned int slen, int where);
unsigned char *ziplistIndex(unsigned char *zl, int index);
unsigned char *ziplistNext(unsigned char *zl, unsigned char *p);
unsigned char *ziplistPrev(unsigned char *zl, unsigned char *p);
unsigned int ziplistGet(unsigned char *p, unsigned char **sval, unsigned int *slen, long long *lval);
unsigned char *ziplistInsert(unsigned char *zl, unsigned char *p, unsigned char *s, unsigned int slen);
unsigned char *ziplistDelete(unsigned char *zl, unsigned char **p);
unsigned char *ziplistDeleteRange(unsigned char *zl, int index, unsigned int num);
unsigned int ziplistCompare(unsigned char *p, unsigned char *s, unsigned int slen);
unsigned char *ziplistFind(unsigned char *p, unsigned char *vstr, unsigned int vlen, unsigned int skip);
unsigned int ziplistLen(unsigned char *zl);
size_t ziplistBlobLen(unsigned char *zl);
void ziplistRepr(unsigned char *zl);
```

# ziplistNew



# 参考

Redis内部数据结构详解(4)——ziplist https://mp.weixin.qq.com/s?__biz=MzA4NTg1MjM0Mg==&mid=2657261265&idx=1&sn=e105c4b86a5640c5fc8212cd824f750b&scene=21#wechat_redirect