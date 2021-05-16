---
title: "Ast2"
date: 2021-05-08T14:58:00+08:00
draft: true
---

# 复合类型

复合类型是指无法用一个标识符表示的类型，它们包含其它包中的基础类型（需要通过点号选择操作符）、指针类型、 数组类型、切片类型、结构体类型、map类型、管道类型、函数类型和接口类型，以及它们之间再次组合产生的更复杂的类型。





## 类型的语法

在基础类型声明章节我们已经简要学习过类型的声明语法规范，不过当时只讨论了基于标识符的简单声明。本章我们将继续探讨复合类型声明的语法和语法树的表示。以下是更为完整的类型声明的语法规范：

```
TypeDecl  = "type" ( TypeSpec | "(" { TypeSpec ";" } ")" ) .
TypeSpec  = AliasDecl | TypeDef .

AliasDecl = identifier "=" Type .
TypeDef   = identifier Type .

Type      = TypeName | TypeLit | "(" Type ")" .
TypeName  = identifier | PackageName "." identifier .
TypeLit   = PointerType | ArrayType | SliceType
          | StructType | MapType | ChannelType
          | FunctionType | InterfaceType
          .
```

增加的部分主要在TypeName和TypeLit。TypeName不仅仅可以从当前空间的标识符定义新类型，还支持从其它包导入的标识符定义类型。而TypeLit表示类型面值，比如基于已有类型的指针，或者是匿名的结构体都属于类型的面值。

如前文所描述，类型定义由`*ast.TypeSpec`结构体表示，复合类型也是如此。下面再来回顾下该结构体的定义：

```
type TypeSpec struct {
	Doc     *CommentGroup // associated documentation; or nil
	Name    *Ident        // type name
	Assign  token.Pos     // position of '=', if any; added in Go 1.9
	Type    Expr          // *Ident, *ParenExpr, *SelectorExpr, *StarExpr, or any of th *XxxTypes
	Comment *CommentGroup // line comments; or nil
}
```

其中Name成员表示给类型命名，Type通过特殊的类型表达式表示类型的定义，此外如果Assign被设置则表示声明的是类型的别名。





## 基础类型

基础类型在前面表述过了，这里就不重复了



## 指针类型

指针是操作底层类型时最强有力的武器，只要有指针就可以操作内存上的所有数据。最简单的是一级指针，然后再扩展出二级和更多级指针。以下是Go语言指针类型的语法规范：

```go
PointerType = "*" BaseType .
BaseType    = Type .

Type        = TypeName | TypeLit | "(" Type ")" .
```

指针类型以星号`*`开头，后面是BaseType定义的类型表达式。从语法规范角度看，Go语言没有单独定义多级指针，只有一种指向BaseType类型的一级指针。但是PointerType又可以作为TypeLit类型面值被重新用作BaseType，这就产生了多级指针的语法。

ex

```go
func main() {
	data := `package main
type IntPtr *int
	`
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, "hello.go", data, parser.AllErrors)
	if err != nil {
		log.Fatal(err)
	}

	for _, decl := range f.Decls {
		ast.Print(nil, decl.(*ast.GenDecl).Specs[0])
	}

}
```
out 

```
     0  *ast.TypeSpec {
     1  .  Name: *ast.Ident {
     2  .  .  NamePos: 19
     3  .  .  Name: "IntPtr"
     4  .  .  Obj: *ast.Object {
     5  .  .  .  Kind: type
     6  .  .  .  Name: "IntPtr"
     7  .  .  .  Decl: *(obj @ 0)
     8  .  .  }
     9  .  }
    10  .  Assign: 0
    11  .  Type: *ast.StarExpr {
    12  .  .  Star: 26
    13  .  .  X: *ast.Ident {
    14  .  .  .  NamePos: 27
    15  .  .  .  Name: "int"
    16  .  .  }
    17  .  }
    18  }

```



新类型的名字依然是普通的`*ast.Ident`标识符类型，其值是新类型的名字“IntPtr”。而`ast.TypeSpec.Type`成员则是新的`*ast.StarExpr`类型，其结构体定义如下：

```go
type StarExpr struct {
	Star token.Pos // position of "*"
	X    Expr      // operand
}
```



指针指向的X类型是一个递归定义的类型表达式。在这个例子中X就是一个`*ast.Ident`标识符类型表示的int，因此IntPtr类型是一个指向int类型的指针类型。

指针是一种天然递归定义的类型。我们可以再定义一个指向IntPtr类型的指针，它又是一个指向int类型的二级指针。但是在语法树表示时，指向IntPtr类型的一级指针和指向int类型的二级指针结构是不一样的，因为语法树解析器会将IntPtr和int都作为普通类型同等对待（语法树解析器只知道这是指向IntPtr类型的一级指针，而不知道它也是指向int类型的二级指针）。

下面的例子依然是在int类型基础之上定义二级指针：

```
type IntPtrPtr **int
```

解析后语法树发生的最大的差异在类型定义部分：

