---

title: "Etcd Raft 各类消息"
date: 2021-04-20T10:23:58+08:00
draft: true
---

# 一些概念

Raft  中的概念

| 英文      | 中文                        |
| --------- | --------------------------- |
| Term      | 选举任期，每次选举之后递增1 |
| Vote      | 选举投票(的ID)              |
| Entry     | Raft算法的日志数据条目      |
| candidate | 候选人                      |
| leader    | 领导者                      |
| follower  | 跟随者                      |
| commit    | 提交                        |
| propose   | 提议                        |



raft.Node 接口 ，由 raft.node 实现

| 函数              | 作用                                                         |
| ----------------- | ------------------------------------------------------------ |
| Tick              | 应用层每次tick时需要调用该函数，将会由这里驱动raft的一些操作比如选举等。至于tick的单位是多少由应用层自己决定，只要保证是恒定时间都会来调用一次就好了。 |
| Campaign          | 调用该函数将驱动节点进入候选人状态，进而将竞争leader。       |
| Propose           | 提议写入数据到日志中，可能会返回错误。                       |
| ProposeConfChange | 提交配置变更                                                 |
| Step              | 将消息msg灌入状态机中                                        |
| Ready             | 这里是核心函数，将返回Ready的channel，应用层需要关注这个channel，当发生变更时将其中的数据进行操作 |
| Advance           | Advance函数是当使用者已经将上一次Ready数据处理之后，调用该函数告诉raft库可以进行下一步的操作 |

 

Ready 结构体

```go

// Ready encapsulates the entries and messages that are ready to read,
// be saved to stable storage, committed or sent to other peers.
// All fields in Ready are read-only.
type Ready struct {
	// The current volatile state of a Node.
	// SoftState will be nil if there is no update.
	// It is not required to consume or store SoftState.
	*SoftState

	// The current state of a Node to be saved to stable storage BEFORE
	// Messages are sent.
	// HardState will be equal to empty state if there is no update.
	pb.HardState

	// ReadStates can be used for node to serve linearizable read requests locally
	// when its applied index is greater than the index in ReadState.
	// Note that the readState will be returned when raft receives msgReadIndex.
	// The returned is only valid for the request that requested to read.
	ReadStates []ReadState

	// Entries specifies entries to be saved to stable storage BEFORE
	// Messages are sent.
	Entries []pb.Entry

	// Snapshot specifies the snapshot to be saved to stable storage.
	Snapshot pb.Snapshot

	// CommittedEntries specifies entries to be committed to a
	// store/state-machine. These have previously been committed to stable
	// store.
	CommittedEntries []pb.Entry

	// Messages specifies outbound messages to be sent AFTER Entries are
	// committed to stable storage.
	// If it contains a MsgSnap message, the application MUST report back to raft
	// when the snapshot has been received or has failed by calling ReportSnapshot.
	Messages []pb.Message

	// MustSync indicates whether the HardState and Entries must be synchronously
	// written to disk or if an asynchronous write is permissible.
	MustSync bool
}

```



- SoftState 软状态，软状态易变且不需要保存在WAL日志中的状态数据，包括：集群leader、节点的当前状态
- HardState 硬状态，与软状态相反，需要写入持久化存储中，包括：节点当前Term、Vote、Commit
- ReadStates 用于读一致性的数据
- Entries  在向其他集群发送消息之前需要先写入持久化存储的日志数据
- Snapshot 在向其他集群发送消息之前需要先写入持久化存储的日志数据
- CommittedEntries 需要输入到状态机中的数据，这些数据之前已经被保存到持久化存储中了
- Messages  在entries被写入持久化存储中以后，需要发送出去的数据







# Raft 库代码结构和核心数据结构



| 结构体/接口 | 所在文件     | 作用                                                         |
| ----------- | ------------ | ------------------------------------------------------------ |
| Node接口    | node.go      | 提供raft库与外界交互的接口                                   |
| node        | node.go      | 实现Node接口                                                 |
| Config      | raft.go      | 封装raft算法相关配置参数                                     |
| raft        | raft.go      | raft算法的实现                                               |
| ReadState   | read_only.go | 线性一致性读相关                                             |
| readOnly    | read_only.go | 线性一致性读相关                                             |
| raftLog     | log.go       | 实现raft日志操作                                             |
| Progress    | progress.go  | 该数据结构用于在leader中保存每个follower的状态信息，leader将根据这些信息决定发送给节点的日志 |
| Storage接口 |              |                                                              |





# Raft库日志存储相关结构

##  raftLog

`raftLog`为`raft`协议核心处理日志复制提供接口，`raft`协议库对日志的操作都基于`raftLog`实施。

 ```go
type raftLog struct {
	//包含从上一次快照以来的所有已被持久化的日志项集合
	//storage contains all stable entries since the last snapshot.
	//
	storage Storage

	// unstable contains all unstable entries and snapshot.
	// they will be saved into storage.
	unstable unstable

	// committed is the highest log position that is known to be in
	// stable storage on a quorum of nodes.
	//被持久化的最高的日志项的索引编号，需要注意，提交索引是集群的一个状态，而不是某一节点的状态.
	committed uint64
	// applied is the highest log position that the application has
	// been instructed to apply to its state machine.
	// Invariant: applied <= committed
	// 已经被应用程序应用到状态机的最高手日志项索引编号。应用索引是节点状态(非集群状态)，这取决于每个节点的应用速度。
	applied uint64

	logger Logger

	// 调用 nextEnts 时，返回的日志项集合的最大的大小
	// nextEnts 函数返回应用程序已经可以应用到状态机的日志项集合
	// maxNextEntsSize is the maximum number aggregate byte size of the messages
	// returned from calls to nextEnts.
	maxNextEntsSize uint64
}
 ```



## unstable 

unstable数据结构用于还没有被用户层持久化的数据，

```go
// unstable.entries[i] has raft log position i+unstable.offset.
// Note that unstable.offset may be less than the highest log
// position in storage; this means that the next write to storage
// might need to truncate the log before persisting unstable.entries.
type unstable struct {
	// the incoming unstable snapshot, if any.
	snapshot *pb.Snapshot
	// all entries that have not yet been written to storage.
	entries []pb.Entry
	offset  uint64

	logger Logger
}

type Entry struct {
	Term  uint64    `protobuf:"varint,2,opt,name=Term" json:"Term"` //任期
	Index uint64    `protobuf:"varint,3,opt,name=Index" json:"Index"`//索引
	Type  EntryType `protobuf:"varint,1,opt,name=Type,enum=raftpb.EntryType" json:"Type"` //类型
	Data  []byte    `protobuf:"bytes,4,opt,name=Data" json:"Data,omitempty"` //数据
}
```



- snapshot 快照数据

- entries 日志条目组成的数组 

