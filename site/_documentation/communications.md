---
title: Discovery protocol
score: 9
---
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

The message `payload` contains the following information:

* `id`: short unique name for the participant. Ex: measure1
* `role`: the role this participant has in the network. Used to group multiple partipants. Ex: measure
* `component`: the component name of the participant. One component may be used in several roles. For instance MeasurementWorker
* `label`: (optional) human-readable description of the system
* `icon`: (optional) icon to use to describe the system, using [Font Awesome](http://fontawesome.io/icons/) semantics
* `inports`: list of inports containing:
  - `id`: port name
  - `queue`: the message queue the process listens to
  - `type`: port datatype, for example `boolean`
  - `description`: (optional) Human-readable description of the port and its function
  - `schema`: (optional) URL to a JSON schema for data expected on port
  - `options`: (optional) queue options as specified by the message queue implementation
* `outports`: list of outports containing:
  - `id`: port name
  - `queue`: the message queue the process transmits to
  - `type`: port datatype, for example `boolean`
  - `description`: (optional) Human-readable description of the port and its function
  - `schema`: (optional) URL to a JSON schema for data sent on port
  - `options`: (optional) queue options as specified by the message queue implementation

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


