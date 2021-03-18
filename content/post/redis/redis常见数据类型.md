---
title: "Redis数据类型使用"
date: 2020-11-04T16:54:38+08:00
draft: false
---
​      Redis目前支持5种数据类型，分别是：

1. String（字符串）
2. List（列表）
3. Hash（字典）
4. Set（集合）
5. Sorted Set（有序集合）

#  redisObject 

 redisObject是redis server存储最原子数据的数据结构，其中的void *ptr会指向真正的存储数据结构，我们set key value中的key和value其实由ptr指向真正保存的位置。

```cpp
typedef struct redisObject {

    // 类型
    unsigned type:4;

    // 编码
    unsigned encoding:4;

    // 对象最后一次被访问的时间
    unsigned lru:REDIS_LRU_BITS; /* lru time (relative to server.lruclock) */

    // 引用计数
    int refcount;

    // 指向实际值的指针
    void *ptr;

} robj;
```





# String 

## 构成

 我们可能以为redis在内部存储string都是用sds的数据结构实现的，其实在整个redis的数据存储过程中为了提高性能，内部做了很多优化。整体选择顺序应该是：

- 整数，存储字符串长度小于21且能够转化为整数的字符串。
- EmbeddedString，存储字符串长度小于44的字符串（REDIS_ENCODING_EMBSTR_SIZE_LIMIT）。
- SDS，剩余情况使用sds进行存储。

 **embstr和sds(raw)的区别在于内存的申请和回收**

- embstr的创建只需分配一次内存(只分配redisObject)，而raw为两次（一次为sds分配对象，另一次为redisObject分配对象，embstr省去了第一次）。相对地，释放内存的次数也由两次变为一次。
- embstr的redisObject和sds放在一起，更好地利用缓存带来的优势
- 缺点：redis并未提供任何修改embstr的方式，即embstr是只读的形式。对embstr的修改实际上是先转换为raw再进行修改。




