---
title: Distributed Flow-Based Programming via Message Queues
layout: frontpage
---
MsgFlo is an implementation of the [Flow-Based Programming](http://en.wikipedia.org/wiki/Flow-based_programming)
using message queues as the communications layer between different processes.
Currently supported message queue transports are
[AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)
and [MQTT](http://mqtt.org).

With MsgFlo you can build robust polyglot FBP systems spanning multiple computers/devices.
A node can be implemented in any language, to reuse existing code, libraries and developer know-how.

In FBP each component is a black-box that processes and produces data,
without knowledge about where the input data comes from, or where the output data goes.
This ensures that a service is easy to change, and facilitates automated testing.

MsgFlo is designed to enable partial and gradual integration into existing systems;
by using standard broker/transports, not placing restrictions on message payloads,
allowing to use existing queue names, and integrating non-MsgFlo nodes seamlessly.