- offset   entries中第一条entry记录的索引值，即第i条entries数组数据在raft日志中的索引为i + unstable.offset。

  
## Storage && MemoryStorage 
Storage表示etcd-raft提供的持久化存储的接口。应用程序负责实现此接口，以将日志信息落盘。并且，若在操作过程此持久化存储时出现错误，则应用程序应该停止对相应的 raft 实例的操作，并需要执行清理或恢复的操作。其数据结构如下
```
// Storage is an interface that may be implemented by the application
// to retrieve log entries from storage.
//
// If any Storage method returns an error, the raft instance will
// become inoperable and refuse to participate in elections; the
// application is responsible for cleanup and recovery in this case.
type Storage interface {
	// TODO(tbg): split this into two interfaces, LogStorage and StateStorage.
	//// 返回 HardState 及 ConfState 数据
	// InitialState returns the saved HardState and ConfState information.
	InitialState() (pb.HardState, pb.ConfState, error)
	// Entries returns a slice of log entries in the range [lo,hi).
	// MaxSize limits the total size of the log entries returned, but
	// Entries returns at least one entry if any.
	//返回 [lo, hi) 范围的日志项集合
	Entries(lo, hi, maxSize uint64) ([]pb.Entry, error)
	// Term returns the term of entry i, which must be in the range
	// [FirstIndex()-1, LastIndex()]. The term of the entry before
	// FirstIndex is retained for matching purposes even though the
	// rest of that entry may not be available.
	//返回指定日志项索引的 term
	Term(i uint64) (uint64, error)
	// LastIndex returns the index of the last entry in the log.
	//返回日志项中最后一条日志的索引编号
	LastIndex() (uint64, error)
	// FirstIndex returns the index of the first log entry that is
	// possibly available via Entries (older entries have been incorporated
	// into the latest Snapshot; if storage only contains the dummy entry the
	// first log entry is not available).
	//返回日志项中最后第一条日志的索引编号，注意在其被创建时，日志项集合会被填充一项 dummy entry
	FirstIndex() (uint64, error)
	// Snapshot returns the most recent snapshot.
	// If snapshot is temporarily unavailable, it should return ErrSnapshotTemporarilyUnavailable,
	// so raft state machine could know that Storage needs some time to prepare
	// snapshot and call Snapshot later.
	// 返回最近一次的快照数据，如果快照不可用，则返回出错
	Snapshot() (pb.Snapshot, error)
}
```


  



# 消息机制

raft算法本质上是一个大的状态机，任何的操作例如选举、提交数据等，最后的操作一定是封装成一个消息结构体，输入到raft算法库的状态机中。在raft/raftpb/raft.proto文件中，定义了raft算法中传输消息的结构体，最终胜出的Message 结构体如下：



```go
type Message struct {
   // 消息类型
   Type MessageType `protobuf:"varint,1,opt,name=type,enum=raftpb.MessageType" json:"type"`
   // 消息接收者的ID
   To   uint64      `protobuf:"varint,2,opt,name=to" json:"to"`
   // 消息发送者的ID
   From uint64      `protobuf:"varint,3,opt,name=from" json:"from"`
   //任期ID
   Term uint64      `protobuf:"varint,4,opt,name=term" json:"term"`
   // logTerm is generally used for appending Raft logs to followers. For example,
   // (type=MsgApp,index=100,logTerm=5) means leader appends entries starting at
   // index=101, and the term of entry at index 100 is 5.
   // (type=MsgAppResp,reject=true,index=100,logTerm=5) means follower rejects some
   // entries from its leader as it already has an entry with term 5 at index 100.
   //日志所处的任期ID
   LogTerm    uint64   `protobuf:"varint,5,opt,name=logTerm" json:"logTerm"`
   //日志所处于的索引
   Index      uint64   `protobuf:"varint,6,opt,name=index" json:"index"`
   // 日志条目数组
   Entries    []Entry  `protobuf:"bytes,7,rep,name=entries" json:"entries"`
   //提交日志的索引
   Commit     uint64   `protobuf:"varint,8,opt,name=commit" json:"commit"`
   //快照数据
   Snapshot   Snapshot `protobuf:"bytes,9,opt,name=snapshot" json:"snapshot"`
   //是否拒绝

   Reject     bool     `protobuf:"varint,10,opt,name=reject" json:"reject"`
   RejectHint uint64   `protobuf:"varint,11,opt,name=rejectHint" json:"rejectHint"`
   //上下文内容
   Context    []byte   `protobuf:"bytes,12,opt,name=context" json:"context,omitempty"`
}
```

由于这个Message结构体，全部将raft协议相关的数据都定义在了一起，有些协议不是用到其中的全部数据，所以这里的字段都是optinal的。Message中的每个消息类型都在raft/doc.go 中有说明，下面将依次分析



## MsgHub 

>  'MsgHup' is used for election. If a node is a follower or candidate, the 'tick' function in 'raft' struct is set as 'tickElection'. If a follower or candidate has not received any heartbeat before the election timeout, it passes 'MsgHup' to its Step method and becomes (or remains) a candidate to start a new election.

MsgHub 消息是用来通知本节点发起选举。当一个节点处于follower 或者 candidate ，当该节点tick在规定时间之内没有收到lead 发送过来的心跳包，tick 就会MsgHug 给状态机发起选择消息。



| 成员 | 类型   | 作用                                                         |
| ---- | ------ | ------------------------------------------------------------ |
| type | MsgHup | MsgHub 消息是用来通知本节点发起选举。当一个节点处于follower 或者 candidate ，当该节点tick在规定时间之内没有收到lead 发送过来的心跳包，tick 就会MsgHug 给状态机发起选择消息。 |
| to   | uint64 | 消息接收者的节点ID                                           |
| from | uint64 | 本节点ID                                                     |



从sever 层发起通知

```go
// raft.Node does not have locks in Raft package
func (r *raftNode) tick() {
	r.tickMu.Lock()
	r.Tick()
	r.tickMu.Unlock()
}

/ start prepares and starts raftNode in a new goroutine. It is no longer safe
// to modify the fields after it has been started.
func (r *raftNode) start(rh *raftReadyHandler) {
	internalTimeout := time.Second

	go func() {
		defer r.onStop()
		islead := false

		for {
			select {
       //启动一个ticker ，这个时间间隔就是心跳包时间间隔
			case <-r.ticker.C:
				r.tick()
		}
      
      ......
}
   
// raft.Node does not have locks in Raft package
func (r *raftNode) tick() {
	r.tickMu.Lock()
  //调用raft.Node 的Tick时钟
	r.Tick()
	r.tickMu.Unlock()
}    

// Tick increments the internal logical clock for this Node. Election timeouts
// and heartbeat timeouts are in units of ticks.
func (n *node) Tick() {
	select {
	case n.tickc <- struct{}{}:
	case <-n.done:
	default:
		n.rn.raft.logger.Warningf("%x A tick missed to fire. Node blocks too long!", n.rn.raft.id)
	}
}
```

在 raft.node.Run 里面接收

