MsgFlo - Flow-Based Programming with Message Queues [![Build Status](https://travis-ci.org/msgflo/msgflo.svg?branch=master)](https://travis-ci.org/msgflo/msgflo)
===================================================

Implementation of the [Flow-Based Programming](http://en.wikipedia.org/wiki/Flow-based_programming)
using message queues as the communications layer between different processes.
Initial message queue transports targeted are
[AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)
and [MQTT](http://mqtt.org).

MsgFlo lets you build robust polyglot FBP systems spanning multiple computers/devices.
A node can be implemented in any language, to reuse existing code, libraries and developer know-how.

In FBP each component is a black-box that processes and produces data,
without knowledge about where the input data comes from, or where the output data goes.
This ensures that a service is easy to change, and facilitates automated testing.

MsgFlo is designed to enable partial and gradual integration into existing systems;
by using standard broker/transports, not placing restrictions on message payloads,
allowing to use existing queue names, and integrating non-MsgFlo nodes seamlessly.

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
* Experimental support for **Arduino** participants with [msgflo-arduino](https://github.com/msgflo/msgflo-arduino)
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
    export MSGFLO_BROKER=amqp://localhost # which broker to use. Can also be mqtt://

Setup a Node.js participant using [msgflo-nodejs](https://github.com/msgflo/msgflo-nodejs) (CoffeeScript)

    msgflo-nodejs --name repeater ./node_modules/msgflo-nodejs/examples/Repeat.coffee

Setup a NoFlo participant using [noflo-runtime-msgflo](https://github.com/noflo/noflo-runtime-msgflo)

    noflo-runtime-msgflo --name out --graph core/Output

Define how the participants form a network (in [.FBP DSL](https://github.com/flowbased/fbp#language-for-flow-based-programming))

    # FILE: myservice.fbp
    repeater(Repeat) OUT -> IN out(Output)

Setup the network

    msgflo-setup ./myservice.fbp

Send some data to input

    msgflo-send-message --queue repeater.IN --json '{ "foo": "bar" }'
    # Should now see output from 'out' participant
    # after having traveled through NoFlo and node.js participants

`TODO: also show Python example`
`TODO: also show C++ examples`


## Using the component library

A component is a piece of code which can instantiate a MsgFlo participant.
By default such component code is placed in `./participants/` directory of a project.

    cp ./node_modules/msgflo-nodejs/examples/Repeat.coffee ./participants/

Declaring a command template in `package.json` tells MsgFlo how to instantiate them.
This can be done per component, or by specifying a handler for a given file extension,
which makes each matching file in the component directory (here: `Repeat`) automatically available as a component.

```json
  "msgflo": {
    "handlers": {
      ".coffee": "msgflo-nodejs --name #ROLE #FILENAME"
    },
    "components": {
      "Output": "noflo-runtime-msgflo --name out --graph core/Output --broker amqp://localhost"
     }
   }
```
The component command template supports substituting several variables, including:

* `#FILENAME`: Full path to the file with the component code
* `#ROLE`: Name of the role to instantiate as
* `#COMPONENT`: Full name of component, as named in graph (project/Component).
* `#COMPONENTNAME`: Name of component without project/ (Component)

Now the example service above can be started with a single command:
By enabling `--participants` MsgFlo will start the individual participants.

    msgflo-setup ./myservice.fbp --broker amqp://localhost --participants --forward=stdout

Using `--forward stdout` enables seeing the output from the `Output` participant, which is in a child process.

Send message again, and it should be repeated on stdout.

    msgflo-send-message --queue repeater.IN --json '{ "foo": "bar-with-componentlib" }'


Having component handlers facilitates live-programming from Flowhub IDE:
Adding a new component with Python code will get a .py file extension,
and the handler for `py` will be used to instantiate a new process.

### Defaults

By default MsgFlo reads its component library configuration from the `package.json` (used by NPM).
You can specify an alternative JSON file using `--library msgflo.json`.
The configuration object can either exist at the top-level, or under a `msgflo` key.

There are [default handlers](https://github.com/msgflo/msgflo/blob/master/src/library.coffee#L9) specified
for common supported environments. These do not need to be specified manually.

*  `.py` (msgflo-python)
* `.coffee`, `.js` (msgflo-nodejs)
* `.json` and `.fbp` (noflo-runtime-msgflo)


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

Several real-life examples of foreign participant declaration can be found
[in c-flo](https://github.com/c-base/c-flo/tree/master/participants).

## Generating Heroku Procfile

`msgflo-procfile` can automatically generate a [Procfile](https://devcenter.heroku.com/articles/procfile)
for running as a Heroku service, based on the MsgFlo graph and component information.
This ensures that the production service runs in the same way as when using MsgFlo locally.

    msgflo-procfile graphs/myservice.fbp > Procfile

You can also selectively ignore certain roles in the graph, by using `--ignore role`.
Or you can include additional process stanzas by using `--include="guv: node ./node_modules/.bin/guv"`.

A real-life example can be found [in imgflo-server](https://github.com/imgflo/imgflo-server/blob/master/Makefile#L67).

## Debugging

The msgflo executable, as well as the transport/participant library
uses the [debug NPM module](https://www.npmjs.com/package/debug).
You can enable (all) logging using:

    export DEBUG=msgflo*

## Participant support for new environments

For programming languages or environments which there does not exist a MsgFlo library,
and native support is desired (ie not using "foreign participant" support), here are some guidelines.

* Must at minimum support either MQTT or AMQP brokers. If possible, support both
* Must send the MsgFlo discovery message
* Must at least support UTF-8 JSON formatted messages
* Should also support binary messages, allowing for non-JSON payloads
* The `MSGFLO_BROKER` envvar must be respected for configuring broker info (including optional user/password)
* When starting a participant via commandline, it must send output on stdout *when ready to receive messages*

Please let the community know about new MsgFlo libraries or tools, including in-progress ones.
This enables interested parties to collaborate, and avoids duplicated efforts.
For instance start a [Github issue](https://github.com/msgflo/msgflo/issues/new).

There exists a basic set of [automated tests](https://github.com/msgflo/msgflo/blob/master/spec/heterogenous.coffee)
for a participant, which checks that the guidelines above are followed.

Example usage: [code](https://github.com/msgflo/msgflo-cpp/blob/master/spec/participant.coffee),
run with `mocha --reporter spec --compilers coffee:coffee-script/register spec/participant.coffee`.
If these tests are set up and passing, with [Travis CI](http://travis-ci.org/) enabled, the library
can be hosted under the [msgflo Github organization](https://github.com/msgflo) as an official module.

## Best practices

A loose collection of best practices to consider when building systems with Msgflo.
Some of these are generic FBP/dataflow programming advice.
For scalability considerations in cloud/worker environments,
[guv best practices](https://github.com/the-grid/guv#best-practices) may also be useful.

### Components/nodes model verbs, not nouns

Components should, to the extent possible, be state-free.
Ideally all the data needed to perform a task is provided in the input data.
In object-oriented-programming the primary entities often represent things/nouns,
which encourages bundling together different aspects of, with associated buildup of state.

Instead it is preferrable to let the data that moves through the system be the thing/noun,
and let the components be the actions/verbs which *operate on* this thing.

If there are a collection of actions somehow provided by the same "thing" (like a device or subsystem),
one can use a group to visually indicate that a set of nodes are related to eachother.

### Always send data

Even for cases where one "does not need to", like when a component uses input to perform a side-effect,
like storing to a database, or notifying an external system.

This allows to know that an operation completed, and to trigger new operations afterwards.
One immediate usecase is for automated tests, which can then assert that any side-effects performed
was done, and done correctly.

If there is no processed/derived data, send the original input onwards.

### Use a dedicated port/queue for errors

Allows to easily distinguish success from failures. By convention it is often just called `error`.
This can for instance be used to automatically report failures to a QA system, for automated or manual analysis.
Or to retry operations, in order to automatically recover from intermittent failures.

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

