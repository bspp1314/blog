---
title: "Go常见库之logrus"
date: 2020-09-15T17:39:25+08:00
draft: false
draft: false
categories: ["golang","golang常见库"]
tags: ["日志"]
---

# 简介

logrus 其是一个 golang 结构化后的日志包，API完全兼容标准包logger。<!--more-->



# 简单使用

下载包

```go
go get github.com/sirupsen/logrus
```



```go
package main

import (
	 "github.com/sirupsen/logrus"
)

func main() {
	logrus.SetLevel(logrus.TraceLevel)
	logrus.Trace("trace msg")
	logrus.Debug("debug msg")
	logrus.Info("info msg")
	logrus.Warn("warn msg")
	logrus.Error("error msg")
	logrus.Fatal("fatal msg")
	logrus.Panic("panic msg")
}
```



out 

```go
TRAC[0000] trace msg                                    
DEBU[0000] debug msg                                    
INFO[0000] info msg                                     
WARN[0000] warn msg                                     
ERRO[0000] error msg                                    
FATA[0000] fatal msg     
```

备注：由于logrus.Fatal 会导致程序退出，下面的 logrus.Panic不会执行到。



logrus 的使用非常简单，与标准库 log 类似。logrus支持更多的日志级别。日志级别从上向下依次增加，Trace 最大，Panic 最小。 logrus 有一个日志级别，高于这个级别的日志不会输出。 默认的级别为 InfoLevel。 

```go
// These are the different logging levels. You can set the logging level to log
// on your instance of logger, obtained with `logrus.New()`.
const (
	// PanicLevel level, highest level of severity. Logs and then calls panic with the
	// message passed to Debug, Info, ...
	PanicLevel Level = iota
	// FatalLevel level. Logs and then calls `logger.Exit(1)`. It will exit even if the
	// logging level is set to Panic.
	FatalLevel
	// ErrorLevel level. Logs. Used for errors that should definitely be noted.
	// Commonly used for hooks to send errors to an error tracking service.
	ErrorLevel
	// WarnLevel level. Non-critical entries that deserve eyes.
	WarnLevel
	// InfoLevel level. General operational entries about what's going on inside the
	// application.
	InfoLevel
	// DebugLevel level. Usually only enabled when debugging. Very verbose logging.
	DebugLevel
	// TraceLevel level. Designates finer-grained informational events than the Debug.
	TraceLevel
)
```





# 输出文件名和方法

调用 SetReportCaller(true) 设置在输出日志中添加文件名和方法信息：

```go
func NewLogger() *logrus.Logger {
	f,_ := os.OpenFile("./out.log",os.O_RDWR | os.O_CREATE,0664)

	l := logrus.New()
	l.Out = f

	return l
}

func main() {
	logger := NewLogger()
	logger.SetReportCaller(true)
	logger.Info("info msg")
}
```



out 

```
time="2020-09-15T18:50:53+08:00" level=info msg="info msg" func=main.main file="/Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/logrus-lib/ex2.go:20"
```

# 添加字段

有时候需要在输出中添加一些字段，可以通过调用 WithField 和 WithFields 实现。

```go
func NewLogger() *logrus.Logger {
	f,_ := os.OpenFile("./out.log",os.O_RDWR | os.O_CREATE,0664)

	l := logrus.New()
	l.Out = f

	return l
}

func main() {
	logger := NewLogger()
	logger.SetReportCaller(true)
	fieldLogger := logger.WithFields(logrus.Fields{
		"user_id":10,
	})
	fieldLogger.Info("info msg")
}
```



out :

```
time="2020-09-15T19:04:10+08:00" level=info msg="info msg" func=main.main file="/Users/linyuanpeng/workplace/go/src/github.com/bspp1314/go-common-lib/logrus-lib/ex3.go:23" user_id=10
```



调用WithFields 或 WithField 会生成一个 Entry 的结构体，该结构体中包含Logger 结构体

