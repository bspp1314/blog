---
title: "UnionAndFind"
date: 2020-12-14T19:54:25+08:00
draft: true
---

# 什么是并查集



**并查集**是一种树型的数据结构，用于处理一些不交集（Disjoint Sets）的合并及查询问题。有一个**联合-查找算法**（**union-find algorithm**）定义了两个用于此数据结构的操作：

- Find：确定元素属于哪一个子集。它可以被用来确定两个元素是否属于同一子集。
- Union：将两个子集合并成同一个集合。



# 实现





```go
type unionSet struct {
	set []int
}


func NewUnionSet(size int) *unionSet {
	buf := make([]int, size)
	for i := 0; i < size; i++ {
		//每一个节点为一类集合
		buf[i] = i
	}
	return &unionSet{set: buf}
}

func (s *unionSet)GetSet() []int  {
	return s.set
}

func (s *unionSet) GetSize() int {
	return len(s.set)
}

func (s *unionSet) Find(i int) (int, error) {
	if i < 0 || i >  len(s.set) {
		return 0, fmt.Errorf("Index is illegal. ")
	}

	return s.set[i], nil
}

func main() {
	s := NewUnionSet(10)
	//Before union
	fmt.Println(s.GetSet())

	s.Union(0,1)
	s.Union(0,2)
	s.Union(0,3)

	fmt.Println(s.GetSet())

	s.Union(4,5)
	s.Union(4,6)
	s.Union(4,7)

	fmt.Println(s.GetSet())


	s.Union(2,4)

	fmt.Println(s.GetSet())

}

```

out 

```
[0 1 2 3 4 5 6 7 8 9]
[3 3 3 3 4 5 6 7 8 9]
[3 3 3 3 7 7 7 7 8 9]
[7 7 7 7 7 7 7 7 8 9]
```





Union 时间复杂度 $ O(n) $

Find时间复杂度 $ O(1) $



上面这种数组方法的实现由于采用完成的数组结构，导致其Union的时间复杂度为 $ O(n) $,时间复杂度过高，我们下面尝试用树来实现

```go
type unionSet struct {
	set []int
}

func NewUnionSet(size int) *unionSet {
	buf := make([]int, size)
	for i := 0; i < size; i++ {
		buf[i] = i  // 初始时，所有节点均指向自己
	}
	return &unionSet{set: buf}
}

func (s *unionSet)GetSet() []int  {
	return s.set
}


func (s *unionSet) Find(i int) (int, error) {
	if i < 0 || i >  len(s.set) {
		return 0, fmt.Errorf(
			"Index is illegal. ")
	}
	return s.getRoot(i), nil
}

func (s *unionSet) getRoot(i int) int {
    if s.set[i] == i {
    	return i
	}

	return  s.getRoot(s.set[i])
}

func (s *unionSet) IsConnected(i, j int) (bool, error) {
	if i < 0 || i > len(s.set) || j < 0 || j > len(s.set) {
		return false, fmt.Errorf(
			"Index is illegal. ")
	}

	return s.getRoot(s.set[i]) == s.getRoot(s.set[j]), nil
}

func (s *unionSet)Union(p,q int) error  {
	if p < 0 || p > len(s.set) || q < 0 || q > len(s.set) {
		return fmt.Errorf(
			"Index is illegal. ")
	}

	pRoot := s.getRoot(p)
	qRoot := s.getRoot(q)
	if pRoot != qRoot {
		s.set[pRoot] = qRoot
	}

	return nil
}




func main() {
	s := NewUnionSet(10)
	//Before union
	fmt.Println(s.GetSet())

	s.Union(0,1)
	s.Union(0,2)
	s.Union(0,3)

	fmt.Println(s.GetSet())

	s.Union(4,5)
	s.Union(4,6)
	s.Union(4,7)

	fmt.Println(s.GetSet())


	s.Union(2,4)

	fmt.Println(s.GetSet())
}
```





Union 时间复杂度 $ O(h) $

Find时间复杂度 $ O(h) $



相比第一版，这个时间复杂度更好接受，不过在极端的情况下，比如执行union(0,1),union(0,2)...union(0,n),这样树变成单链，



```go
type unionSet struct {
	rank []int // rank[i]表示以i为根的树的高度
	set  []int
}

func NewUnionSet(size int) *unionSet {
	u := &unionSet{
		rank: make([]int, size),
		set:  make([]int, size),
	}
	for i := 0; i < size; i++ {
		u.rank[i] = 1
		u.set[i] = 1
	}

	return u
}


func (s *unionSet)GetSet() []int  {
	return s.set
}


func (s *unionSet) Find(i int) (int, error) {
	if i < 0 || i >  len(s.set) {
		return 0, fmt.Errorf(
			"Index is illegal. ")
	}
	return s.getRoot(i), nil
}

func (s *unionSet) getRoot(i int) int {
	if s.set[i] == i {
		return i
	}

	return  s.getRoot(s.set[i])
}

func (s *unionSet) IsConnected(i, j int) (bool, error) {
	if i < 0 || i > len(s.set) || j < 0 || j > len(s.set) {
		return false, fmt.Errorf(
			"Index is illegal. ")
	}

	return s.getRoot(s.set[i]) == s.getRoot(s.set[j]), nil
}


func (s *unionSet)Union(i,j int) error  {
	if i < 0 || i > len(s.set) || j < 0 || j > len(s.set) {
		return fmt.Errorf(
			"Index is illegal. ")
	}

	iRoot := s.getRoot(i)
	jRoot := s.getRoot(j)
	if iRoot != jRoot {
		if s.rank[iRoot] < s.rank[jRoot] {
			s.set[iRoot] = jRoot
		}else if s.rank[jRoot] > s.rank[iRoot]{
			s.set[jRoot] = iRoot
		}else{
			s.set[iRoot] = jRoot
			s.rank[jRoot] += 1
		}
	}

	return nil
```