```c
/* SET key value [NX] [XX] [KEEPTTL] [EX <seconds>] [PX <milliseconds>] */
void setCommand(client *c) {
    int j;
    robj *expire = NULL;
    int unit = UNIT_SECONDS;
    int flags = OBJ_SET_NO_FLAGS;

    for (j = 3; j < c->argc; j++) {
        char *a = c->argv[j]->ptr;
        robj *next = (j == c->argc-1) ? NULL : c->argv[j+1];

        if ((a[0] == 'n' || a[0] == 'N') &&
            (a[1] == 'x' || a[1] == 'X') && a[2] == '\0' &&
            !(flags & OBJ_SET_XX))
        {
            flags |= OBJ_SET_NX;
        } else if ((a[0] == 'x' || a[0] == 'X') &&
                   (a[1] == 'x' || a[1] == 'X') && a[2] == '\0' &&
                   !(flags & OBJ_SET_NX))
        {
            flags |= OBJ_SET_XX;
        } else if (!strcasecmp(c->argv[j]->ptr,"KEEPTTL") &&
                   !(flags & OBJ_SET_EX) && !(flags & OBJ_SET_PX))
        {
            flags |= OBJ_SET_KEEPTTL;
        } else if ((a[0] == 'e' || a[0] == 'E') &&
                   (a[1] == 'x' || a[1] == 'X') && a[2] == '\0' &&
                   !(flags & OBJ_SET_KEEPTTL) &&
                   !(flags & OBJ_SET_PX) && next)
        {
            flags |= OBJ_SET_EX;
            unit = UNIT_SECONDS;
            expire = next;
            j++;
        } else if ((a[0] == 'p' || a[0] == 'P') &&
                   (a[1] == 'x' || a[1] == 'X') && a[2] == '\0' &&
                   !(flags & OBJ_SET_KEEPTTL) &&
                   !(flags & OBJ_SET_EX) && next)
        {
            flags |= OBJ_SET_PX;
            unit = UNIT_MILLISECONDS;
            expire = next;
            j++;
        } else {
            addReply(c,shared.syntaxerr);
            return;
        }
    }

  	//尝试对obj对象重新编码
    c->argv[2] = tryObjectEncoding(c->argv[2]);
    setGenericCommand(c,flags,c->argv[1],c->argv[2],expire,unit,NULL,NULL);
}


/* Try to encode a string object in order to save space */
robj *tryObjectEncoding(robj *o) {
    long value;
    sds s = o->ptr;
    size_t len;

    /* Make sure this is a string object, the only type we encode
     * in this function. Other types use encoded memory efficient
     * representations but are handled by the commands implementing
     * the type. */
    serverAssertWithInfo(NULL,o,o->type == OBJ_STRING);

    /* We try some specialized encoding only for objects that are
     * RAW or EMBSTR encoded, in other words objects that are still
     * in represented by an actually array of chars. */
    if (!sdsEncodedObject(o)) return o;

    /* It's not safe to encode shared objects: shared objects can be shared
     * everywhere in the "object space" of Redis and may end in places where
     * they are not handled. We handle them only as values in the keyspace. */
     if (o->refcount > 1) return o;

    /* Check if we can represent this string as a long integer.
     * Note that we are sure that a string larger than 20 chars is not
     * representable as a 32 nor 64 bit integer. */
    len = sdslen(s);
  //小于20等于21个字节且其为int 
    if (len <= 20 && string2l(s,len,&value)) {
        /* This object is encodable as a long. Try to use a shared object.
         * Note that we avoid using shared integers when maxmemory is used
         * because every object needs to have a private LRU field for the LRU
         * algorithm to work well. */
        if ((server.maxmemory == 0 ||
            !(server.maxmemory_policy & MAXMEMORY_FLAG_NO_SHARED_INTEGERS)) &&
            value >= 0 &&
            value < OBJ_SHARED_INTEGERS)
        {
            decrRefCount(o);
            incrRefCount(shared.integers[value]);
            return shared.integers[value];
        } else {
            if (o->encoding == OBJ_ENCODING_RAW) {
                sdsfree(o->ptr);
                o->encoding = OBJ_ENCODING_INT;
                o->ptr = (void*) value;
                return o;
            } else if (o->encoding == OBJ_ENCODING_EMBSTR) {
                decrRefCount(o);
                return createStringObjectFromLongLongForValue(value);
            }
        }
    }

    /* If the string is small and is still RAW encoded,
     * try the EMBSTR encoding which is more efficient.
     * In this representation the object and the SDS string are allocated
     * in the same chunk of memory to save space and cache misses. */
  	// 小于 44 
    if (len <= OBJ_ENCODING_EMBSTR_SIZE_LIMIT) {
        robj *emb;

        if (o->encoding == OBJ_ENCODING_EMBSTR) return o;
        emb = createEmbeddedStringObject(s,sdslen(s));
        decrRefCount(o);
        return emb;
    }

    /* We can't encode the object...
     *
     * Do the last try, and at least optimize the SDS string inside
     * the string object to require little space, in case there
     * is more than 10% of free space at the end of the SDS string.
     *
     * We do that only for relatively large strings as this branch
     * is only entered if the length of the string is greater than
     * OBJ_ENCODING_EMBSTR_SIZE_LIMIT. */
    trimStringObjectIfNeeded(o);

    /* Return the original object. */
    return o;
}
```


## 常见命令

```
//set(key, value)：给数据库中名称为key的string赋予值value
//get(key)：返回数据库中名称为key的string的value
//getset(key, value)：给名称为key的string赋予上一次的value
//mget(key1, key2,…, key N)：返回库中多个string的value
//setnx(key, value)：添加string，名称为key，值为value
//setex(key, time, value)：向库中添加string，设定过期时间time
//mset(key N, value N)：批量设置多个string的值
//msetnx(key N, value N)：如果所有名称为key i的string都不存在
//incr(key)：名称为key的string增1操作
//incrby(key, integer)：名称为key的string增加integer
//decr(key)：名称为key的string减1操作
//decrby(key, integer)：名称为key的string减少integer
//append(key, value)：名称为key的string的值附加value
//substr(key, start, end)：返回名称为key的string的value的子串
//redis 设置字符串

```

## 使用
```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	rdbCmdStatus  := rdb.Set("key", "value", 0)
	if rdbCmdStatus.Err() != nil {
		fmt.Errorf("Set redis failed %v,cmd is %s  ",rdbCmdStatus.Err(),rdbCmdStatus.String())
		return
	}

	log.Println(rdbCmdStatus.String())

	resStatus := rdb.Get("key")
	if resStatus.Err() != nil {
		fmt.Errorf("Get redis failed %v,cmd is %s  ",rdbCmdStatus.Err(),rdbCmdStatus.String())
		return
	}
  fmt.Println(resStatus.String())
}
```