```go
func (n *node) run() {
		// .....
		select {
		case <-n.tickc:
      n.rn.Tick()
}

// Tick advances the internal logical clock by a single tick.
func (rn *RawNode) Tick() {
	rn.raft.tick() 
}
  
func (r *raft) becomeFollower(term uint64, lead uint64) {
	r.step = stepFollower
	r.reset(term)
	r.tick = r.tickElection
	r.lead = lead
	r.state = StateFollower
	r.logger.Infof("%x became follower at term %d", r.id, r.Term)
}



```



尝试启动选举/启动选举

```go
func (r *raft) tickElection() {
	r.electionElapsed++

	//该节点具备成为leader的资格 && node 节点在开始改变转态之前，会有一个随机时间等等，这样做是为了避免多个节点瓜分选票的问题
	if r.promotable() && r.pastElectionTimeout() {
		r.electionElapsed = 0
		r.Step(pb.Message{From: r.id, Type: pb.MsgHup})
	}
}
// pastElectionTimeout returns true if r.electionElapsed is greater
// than or equal to the randomized election timeout in
// [electiontimeout, 2 * electiontimeout - 1].
func (r *raft) pastElectionTimeout() bool {
  //electiontimeout 在raft是一个逻辑时钟,
	// 这个逻辑时钟和是和配置文件里的 heartbeat-interval election-timeout 相关的
	// electiontimeout =  election-timeout /  heartbeat-interval 这里 election-timeout 至少是 heartbeat-interval  的五倍
  return r.electionElapsed >= r.randomizedElectionTimeout
}
```



## MsgBeat


> 'MsgBeat' is an internal type that signals the leader to send a heartbeat of the 'MsgHeartbeat' type. If a node is a leader, the 'tick' function in the 'raft' struct is set as 'tickHeartbeat', and triggers the leader to
send periodic 'MsgHeartbeat' messages to its followers.



| 成员 | 类型    | 作用                                                         |
| ---- | ------- | ------------------------------------------------------------ |
| type | MsgBeat | 用于leader节点在heartbeat定时器到期时向集群中其他节点发送心跳消息 |
| to   | uint64  | 消息接收者的节点ID                                           |
| from | uint64  | 本节点ID                                                     |


lead 节点发起心跳

```go
// tickHeartbeat is run by leaders to send a MsgBeat after r.heartbeatTimeout.
func (r *raft) tickHeartbeat() {
   r.heartbeatElapsed++
   r.electionElapsed++

  	//......
   if r.heartbeatElapsed >= r.heartbeatTimeout {
      r.heartbeatElapsed = 0
      r.Step(pb.Message{From: r.id, Type: pb.MsgBeat})
   }
}
```

在lead 节点接收到  MsgBeat 信息后，会向全局广播信息

```go
func stepLeader(r *raft, m pb.Message) error {
	// These message types do not require any progress for m.From.
	switch m.Type {
	case pb.MsgBeat:
		r.bcastHeartbeat()
		return nil
	......
}
```

flowwor 节点接到该消息后会重新设置  `electionElapsed` 和 `lead`,`candidate`节点接收到消息后会将节点改变为 `follower`

```go
func stepFollower(r *raft, m pb.Message) error {
	switch m.Type {
	....
	case pb.MsgHeartbeat:
		r.electionElapsed = 0
		r.lead = m.From
		r.handleHeartbeat(m)
 }
  
  // stepCandidate is shared by StateCandidate and StatePreCandidate; the difference is
// whether they respond to MsgVoteResp or MsgPreVoteResp.
func stepCandidate(r *raft, m pb.Message) error {
	switch m.Type {
	case pb.MsgHeartbeat:
		r.becomeFollower(m.Term, m.From) // always m.Term == r.Term
		r.handleHeartbeat(m)
  }
```



## MsgProp 


> 'MsgProp' proposes to append data to its log entries. This is a special type to redirect proposals to leader. Therefore, send method overwrites raftpb.Message's term with its HardState's term to avoid attaching its local term to 'MsgProp'. When 'MsgProp' is passed to the leader's 'Step' method, the leader first calls the 'appendEntry' method to append entries to its log, and then calls 'bcastAppend' method to send those entries to its peers. When passed to candidate, 'MsgProp' is dropped. When passed to follower, 'MsgProp' is stored in follower's mailbox(msgs) by the send method. It is stored with sender's ID and later forwarded to leader by rafthttp package.





| 成员    | 类型   | 作用                                                   |
| ------- | ------ | ------------------------------------------------------ |
| type    | MsgHup | 'MsgProp' 是用来将 proposes 数据添加到它的日志条目中。 |
| to      | uint64 | 消息接收者的节点ID                                     |
| from    | uint64 | 本节点ID                                               |
| entries | Entry  | entriesEntry日志条目数组                               |



###  follower 节点处理

```go
func stepFollower(r *raft, m pb.Message) error {
	switch m.Type {
	case pb.MsgProp:
    //该节点lead为空
    if r.lead == None {
			r.logger.Infof("%x no leader at term %d; dropping proposal", r.id, r.Term)
			return ErrProposalDropped
      // 处于没有收到节点和发起选举时的时间差
		} else if r.disableProposalForwarding {
			r.logger.Infof("%x not forwarding to leader %x at term %d; dropping proposal", r.id, r.lead, r.Term)
			return ErrProposalDropped
		}
    // 将消息转发给lead 
		m.To = r.lead
		r.send(m)
    .....
	case pb.MsgReadIndexResp:
	..... 
	return nil
}
```



### candidate 节点处理

由于candidate节点没有处理propose数据的责任，所以忽略这类型消息。

### lead 节点处理