```go
func (logger *Logger) WithFields(fields Fields) *Entry {
	entry := logger.newEntry()
	defer logger.releaseEntry(entry)
	return entry.WithFields(fields)
}

func (logger *Logger) WithField(key string, value interface{}) *Entry {
	entry := logger.newEntry()
	defer logger.releaseEntry(entry)
	return entry.WithField(key, value)
}

type Entry struct {
	Logger *Logger

	// Contains all the fields set by the user.
	Data Fields

	// Time at which the log entry was created
	Time time.Time

	// Level the log entry was logged at: Trace, Debug, Info, Warn, Error, Fatal or Panic
	// This field will be set on entry firing and the value will be equal to the one in Logger struct field.
	Level Level

	// Calling method, with package name
	Caller *runtime.Frame

	// Message passed to Trace, Debug, Info, Warn, Error, Fatal or Panic
	Message string

	// When formatter is called in entry.log(), a Buffer may be set to entry
	Buffer *bytes.Buffer

	// Contains the context set by the user. Useful for hook processing etc.
	Context context.Context

	// err may contain a field formatting error
	err string
}
```





# 日志格式

logrus 支持两种日志格式，文本和 JSON，默认为文本格式。可以通过 Formatter 设置日志格式。由于在日常开发中，比较常用到的Json格式，所以这里主要关注的是Json格式。

例子

```go
// 将日志中记录的文件名 file 和方法名 func 转成短名字
func CallerPretty(caller *runtime.Frame) (function string, file string) {
	if caller == nil {
		return "", ""
	}

	short := caller.File
	i := strings.LastIndex(caller.File, "/")
	if i != -1 && i != len(caller.File)-1 {
		short = caller.File[i+1:]
	}

	fun := caller.Function
	j := strings.LastIndex(caller.Function, "/")
	if j != -1 && j != len(caller.Function)-1 {
		fun = caller.Function[j+1:]
	}

	return fun, fmt.Sprintf("%s:%d", short, caller.Line)
}

func NewLogger() *logrus.Logger {
	l := logrus.New()
	l.Out = os.Stdout
	l.Formatter = &logrus.JSONFormatter{
		TimestampFormat:   "2006-01-02 15:04:05",
		DisableTimestamp:  false,
		DisableHTMLEscape: false,
		DataKey:           "UserField",
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyLevel:       "Level",
			logrus.FieldKeyFunc:        "Func",
			logrus.FieldKeyFile:        "File",
			logrus.FieldKeyMsg:         "Msg",
			logrus.FieldKeyLogrusError: "Time",
		},
		CallerPrettyfier: nil,
		PrettyPrint:      true,
	}

	return l
}

func main() {
	logger := NewLogger()
	logger.SetReportCaller(true)
	fieldLogger := logger.WithFields(logrus.Fields{
		"user_id": 10,
	})
	fieldLogger.Info("info msg")
}
```

out 

```go
{
  "File": "ex4.go:61",
  "Func": "main.main",
  "Level": "info",
  "Msg": "info msg",
  "UserField": {
    "user_id": 10
  },
  "time": "2020-09-15 23:46:29"
}
```

JSONFormatter 格式如下

```go
type JSONFormatter struct {
	// TimestampFormat sets the format used for marshaling timestamps.
	TimestampFormat string 

	// DisableTimestamp allows disabling automatic timestamps in output
	DisableTimestamp bool

	// DisableHTMLEscape allows disabling html escaping in output
	DisableHTMLEscape bool

	// DataKey allows users to put all the log entry parameters into a nested dictionary at a given key.
	DataKey string

	// FieldMap allows users to customize the names of keys for default fields.
	// As an example:
	// formatter := &JSONFormatter{
	//   	FieldMap: FieldMap{
	// 		 FieldKeyTime:  "@timestamp",
	// 		 FieldKeyLevel: "@level",
	// 		 FieldKeyMsg:   "@message",
	// 		 FieldKeyFunc:  "@caller",
	//    },
	// }
	FieldMap FieldMap

	// CallerPrettyfier can be set by the user to modify the content
	// of the function and file keys in the json data when ReportCaller is
	// activated. If any of the returned value is the empty string the
	// corresponding key will be removed from json fields.
	CallerPrettyfier func(*runtime.Frame) (function string, file string)

	// PrettyPrint will indent all json logs
	PrettyPrint bool
}

```

TimestampFormat 设置时间格式

DisableTimestamp 是否关闭时间输出

DisableHTMLEscape 是否关闭HTML 转义

DataKey    许用户将所有日志条目参数放入一个嵌套字典中，并按给定的键。

FieldMap允许用户自定义默认字段的键的名称。

CallerPrettyfier 用来修正代码所在的函数名和文件

PrettyPrint 是否进行Json 缩进

# 设置钩子

还可以为 logrus 设置钩子，每条日志输出前都会执行钩子的特定方法。所以，我们可以添加输出字段、根据级别将日志输出到不同的目的地。 