# List 

## 构成

 redis list数据结构底层采用压缩列表ziplist或linkedlist两种数据结构进行存储，首先以ziplist进行存储，在不满足ziplist的存储要求后转换为linkedlist列表。
 **当列表对象同时满足以下两个条件时，列表对象使用ziplist进行存储，否则用linkedlist存储。**

- 列表对象保存的所有字符串元素的长度小于64字节
- 列表对象保存的元素数量小于512 （可以配置）



```c
oid pushGenericCommand(client *c, int where) {
    int j, pushed = 0;
  	// 取出对象
    robj *lobj = lookupKeyWrite(c->db,c->argv[1]);

  	// 对象类型不是 OBJ_LIST 
    if (lobj && lobj->type != OBJ_LIST) {
        addReply(c,shared.wrongtypeerr);
        return;
    }

    for (j = 2; j < c->argc; j++) {
      	// 对象为空，创建一个obj 
        if (!lobj) {
            lobj = createQuicklistObject();
          	//设置类型
            quicklistSetOptions(lobj->ptr, server.list_max_ziplist_size,
                                server.list_compress_depth);
            //关联到数据库
            dbAdd(c->db,c->argv[1],lobj);
        }
      	 // 将值推入到列表
        listTypePush(lobj,c->argv[j],where);
        pushed++;
    }
  
    addReplyLongLong(c, (lobj ? listTypeLength(lobj) : 0));
    if (pushed) {
        char *event = (where == LIST_HEAD) ? "lpush" : "rpush";

        signalModifiedKey(c,c->db,c->argv[1]);
        notifyKeyspaceEvent(NOTIFY_LIST,event,c->argv[1],c->db->id);
    }
    server.dirty += pushed;
}

/* The function pushes an element to the specified list object 'subject',
 * at head or tail position as specified by 'where'.
 *
 * There is no need for the caller to increment the refcount of 'value' as
 * the function takes care of it if needed. */
void listTypePush(robj *subject, robj *value, int where) {
    if (subject->encoding == OBJ_ENCODING_QUICKLIST) {
        int pos = (where == LIST_HEAD) ? QUICKLIST_HEAD : QUICKLIST_TAIL;
        value = getDecodedObject(value);
        size_t len = sdslen(value->ptr);
        //推送数据
      	quicklistPush(subject->ptr, value->ptr, len, pos);
        decrRefCount(value);
    } else {
      	
        serverPanic("Unknown list encoding");
    }
}
/* Wrapper to allow argument-based switching between HEAD/TAIL pop */
void quicklistPush(quicklist *quicklist, void *value, const size_t sz,
                   int where) {
    if (where == QUICKLIST_HEAD) {
        quicklistPushHead(quicklist, value, sz);
    } else if (where == QUICKLIST_TAIL) {
        quicklistPushTail(quicklist, value, sz);
    }
}

/* Add new entry to head node of quicklist.
 *
 * Returns 0 if used existing head.
 * Returns 1 if new head created. */
int quicklistPushHead(quicklist *quicklist, void *value, size_t sz) {
    quicklistNode *orig_head = quicklist->head;
   	//是否zip编码类型
  	if (likely(
            _quicklistNodeAllowInsert(quicklist->head, quicklist->fill, sz))) {
        quicklist->head->zl =
            ziplistPush(quicklist->head->zl, value, sz, ZIPLIST_HEAD);
        quicklistNodeUpdateSz(quicklist->head);
    } else {
        quicklistNode *node = quicklistCreateNode();
        node->zl = ziplistPush(ziplistNew(), value, sz, ZIPLIST_HEAD);

        quicklistNodeUpdateSz(node);
        _quicklistInsertNodeBefore(quicklist, quicklist->head, node);
    }
    quicklist->count++;
    quicklist->head->count++;
    return (orig_head != quicklist->head);
}


```





## 常见命令



```
//rpush(key, value)：在名称为key的list尾添加一个值为value的元素
//lpush(key, value)：在名称为key的list头添加一个值为value的 元素
//llen(key)：返回名称为key的list的长度
//lrange(key, start, end)：返回名称为key的list中start至end之间的元素
//ltrim(key, start, end)：截取名称为key的list
//lindex(key, index)：返回名称为key的list中index位置的元素
//lset(key, index, value)：给名称为key的list中index位置的元素赋值
//lrem(key, count, value)：删除count个key的list中值为value的元素
//lpop(key)：返回并删除名称为key的list中的首元素
//rpop(key)：返回并删除名称为key的list中的尾元素
//blpop(key1, key2,… key N, timeout)：lpop命令的block版本。
//brpop(key1, key2,… key N, timeout)：rpop的block版本。
//rpoplpush(srckey, dstkey)：返回并删除名称为srckey的list的尾元素，并将该元素添加到名称为dstkey的list的头部
```

