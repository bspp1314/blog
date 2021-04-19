---
title: "Mongodb简单使用"
date: 2021-04-12T18:15:57+08:00
draft: true
---

# 安装

```
brew tap mongodb/brew
brew install mongodb-community@4.4
```



安装后的相关配置

| Intel Processor                                              | Apple M1 Processor           |                                 |
| :----------------------------------------------------------- | :--------------------------- | ------------------------------- |
| [configuration file](https://docs.mongodb.com/manual/reference/configuration-options/) | `/usr/local/etc/mongod.conf` | `/opt/homebrew/etc/mongod.conf` |
| [`log directory`](https://docs.mongodb.com/manual/reference/configuration-options/#mongodb-setting-systemLog.path) | `/usr/local/var/log/mongodb` | `/opt/homebrew/var/log/mongodb` |
| [`data directory`](https://docs.mongodb.com/manual/reference/configuration-options/#mongodb-setting-storage.dbPath) | `/usr/local/var/mongodb`     | `/opt/homebrew/var/mongodb`     |



启动

```
brew services start mongodb-community@4.4
brew services stop mongodb-community@4.4
```



#  MongoShell 

## Connect 

### Local MongoDb Instance on a no-default port 

```
mongo --port 28015
```



### MongoDB Instance on a Remote Host

连接串连接

```
mongo "mongodb://mongodb0.example.com:28015"
mongo "mongodb://alice@mongodb0.examples.com:28015/?authSource=admin"
```

命令行

```shell
mongo --host mongodb0.example.com --port 28015
mongo --username alice --password --authenticationDatabase admin --host mongodb0.examples.com --port 28015

```

更多复杂的连接可以 参考 [官网](https://docs.mongodb.com/manual/mongo/#connect-to-a-mongodb-replica-set)



## DB 操作

### Display the database 

```
db
```



Ex:

```
> db
test
> 
```



### Switch Database

```
use <database>
```

Ex

```
> use lyp
switched to db lyp
```

如果不存在db,会直接创建一个。



## Collection 操作

### Create Collection 

```
 db.createCollection('user');
```

更多复杂的操作可以 参考 [官网](https://docs.mongodb.com/manual/reference/method/db.createCollection/)



### Drop Collection 

```
db.collection.drop()
```

更多复杂的操作可以 参考 [官网](https://docs.mongodb.com/manual/reference/method/db.collection.drop/)





# CURD 操作

## Insert 

>  Tip
>
> Creating a Collection
>
> If the collection does not currently exist, insert operations will create the collection.



MongoDB provides the following methods for inserting [documents](https://docs.mongodb.com/manual/core/document/#std-label-bson-document-format) into a collection:

|                                                              |                                                              |
| :----------------------------------------------------------- | :----------------------------------------------------------- |
| [`db.collection.insertOne()`](https://docs.mongodb.com/manual/reference/method/db.collection.insertOne/#mongodb-method-db.collection.insertOne) | Inserts a single document into a collection.                 |
| [`db.collection.insertMany()`](https://docs.mongodb.com/manual/reference/method/db.collection.insertMany/#mongodb-method-db.collection.insertMany) | [`db.collection.insertMany()`](https://docs.mongodb.com/manual/reference/method/db.collection.insertMany/#mongodb-method-db.collection.insertMany) inserts *multiple* [documents](https://docs.mongodb.com/manual/core/document/#std-label-bson-document-format) into a collection. |
| [`db.collection.insert()`](https://docs.mongodb.com/manual/reference/method/db.collection.insert/#mongodb-method-db.collection.insert) | [`db.collection.insert()`](https://docs.mongodb.com/manual/reference/method/db.collection.insert/#mongodb-method-db.collection.insert) inserts a single document or multiple documents into a collection. |



### Insert One 

```
 db.inventory.insertOne(  { item: "canvas", qty: 100, tags: ["cotton"], size: { h: 28, w: 35.5, uom: "cm" } })
```

out 

```
{
	"acknowledged" : true,
	"insertedId" : ObjectId("607424e58417a55e62cb2d6f")
}
```



### InsertMany 

```
db.inventory.insertMany([
   { item: "journal", qty: 25, tags: ["blank", "red"], size: { h: 14, w: 21, uom: "cm" } },
   { item: "mat", qty: 85, tags: ["gray"], size: { h: 27.9, w: 35.5, uom: "cm" } },
   { item: "mousepad", qty: 25, tags: ["gel", "blue"], size: { h: 19, w: 22.85, uom: "cm" } }
])
```

out 

```
{
	"acknowledged" : true,
	"insertedIds" : [
		ObjectId("607425598417a55e62cb2d70"),
		ObjectId("607425598417a55e62cb2d71"),
		ObjectId("607425598417a55e62cb2d72")
	]
}
```

## Insert Behavior 

### Collection Creation

If the collection does not currently exist, insert operations will create the collection.

### `_id` Field

In MongoDB, each document stored in a collection requires a unique [_id](https://docs.mongodb.com/manual/reference/glossary/#std-term-_id) field that acts as a [primary key](https://docs.mongodb.com/manual/reference/glossary/#std-term-primary-key). If an inserted document omits the `_id` field, the MongoDB driver automatically generates an [ObjectId](https://docs.mongodb.com/manual/reference/bson-types/#std-label-objectid) for the `_id` field.

This also applies to documents inserted through update operations with [upsert: true](https://docs.mongodb.com/manual/reference/method/db.collection.update/#std-label-upsert-parameter).

### Atomicity

All write operations in MongoDB are atomic on the level of a single document. For more information on MongoDB and atomicity, see [Atomicity and Transactions](https://docs.mongodb.com/manual/core/write-operations-atomicity/)



## Query 

test data 

```
db.inventory.insertMany([
   { item: "journal", qty: 25, size: { h: 14, w: 21, uom: "cm" }, status: "A" },
    { item: "notebook", qty: 50, size: { h: 8.5, w: 11, uom: "in" }, status: "A" },
    { item: "paper", qty: 100, size: { h: 8.5, w: 11, uom: "in" }, status: "D" },
    { item: "planner", qty: 75, size: { h: 22.85, w: 30, uom: "cm" }, status: "D" },
    { item: "postcard", qty: 45, size: { h: 10, w: 15.25, uom: "cm" }, status: "A" }
])
```





### Select All Documents in a Collection

```
db.collection.find()
```

Ex

```
db.inventory.find();
```

Out

```json
 "_id" : ObjectId("60742a4a8417a55e62cb2d73"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "cm" }, "status" : "A" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d74"), "item" : "notebook", "qty" : 50, "size" : { "h" : 8.5, "w" : 11, "uom" : "in" }, "status" : "A" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d75"), "item" : "paper", "qty" : 100, "size" : { "h" : 8.5, "w" : 11, "uom" : "in" }, "status" : "D" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d76"), "item" : "planner", "qty" : 75, "size" : { "h" : 22.85, "w" : 30, "uom" : "cm" }, "status" : "D" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d77"), "item" : "postcard", "qty" : 45, "size" : { "h" : 10, "w" : 15.25, "uom" : "cm" }, "status" : "A" }
```



Pretty 格式输出

Ex

```
db.inventory.find().pretty();
```



 Out

```json
{
	"_id" : ObjectId("60742a4a8417a55e62cb2d73"),
	"item" : "journal",
	"qty" : 25,
	"size" : {
		"h" : 14,
		"w" : 21,
		"uom" : "cm"
	},
	"status" : "A"
}
{
	"_id" : ObjectId("60742a4a8417a55e62cb2d74"),
	"item" : "notebook",
	"qty" : 50,
	"size" : {
		"h" : 8.5,
		"w" : 11,
		"uom" : "in"
	},
	"status" : "A"
}
{
	"_id" : ObjectId("60742a4a8417a55e62cb2d75"),
	"item" : "paper",
	"qty" : 100,
	"size" : {
		"h" : 8.5,
		"w" : 11,
		"uom" : "in"
	},
	"status" : "D"
}
{
	"_id" : ObjectId("60742a4a8417a55e62cb2d76"),
	"item" : "planner",
	"qty" : 75,
	"size" : {
		"h" : 22.85,
		"w" : 30,
		"uom" : "cm"
	},
	"status" : "D"
}
{
	"_id" : ObjectId("60742a4a8417a55e62cb2d77"),
	"item" : "postcard",
	"qty" : 45,
	"size" : {
		"h" : 10,
		"w" : 15.25,
		"uom" : "cm"
	},
	"status" : "A"
}
```



###  Specify Equality Condition（指定相等条件查询）

```
db.collection.find({ <field1>: <value1>, ... })
```
Ex

```
db.inventory.find({ qty: 25 });
```

Out 

```json
{ "_id" : ObjectId("60742a4a8417a55e62cb2d73"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "cm" }, "status" : "A" }
```

Ex

```
db.inventory.find({ size: { h: 14, w: 21, uom: "cm" } });
```

Out 

```json
{ "_id" : ObjectId("60742a4a8417a55e62cb2d73"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "cm" }, "status" : "A" }
```





### Specify Conditions Using Query Operators



A [query filter document](https://docs.mongodb.com/manual/core/document/#std-label-document-query-filter) can use the [query operators](https://docs.mongodb.com/manual/reference/operator/query/#std-label-query-selectors) to specify conditions in the following form:

```
db.collection.find({ <field1>: { <operator1>: <value1> }, ... })
```



Ex

```
db.inventory.find({ status: { $in: [ "A", "D" ] } });
```



Out

```json
{ "_id" : ObjectId("60742a4a8417a55e62cb2d73"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "cm" }, "status" : "A" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d74"), "item" : "notebook", "qty" : 50, "size" : { "h" : 8.5, "w" : 11, "uom" : "in" }, "status" : "A" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d75"), "item" : "paper", "qty" : 100, "size" : { "h" : 8.5, "w" : 11, "uom" : "in" }, "status" : "D" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d76"), "item" : "planner", "qty" : 75, "size" : { "h" : 22.85, "w" : 30, "uom" : "cm" }, "status" : "D" }
{ "_id" : ObjectId("60742a4a8417a55e62cb2d77"), "item" : "postcard", "qty" : 45, "size" : { "h" : 10, "w" : 15.25, "uom" : "cm" }, "status" : "A" }
```



### Specify `AND` Conditions

A compound query can specify conditions for more than one field in the collection's documents. Implicitly, a logical `AND` conjunction connects the clauses of a compound query so that the query selects the documents in the collection that match all the conditions.

The following example retrieves all documents in the `inventory` collection where the `status` equals `"A"` **and** `qty` is less than ([`$lt`](https://docs.mongodb.com/manual/reference/operator/query/lt/#mongodb-query-op.-lt)) `30`:

Ex

```
db.inventory.find({ status: "A", qty: { $lt: 30 } });
```



```json
{ "_id" : ObjectId("60742a4a8417a55e62cb2d73"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "cm" }, "status" : "A" }
```



类似于MySQL里面的And 操作

```
SELECT * FROM inventory WHERE status = "A" AND qty < 30
```



### Query an Array 

参入数据

```json
db.inventory.insertMany([
   { item: "journal", qty: 25, tags: ["blank", "red"], dim_cm: [ 14, 21 ] },
   { item: "notebook", qty: 50, tags: ["red", "blank"], dim_cm: [ 14, 21 ] },
   { item: "paper", qty: 100, tags: ["red", "blank", "plain"], dim_cm: [ 14, 21 ] },
   { item: "planner", qty: 75, tags: ["blank", "red"], dim_cm: [ 22.85, 30 ] },
   { item: "postcard", qty: 45, tags: ["blue"], dim_cm: [ 10, 15.25 ] }
]);
```



#### Match an Array

数组全匹配查询

```
db.collection.find( { field: ["value1","value"] } )
```



Ex

```
db.inventory.find( { tags: ["red", "blank"] } )
```

Out

```json 
{ "_id" : ObjectId("6074f8cff4296182403a3a66"), "item" : "notebook", "qty" : 50, "tags" : [ "red", "blank" ], "dim_cm" : [ 14, 21 ] }
```



这里的全匹配查询必须是单词一致，数量一致，顺序一致。如果需要查找包含全部数组元素又不用保存顺序一致可以用一下命令

Ex

```
 db.inventory.find( { tags: { $all: ["red", "blank"] } } )
```

Out

```
{ "_id" : ObjectId("6074f8cff4296182403a3a65"), "item" : "journal", "qty" : 25, "tags" : [ "blank", "red" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("6074f8cff4296182403a3a66"), "item" : "notebook", "qty" : 50, "tags" : [ "red", "blank" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("6074f8cff4296182403a3a67"), "item" : "paper", "qty" : 100, "tags" : [ "red", "blank", "plain" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("6074f8cff4296182403a3a68"), "item" : "planner", "qty" : 75, "tags" : [ "blank", "red" ], "dim_cm" : [ 22.85, 30 ] }
```



#### Query an Array for an Element

查询数组中存在一个元素

```
db.collection.find(  { <field>: <value> })
```

Ex

```
db.inventory.find( { tags: "red" } )
```

Out 

```json
{ "_id" : ObjectId("60771b8c0dd7d40964f9ee18"), "item" : "journal", "qty" : 25, "tags" : [ "blank", "red" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("60771b8c0dd7d40964f9ee19"), "item" : "notebook", "qty" : 50, "tags" : [ "red", "blank" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("60771b8c0dd7d40964f9ee1a"), "item" : "paper", "qty" : 100, "tags" : [ "red", "blank", "plain" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("60771b8c0dd7d40964f9ee1b"), "item" : "planner", "qty" : 75, "tags" : [ "blank", "red" ], "dim_cm" : [ 22.85, 30 ] }
```



To specify conditions on the elements in the array field, use [query operators](https://docs.mongodb.com/manual/reference/operator/query/#std-label-query-selectors) in the [query filter document](https://docs.mongodb.com/manual/core/document/#std-label-document-query-filter):

```
db.collection.find({ <array field>: { <operator1>: <value1>, ... } })
```



Ex 

```
db.inventory.find( { dim_cm: { $gt: 25 } } )
```



Out 

```json
{ "_id" : ObjectId("60771b8c0dd7d40964f9ee1b"), "item" : "planner", "qty" : 75, "tags" : [ "blank", "red" ], "dim_cm" : [ 22.85, 30 ] }
```



#### Specify Multiple Conditions for Array Elements

When specifying compound conditions on array elements, you can specify the query such that either a single array element meets these condition or any combination of array elements meets the conditions.

#####  Query an Array with Compound Filter Conditions on the Array Elements

多重条件查询数组元素

```
db.collection.find( { field: { <operator1>: <value1>,<operator2>: <value2> ... } } )
```

这个查询语句比较有意思，只要 operators 的条件都被满足即可，无论是由一个元素满足还是由多个元素满足

The following example queries for documents where the `dim_cm` array contains elements that in some combination satisfy the query conditions; e.g., one element can satisfy the greater than `15` condition and another element can satisfy the less than `20` condition, or a single element can satisfy both:

Ex

```
db.inventory.find( { dim_cm: { $gt: 15, $lt: 20 } } )
```



Out

```
{ "_id" : ObjectId("607720ec67570b557240011f"), "item" : "journal", "qty" : 25, "tags" : [ "blank", "red" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("607720ec67570b5572400120"), "item" : "notebook", "qty" : 50, "tags" : [ "red", "blank" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("607720ec67570b5572400121"), "item" : "paper", "qty" : 100, "tags" : [ "red", "blank", "plain" ], "dim_cm" : [ 14, 21 ] }
{ "_id" : ObjectId("607720ec67570b5572400123"), "item" : "postcard", "qty" : 45, "tags" : [ "blue" ], "dim_cm" : [ 10, 15.25 ] }
```



那么如果我要一个元素满足所有条件该怎么办呢？

##### Query for an Array Element that Meets Multiple Criteria[¶

Use [`$elemMatch`](https://docs.mongodb.com/manual/reference/operator/query/elemMatch/#mongodb-query-op.-elemMatch) operator to specify multiple criteria on the elements of an array such that at least one array element satisfies all the specified criteria.

```
db.collection.find( { field:{ $elemMatch: { <operator1>: <value1>,<operator2>: <value2> ... } }} )
```



The following example queries for documents where the `dim_cm` array contains at least one element that is both greater than ([`$gt`](https://docs.mongodb.com/manual/reference/operator/query/gt/#mongodb-query-op.-gt)) `22` and less than ([`$lt`](https://docs.mongodb.com/manual/reference/operator/query/lt/#mongodb-query-op.-lt)) `30`:

```
db.inventory.find( { dim_cm: { $elemMatch: { $gt: 15, $lt: 20 } } } )
```



Out

```
{ "_id" : ObjectId("607720ec67570b5572400123"), "item" : "postcard", "qty" : 45, "tags" : [ "blue" ], "dim_cm" : [ 10, 15.25 ] }
```



可以看到确实和上面有很大不同。

更多的数组操作可以查看[官网](https://docs.mongodb.com/manual/tutorial/query-arrays/#query-for-an-element-by-the-array-index-position) 

更多的查询操作可以查看[官网](https://docs.mongodb.com/manual/tutorial/query-arrays/#query-for-an-element-by-the-array-index-position) 





# Update 操作

MongoDB 提供三个用来更的操作

```sql
db.collection.updateOne(<filter>, <update>, <options>)
db.collection.updateMany(<filter>, <update>, <options>)
db.collection.replaceOne(<filter>, <update>, <options>)
```



The examples on this page use the `inventory` collection. To create and/or populate the `inventory` collection, run the following:

```sql
db.inventory.insertMany( [
   { item: "canvas", qty: 100, size: { h: 28, w: 35.5, uom: "cm" }, status: "A" },
   { item: "journal", qty: 25, size: { h: 14, w: 21, uom: "cm" }, status: "A" },
   { item: "mat", qty: 85, size: { h: 27.9, w: 35.5, uom: "cm" }, status: "A" },
   { item: "mousepad", qty: 25, size: { h: 19, w: 22.85, uom: "cm" }, status: "P" },
   { item: "notebook", qty: 50, size: { h: 8.5, w: 11, uom: "in" }, status: "P" },
   { item: "paper", qty: 100, size: { h: 8.5, w: 11, uom: "in" }, status: "D" },
   { item: "planner", qty: 75, size: { h: 22.85, w: 30, uom: "cm" }, status: "D" },
   { item: "postcard", qty: 45, size: { h: 10, w: 15.25, uom: "cm" }, status: "A" },
   { item: "sketchbook", qty: 80, size: { h: 14, w: 21, uom: "cm" }, status: "A" },
   { item: "sketch pad", qty: 95, size: { h: 22.85, w: 30.5, uom: "cm" }, status: "A" }
] );
```

To update a document, MongoDB provides [update operators](https://docs.mongodb.com/manual/reference/operator/update/), such as [`$set`](https://docs.mongodb.com/manual/reference/operator/update/set/#mongodb-update-up.-set), to modify field values.

To use the update operators, pass to the update methods an update document of the form:

```
{
  <update operator>: { <field1>: <value1>, ... },
  <update operator>: { <field2>: <value2>, ... },
  ...
}
```

### Update a Single Docment 



UpdateOne 会更新collection里第一个服务条件的文档

The following example uses the [`db.collection.updateOne()`](https://docs.mongodb.com/manual/reference/method/db.collection.updateOne/#mongodb-method-db.collection.updateOne) method on the `inventory` collection to update the *first* document where `item` equals `"paper"`: 

```sql
> db.inventory.find({"item":"paper"});
{ "_id" : ObjectId("6078f9a1dc39109546a2fac5"), "item" : "paper", "qty" : 2000, "size" : { "h" : 8.5, "w" : 11, "uom" : "in" }, "status" : "D" }
> db.inventory.find({"item":"paper"});
{ "_id" : ObjectId("6078f9a1dc39109546a2fac5"), "item" : "paper", "qty" : 2000, "size" : { "h" : 8.5, "w" : 11, "uom" : "in" }, "status" : "D" }
> db.inventory.updateOne(
...    { item: "paper" },
...    {
...      $set: { "size.uom": "cm", status: "P" },
...      $currentDate: { lastModified: true }
...    }
... )
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }
>
> db.inventory.find({"item":"paper"});
{ "_id" : ObjectId("6078f9a1dc39109546a2fac5"), "item" : "paper", "qty" : 2000, "size" : { "h" : 8.5, "w" : 11, "uom" : "cm" }, "status" : "P", "lastModified" : ISODate("2021-04-16T02:47:59.350Z") }
```

The update operation:

- uses the [`$set`](https://docs.mongodb.com/manual/reference/operator/update/set/#mongodb-update-up.-set) operator to update the value of the `size.uom` field to `"cm"` and the value of the `status` field to `"P"`,
- uses the [`$currentDate`](https://docs.mongodb.com/manual/reference/operator/update/currentDate/#mongodb-update-up.-currentDate) operator to update the value of the `lastModified` field to the current date. If `lastModified` field does not exist, [`$currentDate`](https://docs.mongodb.com/manual/reference/operator/update/currentDate/#mongodb-update-up.-currentDate) will create the field. See [`$currentDate`](https://docs.mongodb.com/manual/reference/operator/update/currentDate/#mongodb-update-up.-currentDate) for details.

```sql
> db.inventory.find({"qty":{$lt:50}});
{ "_id" : ObjectId("6078f9a1dc39109546a2fac1"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "cm" }, "status" : "A" }
{ "_id" : ObjectId("6078f9a1dc39109546a2fac3"), "item" : "mousepad", "qty" : 25, "size" : { "h" : 19, "w" : 22.85, "uom" : "cm" }, "status" : "P" }
{ "_id" : ObjectId("6078f9a1dc39109546a2fac7"), "item" : "postcard", "qty" : 45, "size" : { "h" : 10, "w" : 15.25, "uom" : "cm" }, "status" : "A" }
> db.inventory.updateMany(
...    { "qty": { $lt: 50 } },
...    {
...      $set: { "size.uom": "in", status: "P" },
...      $currentDate: { lastModified: true }
...    }
... )
{ "acknowledged" : true, "matchedCount" : 3, "modifiedCount" : 3 }
> db.inventory.find({"qty":{$lt:50}});
{ "_id" : ObjectId("6078f9a1dc39109546a2fac1"), "item" : "journal", "qty" : 25, "size" : { "h" : 14, "w" : 21, "uom" : "in" }, "status" : "P", "lastModified" : ISODate("2021-04-16T02:52:24.016Z") }
{ "_id" : ObjectId("6078f9a1dc39109546a2fac3"), "item" : "mousepad", "qty" : 25, "size" : { "h" : 19, "w" : 22.85, "uom" : "in" }, "status" : "P", "lastModified" : ISODate("2021-04-16T02:52:24.016Z") }
{ "_id" : ObjectId("6078f9a1dc39109546a2fac7"), "item" : "postcard", "qty" : 45, "size" : { "h" : 10, "w" : 15.25, "uom" : "in" }, "status" : "P", "lastModified" : ISODate("2021-04-16T02:52:24.016Z") }
>
```

### Behavior

#### Atomicity

All write operations in MongoDB are atomic on the level of a single document. For more information on MongoDB and atomicity, see [Atomicity and Transactions](https://docs.mongodb.com/manual/core/write-operations-atomicity/).

#### `_id` Field

Once set, you cannot update the value of the `_id` field nor can you replace an existing document with a replacement document that has a different `_id` field value.

#### Field Order

MongoDB preserves the order of the document fields following write operations *except* for the following cases:

- The `_id` field is always the first field in the document.
- Updates that include [`renaming`](https://docs.mongodb.com/manual/reference/operator/update/rename/#mongodb-update-up.-rename) of field names may result in the reordering of fields in the document.



更多操作可以查看[官网](https://docs.mongodb.com/manual/tutorial/update-documents-with-aggregation-pipeline/) 



## Delete

mongoDB 提供了两个用来删除的操作函数

- [`db.collection.deleteMany()`](https://docs.mongodb.com/manual/reference/method/db.collection.deleteMany/#mongodb-method-db.collection.deleteMany)
- [`db.collection.deleteOne()`](https://docs.mongodb.com/manual/reference/method/db.collection.deleteOne/#mongodb-method-db.collection.deleteOne)



# 参考

Install mongodb on mac https://docs.mongodb.com/manual/tutorial/install-mongodb-on-os-x/