```go
func stepLeader(r *raft, m pb.Message) error {
	// These message types do not require any progress for m.From.
	switch m.Type {
	case pb.MsgProp:
   		//查看 Entries 是否为空
		if len(m.Entries) == 0 {
			r.logger.Panicf("%x stepped empty MsgProp", r.id)
		}

		// 检查本节点是否还在集群之中，如果已经不在了则直接返回不进行下一步处理。
		//这种情况是出现本节点已经通过配置变化被移除出了集群的场景。
		if r.prs.Progress[r.id] == nil {
			// If we are not currently a member of the range (i.e. this node
			// was removed from the configuration while serving as leader),
			// drop any new proposals.
			return ErrProposalDropped
		}
		// lead 节点正则发生迁移
		if r.leadTransferee != None {
			r.logger.Debugf("%x [term %d] transfer leadership to %x is in progress; dropping proposal", r.id, r.Term, r.leadTransferee)
			return ErrProposalDropped
		}

		for i := range m.Entries {
			e := &m.Entries[i]
			var cc pb.ConfChangeI
			if e.Type == pb.EntryConfChange {
				var ccc pb.ConfChange
				if err := ccc.Unmarshal(e.Data); err != nil {
					panic(err)
				}
				cc = ccc
			} else if e.Type == pb.EntryConfChangeV2 {
				var ccc pb.ConfChangeV2
				if err := ccc.Unmarshal(e.Data); err != nil {
					panic(err)
				}
				cc = ccc
			}
			if cc != nil {
				// 配置正在更新之中
				alreadyPending := r.pendingConfIndex > r.raftLog.applied
				alreadyJoint := len(r.prs.Config.Voters[1]) > 0
				wantsLeaveJoint := len(cc.AsV2().Changes) == 0

				var refused string
				// 若为配置变更请求消息，先判断其 pendingConfIndex（它限制了一次只能进行一个节点的变更）
				// 并且保证其不能超过 appliedIndex，因为只有一个变更请求被 pending，因此其肯定还未提交，因此正常情况下必须小于 appliedIndex
				if alreadyPending {
					refused = fmt.Sprintf("possible unapplied conf change at index %d (applied to %d)", r.pendingConfIndex, r.raftLog.applied)
				} else if alreadyJoint && !wantsLeaveJoint {
					refused = "must transition out of joint config first"
				} else if !alreadyJoint && wantsLeaveJoint {
					refused = "not in joint state; refusing empty conf change"
				}

				if refused != "" {
					r.logger.Infof("%x ignoring conf change %v at config %s: %s", r.id, cc, r.prs.Config, refused)
					m.Entries[i] = pb.Entry{Type: pb.EntryNormal}
				} else {
					r.pendingConfIndex = r.raftLog.lastIndex() + uint64(i) + 1
				}
			}
		}

		//添加消息到日志
		if !r.appendEntry(m.Entries...) {
			return ErrProposalDropped
		}
		//发起广播实际
		r.bcastAppend()
		return nil
		......
		return nil
	}
  
  // sendAppend sends an append RPC with new entries (if any) and the
// current commit index to the given peer.
func (r *raft) sendAppend(to uint64) {
  //发送Apppend消息
	r.maybeSendAppend(to, true)
}
  
// maybeSendAppend sends an append RPC with new entries to the given peer,
// if necessary. Returns true if a message was sent. The sendIfEmpty
// argument controls whether messages with no entries will be sent
// ("empty" messages are useful to convey updated Commit indexes, but
// are undesirable when we're sending multiple messages in a batch).
func (r *raft) maybeSendAppend(to uint64, sendIfEmpty bool) bool {
	//获取目标节点追踪器 
	pr := r.prs.Progress[to]
	if pr.IsPaused() {
		return false
	}
	m := pb.Message{}
	m.To = to

  if{
	} else {
    //设置信息
		m.Type = pb.MsgApp
		m.Index = pr.Next - 1
		m.LogTerm = term
		m.Entries = ents
		m.Commit = r.raftLog.committed
		if n := len(m.Entries); n != 0 {
			switch pr.State {
			// optimistically increase the next when in StateReplicate
			case tracker.StateReplicate:
				last := m.Entries[n-1].Index
				pr.OptimisticUpdate(last)
				pr.Inflights.Add(last)
			case tracker.StateProbe:
				pr.ProbeSent = true
			default:
				r.logger.Panicf("%x is sending append in unhandled state %s", r.id, pr.State)
			}
		}
	}
	r.send(m)
	return true
}
```



## Process

```go
/ Progress represents a follower’s progress in the view of the leader. Leader
// maintains progresses of all followers, and sends entries to the follower
// based on its progress.
//
// NB(tbg): Progress is basically a state machine whose transitions are mostly
// strewn around `*raft.raft`. Additionally, some fields are only used when in a
// certain State. All of this isn't ideal.
type Progress struct {
	//保存下一次leader发送append消息给该follower时的日志索引。
	//保存该follower节点上的最大日志索引。
	//正常情况下 Next = Math + 1
	Match, Next uint64
	// State defines how the leader should interact with the follower.
	//
	// When in StateProbe, leader sends at most one replication message
	// per heartbeat interval. It also probes actual progress of the follower.
	//
	// When in StateReplicate, leader optimistically increases next
	// to the latest entry sent after sending replication message. This is
	// an optimized state for fast replicating log entries to the follower.
	//
	// When in StateSnapshot, leader should have sent out snapshot
	// before and stops sending any replication message.
	State StateType

	// PendingSnapshot is used in StateSnapshot.
	// If there is a pending snapshot, the pendingSnapshot will be set to the
	// index of the snapshot. If pendingSnapshot is set, the replication process of
	// this Progress will be paused. raft will not resend snapshot until the pending one
	// is reported to be failed.
	PendingSnapshot uint64

	// RecentActive is true if the progress is recently active. Receiving any messages
	// from the corresponding follower indicates the progress is active.
	// RecentActive can be reset to false after an election timeout.
	//
	// TODO(tbg): the leader should always have this set to true.
	RecentActive bool

	// ProbeSent is used while this follower is in StateProbe. When ProbeSent is
	// true, raft should pause sending replication message to this peer until
	// ProbeSent is reset. See ProbeAcked() and IsPaused().
	ProbeSent bool

	// Inflights is a sliding window for the inflight messages.
	// Each inflight message contains one or more log entries.
	// The max number of entries per message is defined in raft config as MaxSizePerMsg.
	// Thus inflight effectively limits both the number of inflight messages
	// and the bandwidth each Progress can use.
	// When inflights is Full, no more message should be sent.
	// When a leader sends out a message, the index of the last
	// entry should be added to inflights. The index MUST be added
	// into inflights in order.
	// When a leader receives a reply, the previous inflights should
	// be freed by calling inflights.FreeLE with the index of the last
	// received entry.
	Inflights *Inflights

	// IsLearner is true if this progress is tracked for a learner.
	IsLearner bool
}

```