## 简单使用

```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	cmd := rdb.RPush("language", "Golang", "Java") // push data to list right
	if err := cmd.Err(); err != nil {
		log.Fatal(err)
	}
	defer rdb.Del("language")


	cmd = rdb.LPush("language", "PHP", "Rust") // push data to list right
	if err := cmd.Err(); err != nil {
		log.Fatal(err)
	}

	res, err := rdb.LRange("language", 0, math.MaxInt64).Result()
	if err != nil {
		log.Fatal(err)
	}
	// Rust PHP Golang Java
	fmt.Println(res)

	//Remove
	e,err := rdb.LPop("language").Result()
	if err != nil {
		log.Fatal(err)
	}
	//Get  Rust
	fmt.Println(e)

	//Remove
	e,err = rdb.RPop("language").Result()
	if err != nil {
		log.Fatal(err)
	}
	//Get  Java
	fmt.Println(e)
}

```

# Hash 

## 构成

 redis hash 数据结构底层采用压缩列表ziplist或linkedlist两种数据结构进行存储，首先以ziplist进行存储，在不满足ziplist的存储要求后转换为linkedlist列表。

1. 哈希对象保存的所有键值对的键和值的字符串长度都小于 `64` 字节（可以配置）；
2. 哈希对象保存的键值对数量小于 `512` 个（可以配置）；



```c
void hsetCommand(client *c) {
    int i, created = 0;
    robj *o;

    if ((c->argc % 2) == 1) {
        addReplyErrorFormat(c,"wrong number of arguments for '%s' command",c->cmd->name);
        return;
    }

  	//不存在
    if ((o = hashTypeLookupWriteOrCreate(c,c->argv[1])) == NULL) return;
  	//尝试将ziplist 转换成hash 编码
    hashTypeTryConversion(o,c->argv,2,c->argc-1);

    for (i = 2; i < c->argc; i += 2)
        created += !hashTypeSet(o,c->argv[i]->ptr,c->argv[i+1]->ptr,HASH_SET_COPY);

    /* HMSET (deprecated) and HSET return value is different. */
    char *cmdname = c->argv[0]->ptr;
    if (cmdname[1] == 's' || cmdname[1] == 'S') {
        /* HSET */
        addReplyLongLong(c, created);
    } else {
        /* HMSET */
        addReply(c, shared.ok);
    }
 	 // 发送键修改信号
    signalModifiedKey(c,c->db,c->argv[1]);
  	// 发送事件通知
  notifyKeyspaceEvent(NOTIFY_HASH,"hset",c->argv[1],c->db->id);
    server.dirty++;
}


/* Check the length of a number of objects to see if we need to convert a
 * ziplist to a real hash. Note that we only check string encoded objects
 * as their string length can be queried in constant time. */
void hashTypeTryConversion(robj *o, robj **argv, int start, int end) {
    int i;

    if (o->encoding != OBJ_ENCODING_ZIPLIST) return;

    for (i = start; i <= end; i++) {
        if (sdsEncodedObject(argv[i]) &&
            sdslen(argv[i]->ptr) > server.hash_max_ziplist_value)
        {
            hashTypeConvert(o, OBJ_ENCODING_HT);
            break;
        }
    }
}


int hashTypeSet(robj *o, sds field, sds value, int flags) {
    int update = 0;

  	//ziplist 格式的编码
    if (o->encoding == OBJ_ENCODING_ZIPLIST) {
        unsigned char *zl, *fptr, *vptr;

        zl = o->ptr;
        fptr = ziplistIndex(zl, ZIPLIST_HEAD);
        if (fptr != NULL) {
            fptr = ziplistFind(fptr, (unsigned char*)field, sdslen(field), 1);
            if (fptr != NULL) {
                /* Grab pointer to the value (fptr points to the field) */
                vptr = ziplistNext(zl, fptr);
                serverAssert(vptr != NULL);
                update = 1;

                /* Delete value */
                zl = ziplistDelete(zl, &vptr);

                /* Insert new value */
                zl = ziplistInsert(zl, vptr, (unsigned char*)value,
                        sdslen(value));
            }
        }
			
      	//不是更新
        if (!update) {
            /* Push new field/value pair onto the tail of the ziplist */
            zl = ziplistPush(zl, (unsigned char*)field, sdslen(field),
                    ZIPLIST_TAIL);
            zl = ziplistPush(zl, (unsigned char*)value, sdslen(value),
                    ZIPLIST_TAIL);
        }
        o->ptr = zl;

        /* Check if the ziplist needs to be converted to a hash table */
      	//大于 hash_max_ziplist_entries ,转换格式
        if (hashTypeLength(o) > server.hash_max_ziplist_entries)
            hashTypeConvert(o, OBJ_ENCODING_HT);
    } else if (o->encoding == OBJ_ENCODING_HT) {
        dictEntry *de = dictFind(o->ptr,field);
        if (de) {
            sdsfree(dictGetVal(de));
            if (flags & HASH_SET_TAKE_VALUE) {
                dictGetVal(de) = value;
                value = NULL;
            } else {
                dictGetVal(de) = sdsdup(value);
            }
            update = 1;
        } else {
            sds f,v;
            if (flags & HASH_SET_TAKE_FIELD) {
                f = field;
                field = NULL;
            } else {
                f = sdsdup(field);
            }
            if (flags & HASH_SET_TAKE_VALUE) {
                v = value;
                value = NULL;
            } else {
                v = sdsdup(value);
            }
            dictAdd(o->ptr,f,v);
        }
    } else {
        serverPanic("Unknown hash encoding");
    }

    /* Free SDS strings we did not referenced elsewhere if the flags
     * want this function to be responsible. */
    if (flags & HASH_SET_TAKE_FIELD && field) sdsfree(field);
    if (flags & HASH_SET_TAKE_VALUE && value) sdsfree(value);
    return update;
}

```





