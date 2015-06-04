MsgFlo - Flow-Based Programming with Message Queues [![Build Status](https://travis-ci.org/msgflo/msgflo.svg?branch=master)](https://travis-ci.org/msgflo/msgflo)
===================================================

This is an implementation of the
[Flow-Based Programming](http://en.wikipedia.org/wiki/Flow-based_programming) paradigm using message queues
as the communications layer between different processes. Initial message queue transports targeted are
[AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)
and [MQTT](http://mqtt.org).

MsgFlo lets you build robust polyglot FBP systems spanning multiple nodes.
Each node can be implemented in different languages, and be a FBP runtime internally or not.

## Status

**Production**

* Used at [TheGrid](https://thegrid.io) for all workers using AMQP/RabbitMQ,
including in [imgflo-server](https://github.com/jonnor/imgflo-server)
* [msgflo-nodejs](./src/participant.coffee) makes it easy to set up [Node.js](http://nodejs.org/) participants
* [noflo-runtime-msgflo](https://github.com/noflo/noflo-runtime-msgflo)
makes it super easy to use NoFlo in the participants
* Basic support for C++ participants with [msgflo-cpp](https://github.com/msgflo/msgflo-cpp)
* Basic support for Python participants with [msgflo-python](https://github.com/msgflo/msgflo-python)
* Experimental support for MQTT and direct* transports.
* Coordinator implements basic [FBP runtime protocol](http://noflojs.org/documentation/protocol/). Can enumerate partipants and connect edges using Flowhub

## Licence

MIT, see [./LICENSE](./LICENSE)

## Usecases

There are two primary usecases targetted by `msgflo`.
Usecases with similar setups are also in-scope.

### Horizontally scalable web services

aka "Cloud".

!["Example web service system using msgflo"](./doc/msgflo-system-example-cloud.png)

A web service built using several groups of workers,
each performing a set of tasks, and communicating with eachother using a messaging queue service.
Some of the participants may provide HTTP REST interfaces or persistance to SQL/noSQL database,
others just perform computation.
Typical execution environments include Heroku, Amazon EC2, OpenStack, OpenShift.
Typical messaging system used are AMQP, ZeroMQ, Amazon Simple Queue Service, Google Cloud Pubsub.

### Embedded device networks

aka "Internet of Things".

A bigger embedded system is built using several embedded devices,
each performing a set of tasks, and communicating with eachother using
a messing queue service (typically running on an IoT gateway).
Some devices act as sensors, some as actuators and some provide computation.

Typical execution environments include Embedded Linux, microcontrollers.
Typical messaging systems used are MQTT.


## Usage

Setup a NoFlo participant using noflo-runtime-msgflo

    noflo-runtime-msgflo --name readenv --graph core/ReadEnv --broker amqp://localhost

Setup a Node.js participant using msgflo.Participant (CoffeeScript)

    msgflo = require 'msgflo'

    RepeatParticipant = (client, role) ->
      definition =
        component: 'Repeat'
        icon: 'file-word-o'
        label: 'Repeats in data without changes'
        inports: [
          id: 'in'
          type: 'any'
        ]
        outports: [
          id: 'out'
          type: 'any'
        ]
      process = (inport, indata, callback) ->
        return callback 'out', null, indata
      return new msgflo.participant.Participant client, definition, process, role

    client =  msgflo.transport.getClient 'amqp://localhost'
    worker = new RepeatParticipant client, 'repeater'
    worker.start (err) ->
      throw err if err
      console.log 'Worker started'

Define how the participants form a network (.FBP DSL)

    # FILE: myservice.fbp
    readenv(core/ReadEnv) OUT -> IN repeater(Repeat)

Setup the network

    msgflo-setup --graph ./myservice.fbp --broker amqp://localhost


...

    # TODO: show how to send/receive data for testing the setup
    # TODO


## Debugging

The msgflo executable, as well as the transport/participant library
uses the [debug NPM module](https://www.npmjs.com/package/debug).
You can enable (all) logging using:

    export DEBUG=msgflo*


## Architecture

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

## Communications

All communications between the coordinator and the participants happens using the message queue.
The network coordinator and the participants have channels to communicate,
and when different processes provided by participants are connected with each other,
these also pass through a queue.


### Message format

Each message sent between Participants and Coordinator has the following format:

* `protocol`: Which sub-protocol is used
* `command`: The command this message is on the given sub-protocol
* `payload`: The message payload

### Participant discovery

The network coordinator subscribes to a queue named `fbp`.

Once a participant becomes available, it announces its availability by sending a message to this queue
with `protocol`: 'discovery' and `command`: 'participant'.

In case of fully FBP protocol capable participants, the `payload` contains the following information:

* `id`: short unique name for the system
* `label`: (optional) human-readable description of the system
* `type`: type of the runtime, for example `noflo-nodejs` or `microflo`
* `version`: version of the runtime protocol that the runtime supports, for example `0.4`
* `capabilities`: array of capability strings for things the runtime is able to do
* `inqueue`:  name of the message queue the participant listens for FBP protocol messages
* `outqueue`:  name of the message queue the participant sends FBP protocol messages

In case of systems incapable of communicating via FBP protocol
but which can nonetheless be connected to a network,
the message `payload` contains the following information:


* `id`: short unique name for the participant. Ex: measure1
* `role`: the role this participant has in the network. Used to group multiple partipants. Ex: measure
* `component`: the component name of the participant. One component may be used in several roles. For instance MeasurementWorker
* `label`: (optional) human-readable description of the system
* `icon`: (optional) icon to use to describe the system, using [Font Awesome](http://fontawesome.io/icons/) semantics
* `inports`: list of inports containing:
  - `id`: port name
  - `queue`: the message queue the process listens to
  - `type`: port datatype, for example `boolean`
  - `options`: queue options as specified by the message queue implementation
* `outports`: list of outports containing:
  - `id`: port name
  - `queue`: the message queue the process transmits to
  - `type`: port datatype, for example `boolean`
  - `options`: queue options as specified by the message queue implementation

#### Participant changes

When changes are made in the participant,
the `participant` message should be resent with the updated data.

#### Heartbeat

The `participant` message should be re-sent periodically.
If no message is received within seconds,
the participant will be assumed to have stopped.
The default limit is 600 seconds.

Note: if sending data on ports on a sporadic connection,
one should first send a `participant` message for the data.

### Coordinator-Participant communications

Most of the communications between the coordinator and the participants happens
via the regular [FBP protocol](http://noflojs.org/documentation/protocol/).
Here are listed some additional messages that are used for the MsgFlo environment.

#### Connecting ports to queues

The coordinator can tell a participant to connect an inport of a running graph
to a message queue with the `connectinport` message with the following payload:

* `src`: source
  - `queue`: message queue name
  - `options`: queue options as specified by the message queue implementation
* `tgt`: target
  - `port`: port name
  - `index`: connection index (optional, for addressable ports)
* `metadata` (optional): structure of key-value pairs for edge metadata
* `graph`: graph the action targets

The coordinator can also tell a participant to connect an outport of a running graph
to a message queue with the `connectoutport` message with the following payload:

* `src`:  source
  - `port`: port name
  - `index`: connection index (optional, for addressable ports)
* `tgt`:
  - `queue`: message queue name
  - `options`: queue options as specified by the message queue implementation
* `metadata` (optional): structure of key-value pairs for edge metadata
* `graph`: graph the action targets
