---
title: "Redis源码阅读之list"
date: 2020-11-10T14:22:55+08:00
draft: true
---

链表在 Redis 中的应用非常广泛， 比如列表键的底层实现之一就是链表： 当一个列表键包含了数量比较多的元素， 又或者列表中包含的元素都是比较长的字符串时， Redis 就会使用链表作为列表键的底层实现。



Redis 中的链表实现采用的是非常朴素的双端链表，其结构如下

```c
// list 节点
typedef struct listNode {
    struct listNode *prev; // 前驱指针 
    struct listNode *next; // 后继指针
    void *value;           // 节点值
} listNode;


// list 
typedef struct list {
    listNode *head; //头指针  
    listNode *tail; // 尾指针
    void *(*dup)(void *ptr);// 节点值复制函数
    void (*free)(void *ptr);// 节点释放函数
    int (*match)(void *ptr, void *key);//节点值对比函数
    unsigned long len;//节点长度
} list;

```



# 迭代器

Redis 为双端链表实现了一个迭代器 ， 这个迭代器可以从两个方向对双端链表进行迭代：

沿着节点的 next 指针前进，从表头向表尾迭代； 沿着节点的 prev 指针前进，从表尾向表头迭代；

```c
//迭代器
typedef struct listIter {
    //后继节点
    listNode *next;
    //迭代反向
    int direction;
} listIter;


listIter *listGetIterator(list *list, int direction)
{
    listIter *iter;

    if ((iter = zmalloc(sizeof(*iter))) == NULL) return NULL;
    if (direction == AL_START_HEAD)
        iter->next = list->head;
    else
        iter->next = list->tail;
    iter->direction = direction;
    return iter;
}

listNode *listNext(listIter *iter)
{
    listNode *current = iter->next;

    if (current != NULL) {
        if (iter->direction == AL_START_HEAD)
            iter->next = current->next;
        else
            iter->next = current->prev;
    }
    return current;
}
```







