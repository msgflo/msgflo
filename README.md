MsgFlo - Flow-Based Programming with Message Queues
===================================================

This is an implementation of the [Flow-Based Programming](http://en.wikipedia.org/wiki/Flow-based_programming) paradigm using message queues (initially, [AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)) as the communications layer between different processes. It is intended for building robust polyglot FBP systems.

Currently MsgFlo should be considered to be just an experiment.

## Architecture

### Message queue

Handles message passing between the network coordinator and the different network participants. Usually a standards-based message queue implementation like [RabbitMQ](https://www.rabbitmq.com/).

### Network coordinator

The MsgFlo network coordinator is responsible for keeping track of network participants, and assigning communications channels (message queues) between the different participants. It also serves as a [FBP protocol](http://noflojs.org/documentation/protocol/) endpoint for clients like [Flowhub](https://flowhub.io/) and proxying the protocol to the clients as needed.

### Network participant

A software process that makes itself available to the network. In FBP terms it may provide a single or multiple FBP network processes based on what things it is actually running.

## Communications

All communications between the coordinator and the participants happens using the message queue. The network coordinator and the participants have channels to communicate, and when different processes provided by participants are connected with each other, these also pass through a queue.

### Participant discovery

The network coordinator subscribes to a queue named `fbp`. Once a participant becomes available, it announces its availability by sending a message to this queue.

In case of fully FBP protocol capable participants, the message contains the following information:

* `id`: short unique name for the system
* `label`: (optional) human-readable description of the system
* `type`: type of the runtime, for example `noflo-nodejs` or `microflo`
* `version`: version of the runtime protocol that the runtime supports, for example `0.4`
* `capabilities`: array of capability strings for things the runtime is able to do
* `inqueue`:  name of the message queue the participant listens for FBP protocol messages
* `outqueue`:  name of the message queue the participant sends FBP protocol messages

In case of systems incapable of communicating via FBP protocol but which can nonetheless be connected to a network, the message contains the following information:

* `id`: short unique name for the system
* `label`: (optional) human-readable description of the system
* `icon`: (optional) icon to use to describe the system, using [Font Awesome](http://fontawesome.io/icons/) semantics
* `inports`: list of inports containing:
  - `id`: port name
  - `queue`: the message queue the process listens to
  - `type`: port datatype, for example `boolean`
* `outports`: list of outports containing:
  - `id`: port name
  - `queue`: the message queue the process transmits to
  - `type`: port datatype, for example `boolean`

### Coordinator-Participant communications

#### Heartbeat

Since communications via a message queue are by nature asynchronous, it is often necessary for the coordinator to know when participants are or are not available. For this, coordinator may periodically send a `ping` message to the worker. The ping message contains:

* `sequence`: sequence number for the ping

The participant should as quickly as possible respond with a `pong` message containing the same payload.

If the participant doesn't respond with a `pong` within a reasonable time, the coordinator should assume it to be inactive, and trigger a `processerror` on the processes that the participant is responsible of.
