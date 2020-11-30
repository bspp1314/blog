---
title: "Redis源码阅读之dict"
date: 2020-11-17T18:55:13+08:00
draft: true
---

在 Redis 中，dict 的代码存放在`src/dict.c`和`src/dict.h`两个文件中。在`src/dict.h`中定义了 dict 所用到的结构体，一共有四个:

```c
typedef struct dict {
    dictType *type; // dict类型
    void *privdata; // 保存类型特定函数需要使用的参数 
    dictht ht[2];   // 保存的两个哈希表，ht[0]是真正使用的，ht[1]会在rehash时使用 
    long rehashidx; /* rehashing not in progress if rehashidx == -1 */
    unsigned long iterators; /* number of iterators currently running */
} dict;

// hash表结构
typedef struct dictht {
    dictEntry **table;// hash 表节点数组
    unsigned long size; // hash 表大小
    unsigned long sizemask;// 哈希表大小掩码，用于计算哈希表的索引值，大小总是dictht.size - 1 
    unsigned long used;//哈希表已经使用的节点数量
} dictht;


typedef struct dictType {
    uint64_t (*hashFunction)(const void *key);// 哈希函数
    void *(*keyDup)(void *privdata, const void *key);// 复制key 函数
    void *(*valDup)(void *privdata, const void *obj);// 复制val 函数
    int (*keyCompare)(void *privdata, const void *key1, const void *key2);//key 值比较函数
    void (*keyDestructor)(void *privdata, void *key);// key 值回收
    void (*valDestructor)(void *privdata, void *obj);// value 值回收
} dictType;

//保存一连串操作特定类型键值对的函数 */

//哈希表节点 
typedef struct dictEntry {
    void *key; // key 值
    union {
        void *val; // value 值
        uint64_t u64;
        int64_t s64;
        double d;
    } v;
    struct dictEntry *next;// 下一个节点
} dictEntry;
```

其结构大致如下

![image-20201120164455428](image-20201120164455428.png)

# 创建 dict

```go
/* Create a new hash table */
dict *dictCreate(dictType *type,
        void *privDataPtr)
{
  	//分配内存
    dict *d = zmalloc(sizeof(*d));

  	//初始化
    _dictInit(d,type,privDataPtr);
    return d;
}

/* Initialize the hash table */
int _dictInit(dict *d, dictType *type,
        void *privDataPtr)
{
  	//重置dict 
    _dictReset(&d->ht[0]);
    _dictReset(&d->ht[1]);
  	//设置类型
    d->type = type;
  	//保存类型特定函数需要使用的参数
    d->privdata = privDataPtr;
    d->rehashidx = -1;
    d->iterators = 0;
    return DICT_OK;
}
```

# 查找

```c
dictEntry *dictFind(dict *d, const void *key)
{
    dictEntry *he;
    uint64_t h, idx, table;

  	//字段的大小为0 
    if (dictSize(d) == 0) return NULL; /* dict is empty */
  //如果当前正在进行重哈希，那么将重哈希过程向前推进一步（即调用_dictRehashStep）。实际上，除了查找，插入和删除也都会触发这一动作。这就将重哈希过程分散到各个查找、插入和删除操作中去了，而不是集中在某一个操作中一次性做完。
    if (dictIsRehashing(d)) _dictRehashStep(d);
   
  //计算hash值
 	 h = dictHashKey(d, key);
    for (table = 0; table <= 1; table++) {
       //计算key 所在bucket的位置
       idx = h & d->ht[table].sizemask;
        he = d->ht[table].table[idx];
      	//遍历链表
        while(he) {
            if (key==he->key || dictCompareKeys(d, key, he->key))
                return he;
            he = he->next;
        }
      	//不处于rehash 状态，就不需要查找第二个表
        if (!dictIsRehashing(d)) return NULL;
    }
    return NULL;
}


```

- 如果当前正在进行重哈希，那么将重哈希过程向前推进一步（即调用_dictRehashStep）。实际上，除了查找，插入和删除也都会触发这一动作。这就将重哈希过程分散到各个查找、插入和删除操作中去了，而不是集中在某一个操作中一次性做完。
- 计算key的哈希值（调用dictHashKey，里面的实现会调用前面提到的hashFunction）。
- 先在第一个哈希表ht[0]上进行查找。在table数组上定位到哈希值对应的位置（如前所述，通过哈希值与sizemask进行按位与），然后在对应的dictEntry链表上进行查找。查找的时候需要对key进行比较，这时候调用dictCompareKeys，它里面的实现会调用到前面提到的keyCompare。如果找到就返回该项。否则，进行下一步。
- 判断当前是否在重哈希，如果没有，那么在ht[0]上的查找结果就是最终结果（没找到，返回NULL）。否则，在ht[1]上进行查找（过程与上一步相同）。‘