##常见命令

```
//hset(key, field, value)：向名称为key的hash中添加元素field
//hget(key, field)：返回名称为key的hash中field对应的value
//hmget(key, (fields))：返回名称为key的hash中field i对应的value
//hmset(key, (fields))：向名称为key的hash中添加元素field
//hincrby(key, field, integer)：将名称为key的hash中field的value增加integer
//hexists(key, field)：名称为key的hash中是否存在键为field的域
//hdel(key, field)：删除名称为key的hash中键为field的域
//hlen(key)：返回名称为key的hash中元素个数
//hkeys(key)：返回名称为key的hash中所有键
//hvals(key)：返回名称为key的hash中所有键对应的value
//hgetall(key)：返回名称为key的hash中所有的键（field）及其对应的value
```

## 使用

```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})


	// key is user id
	rdb.HSet("1","name","张三")
	rdb.HSet("1","age",40)

	//set name
	hmGetCmd,err := rdb.HMGet("1","name","age").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Get Name and age ",hmGetCmd)


	hGetAll,err := rdb.HGetAll("1").Result()
	if err != nil {
		log.Fatal(err)
	}

	log.Println(hGetAll)
	defer rdb.Del("1")
}
```

# Set 

## 构成

- **intset**（整数集合）：当集合中的元素都是整数且元素个数小于set-max-intset-entries配置（默认512个）时，

　　　　Redis会选用intset来作为集合内部实现，从而减少内存的使用。

- **hashtable**（哈希表）：当集合类型无法满足intset的条件时，Redis会使用hashtable作为集合的内部实现。



