# FOSDEM 2017 IoT devroom

* Date: Saturday 4th February, 2017
* Talk accepted: https://fosdem.org/2017/schedule/event/iot_msgflo/
* Slides. [PDF](./slides.pdf) [OpenOffice](./slides.odp)
* Example code: https://github.com/jonnor/fosdem2017-iot-msgflo
* CfP: https://github.com/maximevince/IoT-devroom-fosdem

# Proposal
## Title
Building distributed systems with Msgflo

Flow-based-programming over message queues

## Abstract (500 chars)

MsgFlo is a tool to build systems that span multiple processes and devices, for instance IoT sensor networks.
Each device acts as a black-box component with input and output ports, mapped to MQTT message queues.
One then constructs a system by binding the queues of the components together.
Focus on components exchanging data gives good composability and testability, both important in IoT.
We will program a system with MsgFlo using Flowhub, a visual live-programming IDE, and test using fbp-spec.

## Full description (1500 chars)

At the 2014 IoT devroom, we introduced flow-based programming (FBP) for heterogenous IoT systems, using NoFlo and MicroFlo.
The programming model worked well for individual devices, but between the devices of the system our solution caused too tight coupling.
When we realized this, we decided to build Msgflo, which reuses many of the same concepts and tools.

In MsgFlo each process/device is an independent participant,
receiving data on input queues, and sending data on output queues.
A participant do not know where the data comes from, nor where (if anywhere) the data will go.
This strong encapsulation gives good composability and testability.
MsgFlo uses a standard message queue protocol (MQTT or AMQP).
This makes it easy to use with existing software.
As each participant is its own process and communicate over networks,
they can be implemented in any programming language.
Convenience libraries exist for C++, Python, Arduino, Node.js and Rust.
On top of the message queue protocol, a simple discovery mechanism is added.
For existing devices without native Msgflo support, the discovery messages can be sent by a dedicated tool.

We have used Msgflo in a handful of real-life deployments, and will demonstrate building a simple stand-alone IoT system.

In MsgFlo each process/device is an independent participant,
receiving data on input queues, and sending data on output queues.
A participant do not know where the data comes from, nor where (if anywhere) the data will go.
This strong encapsulation gives good composability and testability.
MsgFlo uses a standard message queue protocol (MQTT or AMQP).
This makes it easy to use with existing software.
As each participant is its own process and communicate over networks,
they can be implemented in any programming language.
Convenience libraries exist for C++, Python, Arduino, Node.js and Rust.
On top of the message queue protocol, a simple discovery mechanism is added.
For existing devices without native Msgflo support, the discovery messages can be sent by a dedicated tool.

We have used Msgflo in a handful of real-life deployments, and will demonstrate building a simple stand-alone IoT system.

## Links

https://github.com/msgflo/msgflo/blob/master/README.md
https://github.com/flowbased/fbp-spec
http://www.flowhub.io/
https://archive.fosdem.org/2014/schedule/event/deviot02/

# Slides

What to cover

* Understanding how it works
* Benefits over "traditional approach"
* What can/should it be used for right now
* Where we see this going in future

IoT first step: Get the devices and their data accessible via some protocol
Pubsub is good: Single point where one can send and pickup messages
MQTT is a good choice: open protocol, simple and well-supported.

## Ensuring reusability / composability

Device code 
In one device, receive on a certain topic
In another device, send on that topic
hardcoded queues -> hardcoded functionality -> low reusability
Don't know what connections are or what data available

## Participants as "components"

* Receives on a set of topics "inports"
* Sends on another set of topics "outports"

## Discovery protocol

* Each device describes itself
* JSON message to a standardized topic
* https://github.com/msgflo/msgflo#communications

## Working with existing devices/software

* Send discovery message on behalf
* YAML declaration
* msgflo-register-foreign

## Using Flowhub

* Start runtime. `msgflo --graph foo.json`
* Connect via live-url `http://app.flowhub.io/#runtime/endpoint?protocol%3Dwebsocket%26address%3Dws%3A%2F%2Flocalhost%3A3569`
* Introspects live system using the discovery messages
* Visual node-based programming
* Can reconfigure system on the fly
* Observe data flowing through network

## Support libraries

* Node.js
* NoFlo
* Arduino
* Rust
https://github.com/msgflo/

Creating a new library for one transport is a 1-2 day job.

## Maturity

* MsgFlo programming model and JavaScript participant libraries,
battle-tested in production with AMQP+RabbitMQ.
* MsgFlo with MQTT deployed in Berlin,Oslo hackerspaces
* Live-programming is not so much used yet
* MQTT SSL support not tested! https://github.com/msgflo/msgflo/issues/76

## Future