钩子需要实现 logrus.Hook 接口：

```go
type Hook interface {
  Levels() []Level
  Fire(*Entry) error
}
```

Levels() 方法返回感兴趣的日志级别，输出其他日志时不会触发钩子。Fire是日志输出前调用的钩子方法。我们可以自己实现一个简单的Hook 接口

```go
// 将日志中记录的文件名 file 和方法名 func 转成短名字
func CallerPretty(caller *runtime.Frame) (function string, file string) {
	if caller == nil {
		return "", ""
	}

	short := caller.File
	i := strings.LastIndex(caller.File, "/")
	if i != -1 && i != len(caller.File)-1 {
		short = caller.File[i+1:]
	}

	fun := caller.Function
	j := strings.LastIndex(caller.Function, "/")
	if j != -1 && j != len(caller.Function)-1 {
		fun = caller.Function[j+1:]
	}

	return fun, fmt.Sprintf("%s:%d", short, caller.Line)
}

type ServerName struct {
	ServerName string `json:"server_name"`
}

func (s *ServerName) Levels()[]logrus.Level  {
	return logrus.AllLevels
}

func (s *ServerName) Fire(entry *logrus.Entry) error {
	entry.Data["server-name"] = s.ServerName
	return nil
}


func NewLogger() *logrus.Logger {
	l := logrus.New()
	l.Out = os.Stdout
	l.Formatter = &logrus.JSONFormatter{
		TimestampFormat:   "2006-01-02 15:04:05",
		DisableTimestamp:  false,
		DisableHTMLEscape: false,
		DataKey:           "UserField",
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyLevel:       "Level",
			logrus.FieldKeyFunc:        "Func",
			logrus.FieldKeyFile:        "File",
			logrus.FieldKeyMsg:         "Msg",
			logrus.FieldKeyLogrusError: "Time",
		},
		CallerPrettyfier: CallerPretty,
		PrettyPrint:      true,
	}
	l.AddHook(&ServerName{ServerName: "polaris"})

	return l
}

```

out 

```go
{
  "File": "ex5.go:76",
  "Func": "main.main",
  "Level": "info",
  "Msg": "info msg",
  "UserField": {
    "server-name": "polaris",
    "user_id": 10
  },
  "time": "2020-09-15 23:57:09"
}

```



logrus的第三方 Hook 很多，我们可以使用一些 Hook 将日志发送到 redis/mongodb 等存储中：

