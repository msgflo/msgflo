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

**In Production**

* Used in production at [TheGrid](https://thegrid.io) website builder, with **AMQP**/RabbitMQ. 20 roles, 1'000'000 jobs/weekly+
* Used in production in [imgflo image processing server](https://github.com/jonnor/imgflo-server). 4 roles, 200'000 jobs/weekly+
* Used for IoT networks at hackerspaces [c-base](https://github.com/c-base/c-flo)
and [Bitraf](https://github.com/bitraf/bitraf-iot), using **MQTT**/Mosquitto.

Client support

* [msgflo-nodejs](./src/participant.coffee) makes it easy to make [Node.js](http://nodejs.org/) participants in **JavaScript**/**CoffeeScript**
* [noflo-runtime-msgflo](https://github.com/noflo/noflo-runtime-msgflo)
makes it super easy to use [NoFlo](http://noflojs.org) in the participants
* Basic support for **C++** participants with [msgflo-cpp](https://github.com/msgflo/msgflo-cpp) and [MicroFlo](https://github.com/microflo/microflo)
* Basic support for **Python** participants with [msgflo-python](https://github.com/msgflo/msgflo-python)
* Experimental support for **Rust** participants with [msgflo-rust](https://github.com/msgflo/msgflo-rust)

Tooling

* `msgflo` executable implements the [FBP runtime protocol](https://flowbased.github.io/fbp-protocol).
* Initial support for automated testing using [fbp-spec](https://github.com/flowbased/fbp-spec)
* Experimental support for visually building networks using [Flowhub](https://flowhub.io/)
* [guv](http://github.com/the-grid/guv) provides autoscaling of workers when using Heroku/AMQP.

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

Install MsgFlo and some participant libraries

    npm install msgflo msgflo-nodejs
    npm install noflo-runtime-msgflo noflo-core
    export PATH=./node_modules/.bin:$PATH

Setup a Node.js participant using [msgflo-nodejs](https://github.com/msgflo/msgflo-nodejs) (CoffeeScript)

    msgflo-nodejs --name repeater ./node_modules/msgflo-nodejs/examples/Repeat.coffee

Setup a NoFlo participant using [noflo-runtime-msgflo](https://github.com/noflo/noflo-runtime-msgflo)

    noflo-runtime-msgflo --name out --graph core/Output --broker amqp://localhost

Define how the participants form a network (in [.FBP DSL](https://github.com/flowbased/fbp#language-for-flow-based-programming))

    # FILE: myservice.fbp
    repeater(Repeat) OUT -> IN out(Output)

Setup the network

    msgflo-setup ./myservice.fbp --broker amqp://localhost

Send some data to input

    msgflo-send-message --queue repeater.IN --json '{ "foo": "bar" }'
    # Should now see output from 'out' participant
    # after having traveled through NoFlo and node.js participants

TODO: also show Python example
TODO: also show C++ examples


## Using non-MsgFlo-aware code as participants

MsgFlo can work with existing code that uses a supported message-queues system (AMQP, MQTT).
Because the code is not MsgFlo-aware, another process needs to send the MsgFlo discovery
message on its behalf.

For instance if we had a system that takes data on a queue named `process/A/in`,
transforms it and then sends the results on queue `process/A/out`,
the information can be declared in a [YAML](https://en.wikipedia.org/wiki/YAML) file:

```yaml
 # File: participants/ProcessSomething.yaml
component: ProcessSomething
label: Process input and send some output
icon: ambulance
inports:
  in:
    queue: process/A/in
    type: string
outports:
  out:
    queue: process/A/out
    type: string
```

And then run `msgflo-register-foreign` to publish the information

    msgflo-register-foreign participants/ProcessSomething.yaml

The `queue` key supports substituting `#ROLE`. This allows a single YAML file to declare a component
which can be instantiated multiple times - each with a different role and queue name.


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

If the participant is itself implemented using FBP and supports the
[FBP runtime protocol](https://flowbased.github.io/fbp-protocol/), these additional keys should be defined.

* `type`: type of the runtime, for example `noflo-nodejs` or `microflo`
* `version`: version of the runtime protocol that the runtime supports, for example `0.4`
* `inqueue`:  name of the message queue the participant listens for FBP protocol messages
* `outqueue`:  name of the message queue the participant sends FBP protocol messages

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