* SSL support verify and document
* Support RabbitMQ routing on MQTT, https://github.com/msgflo/msgflo-nodejs/issues/22
* MQTT support for msgflo-rust, https://github.com/msgflo/msgflo-rust/issues/1
* FBP protocol forwarding. Live-programming all the way down! 
* Flowhub showing changes from outside automatically (no refresh)

## Extras

### Message payloads.

* Msgflo does not care about payload format
* Slight preference for JSON in existing tooling (Flowhub) 
* Handling incompatibilities? Participants as adapters
* Easy-to introspect / see what is going on
* Super-basic type info in discovery message,
space for more. JSON schemas, etc?

### Participant modelling / conventions

* Prefer to have "services" as the core unit. Only ports/topics that affect eachother together.
Avoids dependency on a particular device / implmentation. Encourages thinking about common "interfaces".
Things that are hosted in the same device can be grouped. Naming convention etc
* Dataflow/FBP and (event driven) finite state machines provides best practices
* Source/sink/router components classes. 1->1, 1->N firing/packet patterns 
* Always send, proof that state-transition was successful (or not)
* Prefer payloads describing current state fully, instead of events / state changes. Recipient can do transition detection
* Anytime there is a parameter/configuration, expose it.
Never know when you will need it. Much faster to change it live than reflashing!


# Notes

MIT licensed.

Background

At the 2014 IoT devroom, we introduced flow-based programming (FBP) for heterogenous IoT systems, using NoFlo and MicroFlo.
We demonstrated the ability to build microcontroller-based sensors, user interfaces for the browser, and glue logic on Embedded Linux,
using the same programming methodology (FBP) and tools (Flowhub).
The programming model worked well for individual devices, but between the devices of the system there were problems:
A point-to-point protocol was used for communication, which caused a tight coupling between the individual devices.
This was against the FBP concept of assembling systems as a set of loosely coupled black-box components, lowering reuse and testability.
Furthermore the protocol was non-standard, so each device had to use these new frameworks to be able to interoperate,
which made it hard to integrate existing devices and systems.

Msgflo

* Use standard message queue protocol and broker. Ex: MQTT with Mosquitto
* Does not touch message payloads, use what you'd like.
* Can be configured to use specific topic/queue names of existing sytems
* Any programming language, combinations of multiple languages

MsgFlo provides:

* A discovery protocol with self-describing units
* Some documented conventions/best-practices in how to model system. Including topic names, input/output
* A set of convenience libraries for common languages. Node.js, C++, Python, Rust, Arduino 
* The libraries have a basic abstraction of the underlying protocol (MQTT, AMQP supported)
* Support for visual-live-programming via noflo-ui/Flowhub IDE 
* Support for fbp-spec, a declarative data-driven testing tool

Benefits

* Self-documenting, docs come from code, so always up to date
* Quick understanding of system via visual diagrams, introspection of data in network
* High testability and composability due to strong encapsulation
* Quick experimentation via live programming
* Lots of data due to connected-first strategy, network-effects

MsgFlo is used

* at c-base hackerspace in Berlin
* at Bitraf hackerspace in Oslo
* At TheGrid (cloud, not IoT).
* In imgflo-server (cloud, not IoT)

Future

* Introspection of individual participants as graphs, by forwarding FBP protocol
* Support for Flowtrace, for retroactive debugging

# Demo

* Couple of sensors, sending data on MQTT. Ex: Temp/humidity/soundlevel/ambientlight
* Also have an input device unit "remote control". Button/potmeter. Maybe also some RGB LEDs.
* Sensors should be portable and wireless. Battery/microcontroller
* Maybe have an adapter for stock 433Mhz sensors?
* Embedded Linux device (Raspberry Pi), running the coordinator. Runs like audio
* Wireless AP is done by the RPi, or a dedicated router. USB battery? 10Ah should be 15 hours.

# TODO

* Milestone: https://github.com/msgflo/msgflo/milestone/2
* Important: Edge data introspection, https://github.com/msgflo/msgflo/issues/3
* Bonus: 

# Ideas

Should have a Msgflo web? or "browser"
Especially for building UIs, and having these represented in the system as participants
Support MQTT over WebSockets (Mosquitto, RabbitMQ)

Would be good to have a set of "virtual" devices in a webUI that can be used to test

# Guidelines

Topics

    FOSS solutions for machine-to-machine communication on small embedded devices.
    Distributed FOSS applications in any field of interest for autonomous/self-controlled devices, (e.g. domotics, automotive, etc.
    Presentation of embedded devices with one or more possibilities to join a network.
    Infrastructure related (TCP/IP, mesh networking, message queuing, cross-layer solutions).
    Real-life problematics and their solution (Cost of maintenance, power management, reachability).
    Interoperability solutions for heterogeneous applications, devices, protocols, media.

All presentations must be fully FOSS, and related to software development.