progress 是leader维护的各个follower的状态信息， 总共有三种状态: `probe`, `replicate`, `snapshot`， 其内部的[状态机](https://github.com/etcd-io/etcd/blob/master/raft/design.md)如下转换

```
                            +--------------------------------------------------------+          
                            |                  send snapshot                         |          
                            |                                                        |          
                  +---------+----------+                                  +----------v---------+
              +--->       probe        |                                  |      snapshot      |
              |   |  max inflight = 1  <----------------------------------+  max inflight = 0  |
              |   +---------+----------+                                  +--------------------+
              |             |            1. snapshot success                                    
              |             |               (next=snapshot.index + 1)                           
              |             |            2. snapshot failure                                    
              |             |               (no change)                                         
              |             |            3. receives msgAppResp(rej=false&&index>lastsnap.index)
              |             |               (match=m.index,next=match+1)                        
receives msgAppResp(rej=true)                                                                   
(next=match+1)|             |                                                                   
              |             |                                                                   
              |             |                                                                   
              |             |   receives msgAppResp(rej=false&&index>match)                     
              |             |   (match=m.index,next=match+1)                                    
              |             |                                                                   
              |             |                                                                   
              |             |                                                                   
              |   +---------v----------+                                                        
              |   |     replicate      |                                                        
              +---+  max inflight = n  |                                                        
                  +--------------------+                                                       
```



### ProgressStateProbe

> When the progress of a follower is in `probe` state, leader sends at most one `replication message` per heartbeat interval. The leader sends `replication message` slowly and probing the actual progress of the follower. A `msgHeartbeatResp` or a `msgAppResp` with reject might trigger the sending of the next `replication message`

官方的文档描述了Progress 处于 Probe 的行为。那么什么情况下Progress 会进入 Probe 状态呢？

当节点拒绝了最近的Append 消息时，那么就会进入探测状态，此时leader会试图继续往前追述该节点的日志从哪里开始丢失的，让该节点的日志能跟leader同步上。在probe状态时，只能向它发送一次append消息，此后除非状态发生变化，否则就暂停向该节点发送新的append消息了。

只有在以下情况才会恢复取消暂停状态（调用Progress的resume函数）：

1. 收到该节点的心跳消息。
2. 该节点成功应答了前面的最后一条append消息。



至于Probe状态，只有在该节点成功应答了Append消息之后，在leader上保存的索引值发生了变化，才会修改其状态切换到Replicate状态。



### ProgressStateReplicate

> When the progress of a follower is in `replicate` state, leader sends `replication message`, then optimistically increases `next` to the latest entry sent. This is an optimized state for fast replicating log entries to the follower.

正常接收副本数据的状态，当处于该状态时，leader在发送副本消息之后，就修改该节点的next索引为发送消息的最大索引+1

### ProgressStateSnapshot

接收快照状态。 当leader向某个follower发送append消息，试图让该follower状态跟上leader时，发现此时leader上保存的索引数据已经对不上了，比如leader在index为10之前的数据都已经写入快照中了，但是该follower需要的是10之前的数据，此时就会切换到该状态下，发送快照给该follower。

因为快照数据可能很多，不知道会同步多久，所以单独把这个状态抽象出来。

当快照数据同步追上之后，并不是直接切换到Replicate状态，而是首先切换到Probe状态。











## MsgApp


> 'MsgApp' contains log entries to replicate. A leader calls bcastAppend, which calls sendAppend, which sends soon-to-be-replicated logs in 'MsgApp' type. When 'MsgApp' is passed to candidate's Step method, candidate reverts back to follower, because it indicates that there is a valid leader sending 'MsgApp' messages. Candidate and follower respond to this message in 'MsgAppResp' type.



| 成员    | 类型   | 作用                                     |
| ------- | ------ | ---------------------------------------- |
| type    | MsgApp | 用于leader向集群中其他节点同步数据的消息 |
| to      | uint64 | 消息接收者的节点ID                       |
| from    | uint64 | 本节点ID                                 |
| entries | Entry  | 日志条目数组                             |
| logTerm | uint64 | 日志所处的任期ID                         |
| index   | uint64 | 索引ID                                   |



当leader节点在本地处理完`MsgProp` 会通过 `raft.maybeSendAppend()` 来发送日志信息。

```go
// maybeSendAppend sends an append RPC with new entries to the given peer,
// if necessary. Returns true if a message was sent. The sendIfEmpty
// argument controls whether messages with no entries will be sent
// ("empty" messages are useful to convey updated Commit indexes, but
// are undesirable when we're sending multiple messages in a batch).
func (r *raft) maybeSendAppend(to uint64, sendIfEmpty bool) bool {
	//获取目标节点追踪器
	pr := r.prs.Progress[to]
	if pr.IsPaused() {
		return false
	}
	m := pb.Message{}
	m.To = to

	term, errt := r.raftLog.term(pr.Next - 1)
	ents, erre := r.raftLog.entries(pr.Next, r.maxMsgSize)
	if len(ents) == 0 && !sendIfEmpty {
		return false
	}

	if errt != nil || erre != nil { // send snapshot if we failed to get term or entries
		if !pr.RecentActive {
			r.logger.Debugf("ignore sending snapshot to %x since it is not recently active", to)
			return false
		}

		m.Type = pb.MsgSnap
		snapshot, err := r.raftLog.snapshot()
		if err != nil {
			if err == ErrSnapshotTemporarilyUnavailable {
				r.logger.Debugf("%x failed to send snapshot to %x because snapshot is temporarily unavailable", r.id, to)
				return false
			}
			panic(err) // TODO(bdarnell)
		}
		if IsEmptySnap(snapshot) {
			panic("need non-empty snapshot")
		}
		m.Snapshot = snapshot
		sindex, sterm := snapshot.Metadata.Index, snapshot.Metadata.Term
		r.logger.Debugf("%x [firstindex: %d, commit: %d] sent snapshot[index: %d, term: %d] to %x [%s]",
			r.id, r.raftLog.firstIndex(), r.raftLog.committed, sindex, sterm, to, pr)
		pr.BecomeSnapshot(sindex)
		r.logger.Debugf("%x paused sending replication messages to %x [%s]", r.id, to, pr)
	} else {
		m.Type = pb.MsgApp
		m.Index = pr.Next - 1
		m.LogTerm = term
		m.Entries = ents
		m.Commit = r.raftLog.committed
		if n := len(m.Entries); n != 0 {
			switch pr.State {
			// optimistically increase the next when in StateReplicate
			case tracker.StateReplicate:
				last := m.Entries[n-1].Index
				pr.OptimisticUpdate(last)
				pr.Inflights.Add(last)
			case tracker.StateProbe:
				pr.ProbeSent = true
			default:
				r.logger.Panicf("%x is sending append in unhandled state %s", r.id, pr.State)
			}
		}
	}
	r.send(m)
	return true
}
```





在`followr` 节点 和 `candidate` 节点接收到后会做一下处理

```go
r.becomeFollower(m.Term, m.From) // always m.Term == r.Term
r.handleAppendEntries(m)
```

 

其中 `handleAppendEntries` 用于同步从leader 来的 Entries 



```go
func (r *raft) handleAppendEntries(m pb.Message) {
  // m.Index < r.raftLog.committed,说明leader发过来的entries比较老。回复给leader自身当前的committed。告诉leader自身这边的日志已经提交到index。
	if m.Index < r.raftLog.committed {
		r.send(pb.Message{To: m.From, Type: pb.MsgAppResp, Index: r.raftLog.committed})
		return
	}

  //调用raftLog的maybeAppend，判断日志条目是否需要Append,如果没有冲突可以Append，raftLog也会相应的更新自己committed值。
	if mlastIndex, ok := r.raftLog.maybeAppend(m.Index, m.LogTerm, m.Commit, m.Entries...); ok {
		r.send(pb.Message{To: m.From, Type: pb.MsgAppResp, Index: mlastIndex})
	} else {
    //果Append失败，则证明不包含匹配LogTerm的Index所对应的条目，通常该情况为节点挂掉一段时间，落后leader节点。则发送reject的回复给leader，并告诉leader当前自身的lastIndex。leader会重新发包含较早的prevLogTerm及prevLogIndex的RPC给该节点。
		r.logger.Debugf("%x [logterm: %d, index: %d] rejected MsgApp [logterm: %d, index: %d] from %x",
			r.id, r.raftLog.zeroTermOnErrCompacted(r.raftLog.term(m.Index)), m.Index, m.LogTerm, m.Index, m.From)

		// Return a hint to the leader about the maximum index and term that the
		// two logs could be divergent at. Do this by searching through the
		// follower's log for the maximum (index, term) pair with a term <= the
		// MsgApp's LogTerm and an index <= the MsgApp's Index. This can help
		// skip all indexes in the follower's uncommitted tail with terms
		// greater than the MsgApp's LogTerm.
		//
		// See the other caller for findConflictByTerm (in stepLeader) for a much
		// more detailed explanation of this mechanism.
		hintIndex := min(m.Index, r.raftLog.lastIndex())
		hintIndex = r.raftLog.findConflictByTerm(hintIndex, m.LogTerm)
		hintTerm, err := r.raftLog.term(hintIndex)
		if err != nil {
			panic(fmt.Sprintf("term(%d) must be valid, but got %v", hintIndex, err))
		}
		r.send(pb.Message{
			To:         m.From,
			Type:       pb.MsgAppResp,
			Index:      m.Index,
			Reject:     true,
			RejectHint: hintIndex,
			LogTerm:    hintTerm,
		})
	}
}


// maybeAppend returns (0, false) if the entries cannot be appended. Otherwise,
// it returns (last index of new entries, true).
// index  leader 发送过来的
// logTerm leader 发送过来日志的term
// lead 发送过来的最后一个日志的cmmited
func (l *raftLog) maybeAppend(index, logTerm, committed uint64, ents ...pb.Entry) (lastnewi uint64, ok bool) {
	//如果leader发来的消息中的index和logTerm都是和自身匹配的。则证明可以append。
	if l.matchTerm(index, logTerm) {
		lastnewi = index + uint64(len(ents))
		//如果leader发来的Entries有和自身日志冲突的，找到冲突开始的点。如果冲突开始的点早于自身committed值，
		//则作panic处理（正常流程不会有该情况，已经commited的条目是不会修改的），否则更新自身日志条目。
		ci := l.findConflict(ents)
		switch {
		case ci == 0:
		case ci <= l.committed:
			l.logger.Panicf("entry %d conflict with committed entry [committed(%d)]", ci, l.committed)
		default:
			offset := index + 1
			l.append(ents[ci-offset:]...)
		}
		l.commitTo(min(committed, lastnewi))
		return lastnewi, true
	}
	return 0, false
}

// findConflict finds the index of the conflict.
// It returns the first pair of conflicting entries between the existing
// entries and the given entries, if there are any.
// If there is no conflicting entries, and the existing entries contains
// all the given entries, zero will be returned.
// If there is no conflicting entries, but the given entries contains new
// entries, the index of the first new entry will be returned.
// An entry is considered to be conflicting if it has the same index but
// a different term.
// The index of the given entries MUST be continuously increasing.
func (l *raftLog) findConflict(ents []pb.Entry) uint64 {
	// findConflict 的实现，对 ents 中的每个 entry 调用 matchTerm 方法，Index 升序遍历
	//，遇到 unmatch的 (即遇到相同 Index 不同 Term 的 entry 认为 conflict)，
	//如果这个 unmatch 的 entry 的 Index <= lastIndex，则有 conflict，
	//返回第一个 conflict entry 的 Index；如果这个 unmatch 的 entry 的 Index > lastIndex，
	//则认为是新的未包含的 entry，则返回第一个新的 entry 的 Index；如果均 match 则返回 0
	for _, ne := range ents {
		if !l.matchTerm(ne.Index, ne.Term) {
			if ne.Index <= l.lastIndex() {
				l.logger.Infof("found conflict at index %d [existing term: %d, conflicting term: %d]",
					ne.Index, l.zeroTermOnErrCompacted(l.term(ne.Index)), ne.Term)
			}
			return ne.Index
		}
	}
	return 0
}
```



##MsgSnap


> 'MsgSnap' requests to install a snapshot message. When a node has just become a leader or the leader receives 'MsgProp' message, it calls 'bcastAppend' method, which then calls 'sendAppend' method to each follower. In 'sendAppend', if a leader fails to get term or entries, the leader requests snapshot by sending 'MsgSnap' type message.
>
> 

| 成员     | 类型     | 作用                                     |
| -------- | -------- | ---------------------------------------- |
| type     | MsgSnap  | 用于leader向follower同步数据用的快照消息 |
| to       | uint64   | 消息接收者的节点ID                       |
| from     | uint64   | 本节点ID                                 |
| snapshot | Snapshot | 快照数据                                 |

MsgSnap消息做的事情其实跟前面提到的MsgApp消息是一样的：都是用于leader向follower同步数据。Raft算法中，任何的数据要提交成功，首先leader会在本地写一份日志，再广播出去给集群的其他节点，只有在超过半数以上的节点同意，leader才能进行提交操作。而本地日志不可能把全部的日志放到内存之中，必然有一部会做压缩的处理。但是如果前面的数据已经进行了压缩处理，转换成了快照数据，而压缩后的快照数据实际上已经没有日志索引相关的信息了。这时候只能将快照数据全部同步给节点了。还是以前面的流程为例，假如leader上日志索引为7之前的数据都已经被压缩成了快照数据，那么这部分数据在同步时是需要整份传输过去的



实际上对于leader而言，向某个节点同步数据这个操作，都封装在`raft.maybeSendAppend`函数中 这在上面我们已经分析过了，现在重点是要关注在follower里相关的操作 。

```go
func (r *raft) handleSnapshot(m pb.Message) {
	sindex, sterm := m.Snapshot.Metadata.Index, m.Snapshot.Metadata.Term
	if r.restore(m.Snapshot) {
		r.logger.Infof("%x [commit: %d] restored snapshot [index: %d, term: %d]",
			r.id, r.raftLog.committed, sindex, sterm)
		r.send(pb.Message{To: m.From, Type: pb.MsgAppResp, Index: r.raftLog.lastIndex()})
	} else {
		r.logger.Infof("%x [commit: %d] ignored snapshot [index: %d, term: %d]",
			r.id, r.raftLog.committed, sindex, sterm)
		r.send(pb.Message{To: m.From, Type: pb.MsgAppResp, Index: r.raftLog.committed})
	}
}
```







## MsgAppResp


>'MsgAppResp' is response to log replication request('MsgApp'). When 'MsgApp' is passed to candidate or follower's Step method, it responds by calling 'handleAppendEntries' method, which sends 'MsgAppResp' to raft mailbox.



| 成员       | 类型       | 作用                                                         |
| ---------- | ---------- | ------------------------------------------------------------ |
| type       | MsgAppResp | 集群中其他节点针对leader的MsgApp/MsgSnap消息的应答消息       |
| to         | uint64     | 消息接收者的节点ID                                           |
| from       | uint64     | 本节点ID                                                     |
| index      | uint64     | 日志索引ID，用于节点向leader汇报自己已经commit的日志数据ID   |
| reject     | bool       | 是否拒绝同步日志的请求                                       |
| rejectHint | uint64     | 拒绝同步日志请求时返回的当前节点日志ID，用于被拒绝方快速定位到下一次合适的同步日志位置 |





## MsgVote 
> 'MsgVote' requests votes for election. When a node is a follower or candidate and 'MsgHup' is passed to its Step method, then the node calls 'campaign' method to campaign itself to become a leader. Once 'campaign' method is called, the node becomes candidate and sends 'MsgVote' to peers in cluster to request votes. When passed to leader or candidate's Step method and the message's Term is lower than leader's or candidate's, 'MsgVote' will be rejected ('MsgVoteResp' is returned with Reject true). If leader or candidate receives 'MsgVote' with higher term, it will revert back to follower. When 'MsgVote' is passed to follower, it votes for the sender only when sender's last term is greater than MsgVote's term or sender's last term is equal to MsgVote's term but sender's last committed index is greater than or equal to follower's.



MsgVote 是节点在一定时间没有收到leader的心跳包之后就会发起选举的操作。




| 成员    | 类型               | 作用                                                       |
| ------- | ------------------ | ---------------------------------------------------------- |
| type    | MsgVote | 节点投票给自己以进行新一轮的选举                           |
| to      | uint64             | 消息接收者的节点ID                                         |
| from    | uint64             | 本节点ID                                                   |
| term    | uint64             | 任期ID                                                     |
| index   | uint64             | 日志索引ID，用于节点向leader汇报自己已经commit的日志数据ID |
| logTerm | uint64             | 日志所处的任期ID                                           |
| context | bytes              | 上下文数据                                                 |



```go
func (r *raft) Step(m pb.Message) error {
	.....
	switch m.Type {
   // 收到 MsgHub 消息发起选举
	case pb.MsgHup:
		if r.preVote {
      //配置了PreVate,两段式选举
			r.hup(campaignPreElection)
		} else {
      //未配置PreVate,正常发起选举
			r.hup(campaignElection)
		}

	return nil
}
  
unc (r *raft) hup(t CampaignType) {
	//已经是Leader 
	if r.state == StateLeader {
		r.logger.Debugf("%x ignoring MsgHup because already leader", r.id)
		return
	}

	//判断是否有资格发起选举
	if !r.promotable() {
		r.logger.Warningf("%x is unpromotable and can not campaign", r.id)
		return
	}
	ents, err := r.raftLog.slice(r.raftLog.applied+1, r.raftLog.committed+1, noLimit)
	if err != nil {
		r.logger.Panicf("unexpected error getting unapplied entries (%v)", err)
	}
	//日志还有处于pending的状态 &&  集群经被应用的最大索引 > 该节点已经被应用的最大索引。
	if n := numOfPendingConf(ents); n != 0 && r.raftLog.committed > r.raftLog.applied {
		r.logger.Warningf("%x cannot campaign at term %d since there are still %d pending configuration changes to apply", r.id, r.Term, n)
		return
	}

	r.logger.Infof("%x is starting a new election at term %d", r.id, r.Term)
	r.campaign(t)
}
  
// campaign transitions the raft instance to candidate state. This must only be
// called after verifying that this is a legitimate transition.
func (r *raft) campaign(t CampaignType) {
	if !r.promotable() {
		// This path should not be hit (callers are supposed to check), but
		// better safe than sorry.
		r.logger.Warningf("%x is unpromotable; campaign() should have been called", r.id)
	}
	var term uint64
	var voteMsg pb.MessageType
	if t == campaignPreElection {
		//转换成Pre Candidate 状态
		r.becomePreCandidate()
		voteMsg = pb.MsgPreVote
		// PreVote RPCs are sent for the next term before we've incremented r.Term.
		// 为什么这里是 term = r.Term + 1 呢？
		// 因为要确定新leader,会将该节点的 (term +1),这个操作会在 becomeCandidate 里操作，没有在 becomePreCandidate 操作
		term = r.Term + 1
	} else {
		//变成Candidtae

		r.becomeCandidate()
		voteMsg = pb.MsgVote
		term = r.Term
	}
	//判断选举是否成功
	if _, _, res := r.poll(r.id, voteRespMsgType(voteMsg), true); res == quorum.VoteWon {
		// We won the election after voting for ourselves (which must mean that
		// this is a single-node cluster). Advance to the next state.
		if t == campaignPreElection {
			r.campaign(campaignElection)
		} else {
			r.becomeLeader()
		}
		return
	}
	var ids []uint64
	{
		idMap := r.prs.Voters.IDs()
		ids = make([]uint64, 0, len(idMap))
		for id := range idMap {
			ids = append(ids, id)
		}
		sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	}
	for _, id := range ids {
		if id == r.id {
			continue
		}
		r.logger.Infof("%x [logterm: %d, index: %d] sent %s request to %x at term %d",
			r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), voteMsg, id, r.Term)

		var ctx []byte
		if t == campaignTransfer {
			ctx = []byte(t)
		}
		//发送要选举的信息
		r.send(pb.Message{Term: term, To: id, Type: voteMsg, Index: r.raftLog.lastIndex(), LogTerm: r.raftLog.lastTerm(), Context: ctx})
	}
}
```

其他节点在收到MsgVate 操作

```go
func (r *raft) Step(m pb.Message) error {
	// Handle the message term, which may result in our stepping down to a follower.
	switch {
	case m.Term == 0:
		// local message
		// Messge 的任期大于本地节点的任期
	case m.Term > r.Term:
		// 如果收到的是投票类消息
		if m.Type == pb.MsgVote || m.Type == pb.MsgPreVote {
			//当context为campaignTransfer时表示强制要求进行竞选
			force := bytes.Equal(m.Context, []byte(campaignTransfer))
			//是否在electionTimeout之内
			inLease := r.checkQuorum && r.lead != None && r.electionElapsed < r.electionTimeout
			if !force && inLease {
				// If a server receives a RequestVote request within the minimum election timeout
				// of hearing from a current leader, it does not update its term or grant its vote
				r.logger.Infof("%x [logterm: %d, index: %d, vote: %x] ignored %s from %x [logterm: %d, index: %d] at term %d: lease is not expired (remaining ticks: %d)",
					r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), r.Vote, m.Type, m.From, m.LogTerm, m.Index, r.Term, r.electionTimeout-r.electionElapsed)
				return nil
			}
		}
		switch {
		case m.Type == pb.MsgPreVote:
			// Never change our term in response to a PreVote
		case m.Type == pb.MsgPreVoteResp && !m.Reject:
			// We send pre-vote requests with a term in our future. If the
			// pre-vote is granted, we will increment our term when we get a
			// quorum. If it is not, the term comes from the node that
			// rejected our vote so we should become a follower at the new
			// term.
		default:
			r.logger.Infof("%x [term: %d] received a %s message with higher term from %x [term: %d]",
				r.id, r.Term, m.Type, m.From, m.Term)
			if m.Type == pb.MsgApp || m.Type == pb.MsgHeartbeat || m.Type == pb.MsgSnap {
				r.becomeFollower(m.Term, m.From)
			} else {
				r.becomeFollower(m.Term, None)
			}
		}

	case m.Term < r.Term:
		 ......
		return nil
	}
	switch m.Type {
    //....
	case pb.MsgVote, pb.MsgPreVote:
    //投票的前置条件
		// We can vote if this is a repeat of a vote we've already cast...
		canVote := r.Vote == m.From ||
			// ...we haven't voted and we don't think there's a leader yet in this term...
			(r.Vote == None && r.lead == None) ||
			// ...or this is a PreVote for a future term...
			(m.Type == pb.MsgPreVote && m.Term > r.Term)
		// ...and we believe the candidate is up to date.
		if canVote && r.raftLog.isUpToDate(m.Index, m.LogTerm) {
			// Note: it turns out that that learners must be allowed to cast votes.
			// This seems counter- intuitive but is necessary in the situation in which
			// a learner has been promoted (i.e. is now a voter) but has not learned
			// about this yet.
			// For example, consider a group in which id=1 is a learner and id=2 and
			// id=3 are voters. A configuration change promoting 1 can be committed on
			// the quorum `{2,3}` without the config change being appended to the
			// learner's log. If the leader (say 2) fails, there are de facto two
			// voters remaining. Only 3 can win an election (due to its log containing
			// all committed entries), but to do so it will need 1 to vote. But 1
			// considers itself a learner and will continue to do so until 3 has
			// stepped up as leader, replicates the conf change to 1, and 1 applies it.
			// Ultimately, by receiving a request to vote, the learner realizes that
			// the candidate believes it to be a voter, and that it should act
			// accordingly. The candidate's config may be stale, too; but in that case
			// it won't win the election, at least in the absence of the bug discussed
			// in:
			// https://github.com/etcd-io/etcd/issues/7625#issuecomment-488798263.
			r.logger.Infof("%x [logterm: %d, index: %d, vote: %x] cast %s for %x [logterm: %d, index: %d] at term %d",
				r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), r.Vote, m.Type, m.From, m.LogTerm, m.Index, r.Term)
			// When responding to Msg{Pre,}Vote messages we include the term
			// from the message, not the local term. To see why, consider the
			// case where a single node was previously partitioned away and
			// it's local term is now out of date. If we include the local term
			// (recall that for pre-votes we don't update the local term), the
			// (pre-)campaigning node on the other end will proceed to ignore
			// the message (it ignores all out of date messages).
			// The term in the original message and current local term are the
			// same in the case of regular votes, but different for pre-votes.
			r.send(pb.Message{To: m.From, Term: m.Term, Type: voteRespMsgType(m.Type)})
			if m.Type == pb.MsgVote {
				// Only record real votes.
				r.electionElapsed = 0
				r.Vote = m.From
			}
		} else {
			r.logger.Infof("%x [logterm: %d, index: %d, vote: %x] rejected %s from %x [logterm: %d, index: %d] at term %d",
				r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), r.Vote, m.Type, m.From, m.LogTerm, m.Index, r.Term)
			r.send(pb.Message{To: m.From, Term: r.Term, Type: voteRespMsgType(m.Type), Reject: true})
		}

	default:
		err := r.step(r, m)
		if err != nil {
			return err
		}
	}  


	
	return nil
}

```

上面这个处理里面最关键的函数就是 `isUpToDate`

```go
// isUpToDate determines if the given (lastIndex,term) log is more up-to-date
// by comparing the index and term of the last entries in the existing logs.
// If the logs have last entries with different terms, then the log with the
// later term is more up-to-date. If the logs end with the same term, then
// whichever log has the larger lastIndex is more up-to-date. If the logs are
// the same, the given log is up-to-date.
func (l *raftLog) isUpToDate(lasti, term uint64) bool {
	return term > l.lastTerm() || (term == l.lastTerm() && lasti >= l.lastIndex())
}
```

`candidate` 的日志必须是最新，才能有被选举的资格，这个逻辑可以查看 `Raft` 论文。 

 





## MsgVoteResp 

>'MsgVoteResp' contains responses from voting request. When 'MsgVoteResp' is passed to candidate, the candidate calculates how many votes it has won. If it's more than majority (quorum), it becomes leader and calls 'bcastAppend'. If candidate receives majority of votes of denials, it reverts back to follower.


| 成员   | 类型        | 作用               |
| ------ | ----------- | ------------------ |
| type   | MsgVoteResp | 投票应答消息       |
| to     | uint64      | 消息接收者的节点ID |
| from   | uint64      | 本节点ID           |
| reject | bool        | 是否拒绝           |

candidate 节点收到 MsgVoteResp 之后就对投票的结果进行处理 
```
// stepCandidate is shared by StateCandidate and StatePreCandidate; the difference is
// whether they respond to MsgVoteResp or MsgPreVoteResp.
func stepCandidate(r *raft, m pb.Message) error {
	// Only handle vote responses corresponding to our candidacy (while in
	// StateCandidate, we may get stale MsgPreVoteResp messages in this term from
	// our pre-candidate state).
	var myVoteRespType pb.MessageType
	if r.state == StatePreCandidate {
		myVoteRespType = pb.MsgPreVoteResp
	} else {
		myVoteRespType = pb.MsgVoteResp
	}
	switch m.Type {
	case pb.MsgProp:
		r.logger.Infof("%x no leader at term %d; dropping proposal", r.id, r.Term)
		return ErrProposalDropped
	case pb.MsgApp:
		r.becomeFollower(m.Term, m.From) // always m.Term == r.Term
		r.handleAppendEntries(m)
	case pb.MsgHeartbeat:
		r.becomeFollower(m.Term, m.From) // always m.Term == r.Term
		r.handleHeartbeat(m)
	case pb.MsgSnap:
		r.becomeFollower(m.Term, m.From) // always m.Term == r.Term
		r.handleSnapshot(m)
	case myVoteRespType:
		gr, rj, res := r.poll(m.From, m.Type, !m.Reject)
		r.logger.Infof("%x has received %d %s votes and %d vote rejections", r.id, gr, m.Type, rj)
		switch res {
		case quorum.VoteWon:
			if r.state == StatePreCandidate {
				r.campaign(campaignElection)
			} else {
				r.becomeLeader()
				r.bcastAppend()
			}
		case quorum.VoteLost:
			// pb.MsgPreVoteResp contains future term of pre-candidate
			// m.Term > r.Term; reuse r.Term
			r.becomeFollower(r.Term, None)
		}
	case pb.MsgTimeoutNow:
		r.logger.Debugf("%x [term %d state %v] ignored MsgTimeoutNow from %x", r.id, r.Term, r.state, m.From)
	}
	return nil
}

```





# 参考 

线性一致性和 Raft https://pingcap.com/blog-cn/linearizability-and-raft/

Etcd Raft架构设计和源码剖析1：宏观架构 https://lessisbetter.site/2019/08/19/etcd-raft-sources-arch/

Raft在etcd中的实现（四）日志复制与执行 https://yuan1028.github.io/etcd-raft-4/

