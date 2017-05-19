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
* Basic support for **browser** participants with [msgflo-browser](https://github.com/msgflo/msgflo-browser)
* Experimental support for **Arduino** participants with [msgflo-arduino](https://github.com/msgflo/msgflo-arduino)
* Experimental support for **Rust** participants with [msgflo-rust](https://github.com/msgflo/msgflo-rust)

Tooling

* `msgflo` executable implements the [FBP runtime protocol](https://flowbased.github.io/fbp-protocol).
* Initial support for automated testing using [fbp-spec](https://github.com/flowbased/fbp-spec)
* Experimental support for visually building networks using [Flowhub](https://flowhub.io/)
* [guv](http://github.com/the-grid/guv) provides autoscaling of workers when using Heroku/AMQP.

## Licence

MIT, see [./LICENSE](./LICENSE)

## Documentation

Please refer to <https://msgflo.org>

## Debugging

The msgflo executable, as well as the transport/participant library
uses the [debug NPM module](https://www.npmjs.com/package/debug).
You can enable (all) logging using:

    export DEBUG=msgflo*
