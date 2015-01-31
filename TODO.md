
0.1.0
-------

* TEST: attempt to run The Grid
* Add warning on duplicate queue names/mismatching datatypes
* Fix removeEdge
* Fix removeInitial
* Make fbp-test pass all cases

Soon
-----

* Use setTimeout to make direct transport "async"
* Support for FBP components which we can only have one of in FBP protocol
* Ability to spawn participants from cordinator

Later
-----

* Support informing which execution model participant has
* Fire `processerror` when node does not respond to heartbeat
* Handle disconnects/errors in MQTT and AMQP
* Add ability to directly ruote between queues for AMQP
* Move queue abstraction to separate library, for reuse in noflo-runtime etc
* Ability to scale number of workers on Heroku

Ideas
-------

* A mechanical turk task as a participant in the flow

