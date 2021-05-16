# 4.1 

## Congestion is unvoidable（不可避免）

1. We use packet switching because it make efficient use of the links. Therefore,buffers in the routers are frequently occupied
2. If buffers are always empty,delay is low,but our usage of the network is low 
3. if buffers are always occupied,dely is high,but we are using network more efficiently 



- Congestion is inevitable(不可避免的),and arguably（可以说是是） desirable（adj 可取的，值得拥有的）

- Congestion happens at different time scales-from two individual(独立的) packets colliding（冲突）,to some flows sending too quickly,to flash crowds appearing in the network 

- If packets are dropped,then retrainsmissions can make congestion even worse . 
- When packets are dropped,they waste resource upstream before the were dropped
- We need a definition of fairness,to deside how we want flows to share a bottleneck link 



Max-min fairness 

An allocation is max-min fair if you can not increase the rate of one flow without decreasing the rate of another flow with a lower rate . (最大最小化公平分配算法，也就是尽量满足用户中的最小的需求，然后将剩余的资源公平分配给剩下的)







