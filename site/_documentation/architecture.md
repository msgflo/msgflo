---
title: Architecture
score: 7
---
### Message queue

Handles message passing between the network coordinator and the different network participants.
Usually a standards-based message queue implementation like [RabbitMQ](https://www.rabbitmq.com/).

### Network coordinator

The MsgFlo network coordinator is a software process responsible
for keeping track of network participants, and assigning communications channels (message queues)
between the different participants.

It also serves as a [FBP protocol](http://noflojs.org/documentation/protocol/) endpoint
for clients like [Flowhub](https://flowhub.io/) and proxying the protocol to the clients as needed.

### Network participant

MsgFlo Network Participant is a software process that makes itself available to the network.
In FBP terms it may provide a single or multiple FBP network processes based on what things it is actually running.
Participants are typically FBP runtimes instances.