```c
void saddCommand(client *c) {
    robj *set;
    int j, added = 0;

    set = lookupKeyWrite(c->db,c->argv[1]);
    if (set == NULL) {
        set = setTypeCreate(c->argv[2]->ptr);
        dbAdd(c->db,c->argv[1],set);
    } else {
        if (set->type != OBJ_SET) {
            addReply(c,shared.wrongtypeerr);
            return;
        }
    }

    for (j = 2; j < c->argc; j++) {
        if (setTypeAdd(set,c->argv[j]->ptr)) added++;
    }
    if (added) {
        signalModifiedKey(c,c->db,c->argv[1]);
        notifyKeyspaceEvent(NOTIFY_SET,"sadd",c->argv[1],c->db->id);
    }
    server.dirty += added;
    addReplyLongLong(c,added);
}
/* Add the specified value into a set.
 *
 * If the value was already member of the set, nothing is done and 0 is
 * returned, otherwise the new element is added and 1 is returned. */
int setTypeAdd(robj *subject, sds value) {
    long long llval;
  	//编码类型是 hashtable 
    if (subject->encoding == OBJ_ENCODING_HT) {
        dict *ht = subject->ptr;
        dictEntry *de = dictAddRaw(ht,value,NULL);
        if (de) {
            dictSetKey(ht,de,sdsdup(value));
            dictSetVal(ht,de,NULL);
            return 1;
        }
    } else if (subject->encoding == OBJ_ENCODING_INTSET) {
        if (isSdsRepresentableAsLongLong(value,&llval) == C_OK) {
            uint8_t success = 0;
            subject->ptr = intsetAdd(subject->ptr,llval,&success);
            if (success) {
                /* Convert to regular set when the intset contains
                 * too many entries. */
              	// 量过多，转换成 hashtable 
                if (intsetLen(subject->ptr) > server.set_max_intset_entries)
                    setTypeConvert(subject,OBJ_ENCODING_HT);
                return 1;
            }
        } else {
            /* Failed to get integer from object, convert to regular set. */
            // 量过多，转换成 hashtable 
            setTypeConvert(subject,OBJ_ENCODING_HT);

            /* The set *was* an intset and this value is not integer
             * encodable, so dictAdd should always work. */
            serverAssert(dictAdd(subject->ptr,sdsdup(value),NULL) == DICT_OK);
            return 1;
        }
    } else {
        serverPanic("Unknown set encoding");
    }
    return 0;
}


```

## 常见命令



```
//sadd(key, member)：向名称为key的set中添加元素member
//srem(key, member) ：删除名称为key的set中的元素member
//spop(key) ：随机返回并删除名称为key的set中一个元素
//smove(srckey, dstkey, member) ：移到集合元素
//scard(key) ：返回名称为key的set的基数
//sismember(key, member) ：member是否是名称为key的set的元素
//sinter(key1, key2,…key N) ：求交集
//sinterstore(dstkey, (keys)) ：求交集并将交集保存到dstkey的集合
//sunion(key1, (keys)) ：求并集
//sunionstore(dstkey, (keys)) ：求并集并将并集保存到dstkey的集合
//sdiff(key1, (keys)) ：求差集
//sdiffstore(dstkey, (keys)) ：求差集并将差集保存到dstkey的集合
//smembers(key) ：返回名称为key的set的所有元素
//srandmember(key) ：随机返回名称为key的set的一个元素
```

## 使用



```go
func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	_,err := rdb.SAdd("math_class","MaYu").Result()
	if err != nil {
		log.Fatal(err)
	}
	defer rdb.Del("math_class")

	_,err = rdb.SAdd("math_class","CuiGeHeng").Result()
	if err != nil {
		log.Fatal(err)
	}

	_,err = rdb.SAdd("math_class","ChenJingWen").Result()
	if err != nil {
		log.Fatal(err)
	}

	_,err = rdb.SAdd("math_class","ChenJun").Result()
	if err != nil {
		log.Fatal(err)
	}

	//get all math_class
	mathMembers,err := rdb.SMembers("math_class").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Math members is ",mathMembers)

	_,err = rdb.SAdd("english_class", "ChenJun").Result() // 向 whitelist 添加元素
	if err != nil {
		log.Fatal(err)
	}
	defer rdb.Del("english_class")



	_,err = rdb.SAdd("english_class", "FengYuanYuan").Result() // 向 whitelist 添加元素
	if err != nil {
		log.Fatal(err)
	}

	rdb.SAdd("english_class", "FengZhenKai").Result() // 向 whitelist 添加元素
	if err != nil {
		log.Fatal(err)
	}

	//get all math_class
	EnglishClassMembers,err := rdb.SMembers("english_class").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("English members is ",EnglishClassMembers)

	// 判断元素是否在集合中
	isMember, err := rdb.SIsMember("math_class", "MaYu").Result()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Is MaYu in math_class: ", isMember)

	//交集
	sInter,err := rdb.SInter("math_class","english_class").Result()
	if err != nil {
		log.Fatal(err)
	}

	log.Println("In math class and english class members is ",sInter)


	//交集
	sUnion,err := rdb.SUnion("math_class","english_class").Result()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("In math class or english class members is ",sUnion)

}

```



# 参考 

http://redisbook.com/preview/object/hash.html