# 添加key-value 到字典

dictAdd插入新的一对key和value，如果key已经存在，则插入失败。

dictReplace也是插入一对key和value，不过在key存在的时候，它会更新value。

```c
/* Add an element to the target hash table */
int dictAdd(dict *d, void *key, void *val)
{
    dictEntry *entry = dictAddRaw(d,key,NULL);

    if (!entry) return DICT_ERR;
    dictSetVal(d, entry, val);
    return DICT_OK;
}



dictEntry *dictAddRaw(dict *d, void *key, dictEntry **existing)
{
    long index;
    dictEntry *entry;
    dictht *ht;

  	//是否处于reshash过程，rehash的相关在后面在分析
    if (dictIsRehashing(d)) _dictRehashStep(d);

    /* Get the index of the new element, or -1 if
     * the element already exists. */
   //
    if ((index = _dictKeyIndex(d, key, dictHashKey(d,key), existing)) == -1)
        return NULL;

    /* Allocate the memory and store the new entry.
     * Insert the element in top, with the assumption that in a database
     * system it is more likely that recently added entries are accessed
     * more frequently. */
  	//果正在重哈希中，它会把数据插入到ht[1]；否则插入到ht[0]。
    ht = dictIsRehashing(d) ? &d->ht[1] : &d->ht[0];
    entry = zmalloc(sizeof(*entry));
    entry->next = ht->table[index];
 // 在对应的bucket中插入数据的时候，总是插入到dictEntry的头部。因为新数据接下来被访问的概率可能比较高，这样再次查找它时就比较次数较少。
    ht->table[index] = entry;
    ht->used++;

    /* Set the hash entry fields. */
  	//设置Value 
    dictSetKey(d, entry, key);
    return entry;
}

//查找key值需要插入的位置，如果存在
static int _dictKeyIndex(dict *d, const void *key)
{
    unsigned int h, idx, table;
    dictEntry *he;

    /* Expand the hash table if needed */
    if (_dictExpandIfNeeded(d) == DICT_ERR)
        return -1;
    /* Compute the key hash value */
    h = dictHashKey(d, key);
    for (table = 0; table <= 1; table++) {
      	//查看key在buket的位置
        idx = h & d->ht[table].sizemask;
        /* Search if this slot does not already contain the given key */
        he = d->ht[table].table[idx];
        while(he) {
         		//key值是否相等
            if (key==he->key || dictCompareKeys(d, key, he->key))
                return -1;
            he = he->next;
        }
        if (!dictIsRehashing(d)) break;
    }
    return idx;
}

/* Add or Overwrite:
 * Add an element, discarding the old value if the key already exists.
 * Return 1 if the key was added from scratch, 0 if there was already an
 * element with such key and dictReplace() just performed a value update
 * operation. */
int dictReplace(dict *d, void *key, void *val)
{
    dictEntry *entry, *existing, auxentry;

    /* Try to add the element. If the key
     * does not exists dictAdd will succeed. */
    entry = dictAddRaw(d,key,&existing);
    if (entry) {
        dictSetVal(d, entry, val);
        return 1;
    }

    /* Set the new value and free the old one. Note that it is important
     * to do that in this order, as the value may just be exactly the same
     * as the previous one. In this context, think to reference counting,
     * you want to increment (set), and then decrement (free), and not the
     * reverse. */
    auxentry = *existing;
    dictSetVal(d, existing, val);
    dictFreeVal(d, &auxentry);
    return 0;
}

```

由于dictReplace 和 dictAdd 基本一样，我们这里只分析 dictAdd的步骤

- 是否处于reash状态，如果处于reash状态，触发推进一步重哈希（_dictRehashStep）。

- 如果正在重哈希中，它会把数据插入到ht[1]；否则插入到ht[0]。

- 在对应的bucket中插入数据的时候，总是插入到dictEntry的头部。因为新数据接下来被访问的概率可能比较高，这样再次查找它时就比较次数较少。

- _dictKeyIndex在dict中寻找插入位置。如果不在重哈希过程中，它只查找ht[0]；否则查找ht[0]和ht[1]。

# Rehash 
当操作越来越多，比如不断的向哈希表添加元素，那么hash表的冲突就会越来越多，has表会退化成链表。所以这个时候就需要扩张hash表的bucket的数量。同样如果不断的减少hash表元素，那么hash的空间利用率就大大减低，所以这个时候需要减少hash表的bucket的数量。当哈希表保存的键值对太多或者太少时，redis对哈希表大小进行相应的扩展和收缩，称为rehash（重新散列）。