- [mgorus](https://github.com/weekface/mgorus)：将日志发送到 mongodb；
- [logrus-redis-hook](https://github.com/rogierlommers/logrus-redis-hook)：将日志发送到 redis；
- [logrus-amqp](https://github.com/vladoatanasov/logrus_amqp)：将日志发送到 ActiveMQ。

# 源码分析

## Logger 结构体

Logger 是logrus 中重要的一个结构体，可以通过New 来创建

```go
type Logger struct {
	// The logs are `io.Copy`'d to this in a mutex. It's common to set this to a
	// file, or leave it default which is `os.Stderr`. You can also set this to
	// something more adventurous, such as logging to Kafka.
	Out io.Writer
	// Hooks for the logger instance. These allow firing events based on logging
	// levels and log entries. For example, to send errors to an error tracking
	// service, log to StatsD or dump the core on fatal errors.
	Hooks LevelHooks
	// All log entries pass through the formatter before logged to Out. The
	// included formatters are `TextFormatter` and `JSONFormatter` for which
	// TextFormatter is the default. In development (when a TTY is attached) it
	// logs with colors, but to a file it wouldn't. You can easily implement your
	// own that implements the `Formatter` interface, see the `README` or included
	// formatters for examples.
	Formatter Formatter

	// Flag for whether to log caller info (off by default)
	ReportCaller bool

	// The logging level the logger should log at. This is typically (and defaults
	// to) `logrus.Info`, which allows Info(), Warn(), Error() and Fatal() to be
	// logged.
	Level Level
	// Used to sync writing to the log. Locking is enabled by Default
	mu MutexWrap
	// Reusable empty entry
	entryPool sync.Pool
	// Function to exit the application, defaults to `os.Exit()`
	ExitFunc exitFunc
}

```

Out  输出的IO 接口

Hooks 钩子接口

Formatter 格式化接口 

ReportCaller 是否输出日志中添加文件名和方法信息

Level 级别

mu 用于同步写入到日志。默认情况下是启用锁定的

entryPool  用来解决Entry gc压



## 一个简单的 (logger *Logger) Info调用过程



```go
// first 
func (logger *Logger) Info(args ...interface{}) {
	logger.Log(InfoLevel, args...)
}

//second 
func (logger *Logger) Log(level Level, args ...interface{}) {
	if logger.IsLevelEnabled(level) {
		entry := logger.newEntry()  
		entry.Log(level, args...)
		logger.releaseEntry(entry)
	}
}

//third 
func (entry *Entry) Log(level Level, args ...interface{}) {
	if entry.Logger.IsLevelEnabled(level) {
		entry.log(level, fmt.Sprint(args...))
	}
}

//four 
ffunc (entry Entry) log(level Level, msg string) {
	.....
  
	entry.Level = level
	entry.Message = msg
	entry.Logger.mu.Lock()
  //判断是否需要调用函数
	if entry.Logger.ReportCaller {
		entry.Caller = getCaller()
	}
	entry.Logger.mu.Unlock()

  //执行钩子
	entry.fireHooks()

 // 写日志
	entry.write()

	entry.Buffer = nil
	.... 
}

// five 
func (entry *Entry) write() {
	entry.Logger.mu.Lock()
	defer entry.Logger.mu.Unlock()
  // 格式化日志
	serialized, err := entry.Logger.Formatter.Format(entry)
	if err != nil {
    // 日志输出
		fmt.Fprintf(os.Stderr, "Failed to obtain reader, %v\n", err)
		return
	}
	if _, err = entry.Logger.Out.Write(serialized); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write to log, %v\n", err)
	}
}

```

虽说我们New出来的是Logger类型, 但logrus真正执行者却是 Entry 。Logger 有两个比较重要的函数 newEntry, releaseEntry, logrus所有的log函数, 比如:  Info, Error.... 最终都会调用这两个函数

## newEntry && releaseEntry

```go
func (logger *Logger) newEntry() *Entry {
	entry, ok := logger.entryPool.Get().(*Entry)
	if ok {
		return entry
	}
	return NewEntry(logger)
}

func (logger *Logger) releaseEntry(entry *Entry) {
	entry.Data = map[string]interface{}{}
	logger.entryPool.Put(entry)
}

```

Logger使用到了 sync.Pool, 用来解决频繁创建/释放Entry对象造成的gc的压力。

当我们使用logrus log相关函数时, 必定会调用到 logger.Log() 函数, 该函数会调用 newEntry() 来申请Pool内存, 调用完成后会再调用 releaseEntry() 返还给PoolEnrty 

## Entry 
```go
type Entry struct {
	Logger *Logger  

	// Contains all the fields set by the user.
	Data Fields

	// Time at which the log entry was created
	Time time.Time

	// Level the log entry was logged at: Trace, Debug, Info, Warn, Error, Fatal or Panic
	// This field will be set on entry firing and the value will be equal to the one in Logger struct field.
	Level Level

	// Calling method, with package name
	Caller *runtime.Frame

	// Message passed to Trace, Debug, Info, Warn, Error, Fatal or Panic
	Message string

	// When formatter is called in entry.log(), a Buffer may be set to entry
	Buffer *bytes.Buffer

	// Contains the context set by the user. Useful for hook processing etc.
	Context context.Context

	// err may contain a field formatting error
	err string
}
```



Logger 指向创建 Logger 结构体的指针

Entry    Entry 的创建时间

Level   级别

Caller 和调用方法所在的文件和函数相关

Message 需要输出的信息

Buffer 提供给各种Formatter使用, 其实就是真正要打印的日志的内存地址

Context  提供给logrus.WithTime, logrus.WithContext使用

err string   提供一个能够包含错误信息的字段

## 创建 Entry 
```
func NewEntry(logger *Logger) *Entry {
	return &Entry{
		Logger: logger,
		// Default is three fields, plus one optional.  Give a little extra room.
		Data: make(Fields, 6),
	}
}

```

注意到到Data其实就是map[string]interface{}, 其预先分配了6个空间(预先给make函数⼀一个合理元素数量参数，有助于提升性能。因为事先申请⼀一⼤大块内存， 可避免后续操作时频繁扩张。



# 参考连接

源码 https://github.com/sirupsen/logrus

官方文档 https://godoc.org/github.com/sirupsen/logrus

Logrus源码阅读(2)--logrus生命周期 https://www.haohongfan.com/post/2019-10-05-logrus-life-cycle/

