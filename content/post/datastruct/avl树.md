---
title: "avl树"
date: 2020-09-01T12:55:09+08:00
draft: true
---



# 什么是AVL 树

AVL 树是一种最早被发明的自平衡二叉树（ self-balancing Binary Search Tree (BST)）,任一节点对应的两棵子树的最大高度差为1.



**An Example Tree that is an avl Tree**





![image-20200901125824201](/Users/linyuanpeng/workplace/bspp1314/content/post/datastruct/image-20200901125824201.png)

可以看到上面这颗二叉树的任一节点的左右子树最大的高度差都不超过1 ,所以其当然是一颗AVL树。



**An Example Tree that is NOT an AVL Tree**

![image-20200901130037245](/Users/linyuanpeng/workplace/bspp1314/content/post/datastruct/image-20200901130037245.png)

上述的二叉树存在左右子树的节点，所以其不是一颗AVL树。



# 为何使用AVL 树

> Most of the BST operations (e.g., search, max, min, insert, delete.. etc) take O(h) time where h is the height of the BST. The cost of these operations may become O(n) for a skewed Binary tree. If we make sure that height of the tree remains O(Logn) after every insertion and deletion, then we can guarantee an upper bound of O(Logn) for all these operations. The height of an AVL tree is always O(Logn) where n is the number of nodes in the tree (See [this ](http://www.youtube.com/watch?v=TbvhGcf6UJU)video lecture for proof).



# 插入操作



## 左旋和右旋







# 