```go
     0  *ast.TypeSpec {
     1  .  Name: *ast.Ident {
     2  .  .  NamePos: 19
     3  .  .  Name: "IntPtr"
     4  .  .  Obj: *ast.Object {
     5  .  .  .  Kind: type
     6  .  .  .  Name: "IntPtr"
     7  .  .  .  Decl: *(obj @ 0)
     8  .  .  }
     9  .  }
    10  .  Assign: 0
    11  .  Type: *ast.StarExpr {
    12  .  .  Star: 26
    13  .  .  X: *ast.StarExpr {
    14  .  .  .  Star: 27
    15  .  .  .  X: *ast.Ident {
    16  .  .  .  .  NamePos: 28
    17  .  .  .  .  Name: "int"
    18  .  .  .  }
    19  .  .  }
    20  .  }
    21  }
```



## 数组类型

在传统的C/C++语言中，数组是和指针近似等同的类型，特别在传递参数时只传递数组的首地址。Go语言的数组类型是一种值类型，每次传递数组参数或者赋值都是生成数组的拷贝。但是从数组的语法定义角度看，它和指针类型也是非常相似的。以下是数组类型的语法规范：

```
ArrayType   = "[" ArrayLength "]" ElementType .
ArrayLength = Expression .
ElementType = Type .
```



简单的一维整型数组的例子：

```go
type IntArray [1]int 
```

out 

```go
     0  *ast.TypeSpec {
     1  .  Name: *ast.Ident {
     2  .  .  NamePos: 37
     3  .  .  Name: "IntArray"
     4  .  .  Obj: *ast.Object {
     5  .  .  .  Kind: type
     6  .  .  .  Name: "IntArray"
     7  .  .  .  Decl: *(obj @ 0)
     8  .  .  }
     9  .  }
    10  .  Assign: 0
    11  .  Type: *ast.ArrayType {
    12  .  .  Lbrack: 46
    13  .  .  Len: *ast.BasicLit {
    14  .  .  .  ValuePos: 47
    15  .  .  .  Kind: INT
    16  .  .  .  Value: "1"
    17  .  .  }
    18  .  .  Elt: *ast.Ident {
    19  .  .  .  NamePos: 49
    20  .  .  .  Name: "int"
    21  .  .  }
    22  .  }
    23  }
```

数组的类型主要由`*ast.ArrayType`类型定义。数组的长度是一个`*ast.BasicLit`类型的表达式，也就是长度为1的数组。数组元素的长度是`*ast.Ident`类型的标识符表示，数组的元素对应int类型。

完整的`*ast.ArrayType`结构体如下：

```go
type ArrayType struct {
	Lbrack token.Pos // position of "["
	Len    Expr      // Ellipsis node for [...]T array types, nil for slice types
	Elt    Expr      // element type
}
```



二维的数组

```go
type IntArrayArray [1][2]int
```

out 

```go
     0  *ast.TypeSpec {
     1  .  Name: *ast.Ident {
     2  .  .  NamePos: 78
     3  .  .  Name: "IntArray"
     4  .  .  Obj: *ast.Object {
     5  .  .  .  Kind: type
     6  .  .  .  Name: "IntArray"
     7  .  .  .  Decl: *(obj @ 0)
     8  .  .  }
     9  .  }
    10  .  Assign: 0
    11  .  Type: *ast.ArrayType {
    12  .  .  Lbrack: 87
    13  .  .  Len: *ast.BasicLit {
    14  .  .  .  ValuePos: 88
    15  .  .  .  Kind: INT
    16  .  .  .  Value: "1"
    17  .  .  }
    18  .  .  Elt: *ast.ArrayType {
    19  .  .  .  Lbrack: 90
    20  .  .  .  Len: *ast.BasicLit {
    21  .  .  .  .  ValuePos: 91
    22  .  .  .  .  Kind: INT
    23  .  .  .  .  Value: "2"
    24  .  .  .  }
    25  .  .  .  Elt: *ast.Ident {
    26  .  .  .  .  NamePos: 93
    27  .  .  .  .  Name: "int"
    28  .  .  .  }
    29  .  .  }
    30  .  }
    31  }

```

同样，数组元素的类型也变成了嵌套的数组类型。N维的数组类型的语法树也类似一个单向链表结构，后`N-1`维的数组的元素也是`*ast.ArrayType`类型，最后的尾结点对应一个`*ast.Ident`标识符（也可以是其它面值类型）。



## 切片类型

Go语言中切片是简化的数组，切片中引入了诸多数组不支持的语法。不过对于切片类型的定义来说，切片和数组的差异就是省略了数组的长度而已。切片类型声明的语法规则如下：

```go
SliceType   = "[" "]" ElementType .
ElementType = Type .
```

下面例子是定义一个int切片：

```
type IntSlice []int
```

out 

```go
     0  *ast.TypeSpec {
     1  .  Name: *ast.Ident {
     2  .  .  NamePos: 103
     3  .  .  Name: "IntSlice"
     4  .  .  Obj: *ast.Object {
     5  .  .  .  Kind: type
     6  .  .  .  Name: "IntSlice"
     7  .  .  .  Decl: *(obj @ 0)
     8  .  .  }
     9  .  }
    10  .  Assign: 0
    11  .  Type: *ast.ArrayType {
    12  .  .  Lbrack: 113
    13  .  .  Elt: *ast.Ident {
    14  .  .  .  NamePos: 115
    15  .  .  .  Name: "int"
    16  .  .  }
    17  .  }
    18  }
```

切片和数组一样，也是通过`*ast.ArrayType`结构表示切片，不过Len长度成员为nil类型（切片必须是nil，如果是0则表示是数组类型）。