性能测试

```go
func BenchmarkUnionSet_Union1(b *testing.B) {

	for j := 0; j < b.N; j++ {
		count := 10000
		s := NewUnionSet(count)
		for i := 1; i < count; i++ {
			s.Find(i)
			s.Union(i-1, i)
		}
	}

}

func BenchmarkUnionSet_Union2(b *testing.B) {

	for j := 0; j < b.N; j++ {
		count := 10000
		s := NewUnionSet(count)
		for i := 1; i < count; i++ {
			s.Find(i)
			s.Union(0, i)
		}
	}
}


```



第一版的测试结果

```shell
$ go test -v -bench=BenchmarkUnionSet_Union1
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet1
BenchmarkUnionSet_Union1
BenchmarkUnionSet_Union1-4             1        7445523084 ns/op
PASS
ok      leetcode/unionSet/unionSet1     7.465s



$ go test -v -bench=BenchmarkUnionSet_Union2
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet1
BenchmarkUnionSet_Union2
BenchmarkUnionSet_Union2-4             1        9860798919 ns/op
PASS
ok      leetcode/unionSet/unionSet1     9.872s

```

第二版测试结果

```shell
go test -v -bench=BenchmarkUnionSet_Union1
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet2
BenchmarkUnionSet_Union1
BenchmarkUnionSet_Union1-4           680           1818219 ns/op
PASS
ok      leetcode/unionSet/unionSet2     2.394s



go test -v -bench=BenchmarkUnionSet_Union2
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet2
BenchmarkUnionSet_Union2
BenchmarkUnionSet_Union2-4             1        36078743385 ns/op
PASS
ok      leetcode/unionSet/unionSet2     36.090s


```



第三种测试结果

```shell
$ go test -v -bench=BenchmarkUnionSet_Union1
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet3
BenchmarkUnionSet_Union1
BenchmarkUnionSet_Union1-4           393           2969819 ns/op
PASS
ok      leetcode/unionSet/unionSet3     1.488s

$ go test -v -bench=BenchmarkUnionSet_Union2
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet3
BenchmarkUnionSet_Union2
BenchmarkUnionSet_Union2-4           398           2936240 ns/op
PASS
ok      leetcode/unionSet/unionSet3     1.485s
```



通过上面6组测试我们可以看出，第一版和第三版的性能都比较稳定，但是第三版的性能明显比较理想。而第二版的性能是很不稳定的，在不同的数据结构下性能相差巨大。



路径压缩优化

```go
type unionSet struct {
	rank []int // rank[i]表示以i为根的树的高度
	set  []int
}

func NewUnionSet(size int) *unionSet {
	u := &unionSet{
		rank: make([]int, size),
		set:  make([]int, size),
	}
	for i := 0; i < size; i++ {
		u.rank[i] = 1
		u.set[i] = 1
	}

	return u
}


func (s *unionSet)GetSet() []int  {
	return s.set
}


func (s *unionSet) Find(i int) (int, error) {
	if i < 0 || i >  len(s.set) {
		return 0, fmt.Errorf(
			"Index is illegal. ")
	}
	return s.getRoot(i), nil
}

func (s *unionSet) getRoot(i int) int {
	for i != s.set[i] {
		// i->parent = i->parent->parent
		s.set[i] = s.set[s.set[i]]
		i = s.set[i]
	}

	return i
}

func (s *unionSet) IsConnected(i, j int) (bool, error) {
	if i < 0 || i > len(s.set) || j < 0 || j > len(s.set) {
		return false, fmt.Errorf(
			"Index is illegal. ")
	}

	return s.getRoot(s.set[i]) == s.getRoot(s.set[j]), nil
}


func (s *unionSet)Union(i,j int) error  {
	if i < 0 || i > len(s.set) || j < 0 || j > len(s.set) {
		return fmt.Errorf(
			"Index is illegal. ")
	}

	iRoot := s.getRoot(i)
	jRoot := s.getRoot(j)
	if iRoot != jRoot {
		if s.rank[iRoot] < s.rank[jRoot] {
			s.set[iRoot] = jRoot
		}else if s.rank[jRoot] > s.rank[iRoot]{
			s.set[jRoot] = iRoot
		}else{
			s.set[iRoot] = jRoot
			s.rank[jRoot] += 1
		}
	}

	return nil
}
```





测试结果

```shell
$ go test -v -bench=BenchmarkUnionSet_Union1
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet4
BenchmarkUnionSet_Union1
BenchmarkUnionSet_Union1-4           440           2758189 ns/op
PASS
ok      leetcode/unionSet/unionSet4     1.510s


$ go test -v -bench=BenchmarkUnionSet_Union2
goos: darwin
goarch: amd64
pkg: leetcode/unionSet/unionSet4
BenchmarkUnionSet_Union2
BenchmarkUnionSet_Union2-4           444           2970202 ns/op
PASS
ok      leetcode/unionSet/unionSet4     1.604s
```










# 参考



并查集 https://zh.wikipedia.org/wiki/%E5%B9%B6%E6%9F%A5%E9%9B%86

并查集 https://en.wikipedia.org/wiki/Disjoint-set_data_structure

并查集 https://www.geeksforgeeks.org/union-find/?ref=lbp