## 负载因子
```
负载因子 = 哈希表已保存节点数量 / 哈希表大小
```
负载因子越大，意味着哈希表越满，越容易导致冲突，性能也就越低。因此，一般来说，当负载因子大于某个常数(可能是 1，或者 0.75 等)时，哈希表将自动扩容。

## 渐进式rehash
rehash的操作不是一次性就完成了的，而是分多次，渐进式地完成。
原因是，如果需要rehash的键值对较多，会对服务器造成性能影响，渐进式地rehash避免了对服务器的影响。
渐进式的rehash使用了dict结构体中的rehashidx属性辅助完成。当渐进式哈希开始时，rehashidx会被设置为0，表示从dictEntry[0]开始进行rehash，每完成一次，就将rehashidx加1。直到ht[0]中的所有节点都被rehash到ht[1]，rehashidx被设置为-1，此时表示rehash结束。





作者：hoohack
链接：https://juejin.cn/post/6844903545724993549
来源：掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。

```go
static int _dictExpandIfNeeded(dict *ht) {
    /* If the hash table is empty expand it to the initial size,
     * if the table is "full" dobule its size. */
    if (ht->size == 0)
        return dictExpand(ht, DICT_HT_INITIAL_SIZE);
    if (ht->used == ht->size)
        //扩展hash桶
        return dictExpand(ht, ht->size*2);
    return DICT_OK;
}

/* Expand or create the hash table */
int dictExpand(dict *d, unsigned long size)
{
    dictht n; /* the new hash table */
    //获取新表的大小
    unsigned long realsize = _dictNextPower(size);

    /* the size is invalid if it is smaller than the number of
     * elements already inside the hash table */
    if (dictIsRehashing(d) || d->ht[0].used > size)
        return DICT_ERR;

    /* Rehashing to the same table size is not useful. */
    if (realsize == d->ht[0].size) return DICT_ERR;

    /* Allocate the new hash table and initialize all pointers to NULL */
    //内存分配
    n.size = realsize;
    n.sizemask = realsize-1;
    n.table = zcalloc(realsize*sizeof(dictEntry*));
    n.used = 0;

    /* Is this the first initialization? If so it's not really a rehashing
     * we just set the first hash table so that it can accept keys. */
     //第一张表为空，说明为插入key 
    if (d->ht[0].table == NULL) {
        d->ht[0] = n;
        return DICT_OK;
    }

    /* Prepare a second hash table for incremental rehashing */
    d->ht[1] = n;
    //修改rehashidx状态
    d->rehashidx = 0;
    return DICT_OK;
}




tatic void _dictRehashStep(dict *d) {
    if (d->iterators == 0) dictRehash(d,1);
}

int dictRehash(dict *d, int n) {
    int empty_visits = n*10; /* Max number of empty buckets to visit. */
  	//是否处于rehash的状态
    if (!dictIsRehashing(d)) return 0;
		
  	//h[0]中的被使用数量不为0 
    while(n-- && d->ht[0].used != 0) {
        dictEntry *de, *nextde;

        /* Note that rehashidx can't overflow as we are sure there are more
         * elements because ht[0].used != 0 */
        assert(d->ht[0].size > (unsigned long)d->rehashidx);
        //跳过数组中为空的桶
        while(d->ht[0].table[d->rehashidx] == NULL) {
            d->rehashidx++;
           //如果访问空桶次数超过限制，则直接返回
            if (--empty_visits == 0) return 1;
        }
      	 //ht[0]中正在rehash的桶的位置
        de = d->ht[0].table[d->rehashidx];
        /* Move all the keys in this bucket from the old to the new hash HT */
      //将旧bucket的数据迁移到新桶中   
      while(de) {
            uint64_t h;

            nextde = de->next;
            /* Get the index in the new hash table */
            h = dictHashKey(d, de->key) & d->ht[1].sizemask;
            de->next = d->ht[1].table[h];
            d->ht[1].table[h] = de;
            d->ht[0].used--;
            d->ht[1].used++;
            de = nextde;
        }
        d->ht[0].table[d->rehashidx] = NULL;
        d->rehashidx++;
    }

    /* Check if we already rehashed the whole table... */
  	//ht[0]剩余元素个数为0，表明ht[0]中的元素已经全部rehash到ht[1]中，因此rehash过程已经完成
    if (d->ht[0].used == 0) {
        zfree(d->ht[0].table);
        d->ht[0] = d->ht[1];
        _dictReset(&d->ht[1]);
        d->rehashidx = -1;
        return 0;
    }

    /* More to rehash... */
    return 1;
}

```





# 参考

Redis内部数据结构详解(1)——dict http://zhangtielei.com/posts/blog-redis-dict.html

  

  

