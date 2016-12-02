# FOSDEM 2017 IoT devroom

* CfP: https://github.com/maximevince/IoT-devroom-fosdem
* Date: Saturday 4th February, 2017, somewhere between 10.30 and 18:00
* Format: 25 mins, with demo 5-10min, talk 5-10min, QA 5min.

# Title
Building distributed systems with Msgflo

Flow-based-programming over message queues

# Abstract (500 chars)

MsgFlo is a tool to build systems that span multiple processes and devices, for instance IoT sensor networks.
Each device acts as a black-box component with input and output ports, mapped to MQTT message queues.
One then constructs a system by binding the queues of the components together.
Focus on components exchanging data gives good composability and testability, both important in IoT.
We will program a system with MsgFlo using Flowhub, a visual live-programming IDE, and test using fbp-spec.

# Full description (1500 chars)

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

# Links

https://github.com/msgflo/msgflo/blob/master/README.md
https://github.com/flowbased/fbp-spec
http://www.flowhub.io/
https://archive.fosdem.org/2014/schedule/event/deviot02/

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
* Does touch message payloads, use what you'd like.
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

