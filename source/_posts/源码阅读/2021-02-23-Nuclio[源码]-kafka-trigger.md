---
title: 'Nuclio[源码]-kafka-trigger流程'
categories:
  - 源码阅读
tags:
  - Source Code
  - Nuclio
  - 待完善
date: '2021-02-23 10:19:09'
top: false
comments: true
---

# 重要

1. 入口函数 `nuclio: pkg/processor/trigger/kafka/trigger.go`   `k.consumerGroup.Consume`函数
```go
func (k *kafka) Start(checkpoint functionconfig.Checkpoint) error {
	var err error

	k.consumerGroup, err = k.newConsumerGroup()
	if err != nil {
		return errors.Wrap(err, "Failed to create consumer")
	}

	k.shutdownSignal = make(chan struct{}, 1)

	// start consumption in the background
	go func() {
		for {
			k.Logger.DebugWith("Starting to consume from broker", "topics", k.configuration.Topics)

			// start consuming. this will exit without error if a rebalancing occurs
			err = k.consumerGroup.Consume(context.Background(), k.configuration.Topics, k)

			if err != nil {
				k.Logger.WarnWith("Failed to consume from group, waiting before retrying", "err", errors.GetErrorStackString(err, 10))

				time.Sleep(1 * time.Second)
			} else {
				k.Logger.DebugWith("Consumer session closed (possibly due to a rebalance), re-creating")
			}
		}
	}()

	return nil
}
```



2. sarama consume 函数`sarama:consumer_group.go`    `c.newSession`函数

```go
// Consume implements ConsumerGroup.
func (c *consumerGroup) Consume(ctx context.Context, topics []string, handler ConsumerGroupHandler) error {
	// Ensure group is not closed
	select {
	case <-c.closed:
		return ErrClosedConsumerGroup
	default:
	}

	c.lock.Lock()
	defer c.lock.Unlock()

	// Quick exit when no topics are provided
	if len(topics) == 0 {
		return fmt.Errorf("no topics provided")
	}

	// Refresh metadata for requested topics
	if err := c.client.RefreshMetadata(topics...); err != nil {
		return err
	}

	// Init session
	sess, err := c.newSession(ctx, topics, handler, c.config.Consumer.Group.Rebalance.Retry.Max)
	if err == ErrClosedClient {
		return ErrClosedConsumerGroup
	} else if err != nil {
		return err
	}

	// loop check topic partition numbers changed
	// will trigger rebalance when any topic partitions number had changed
	go c.loopCheckPartitionNumbers(topics, sess)

	// Wait for session exit signal
	<-sess.ctx.Done()

	// Gracefully release session claims
	return sess.release(true)
}
```



3. 



# 安装

# 使用

# Reference