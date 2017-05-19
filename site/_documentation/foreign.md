---
title: Non-MsgFlo-aware participants
---
MsgFlo can work with existing code that uses a supported message-queues system (AMQP, MQTT).
Because the existing code is not MsgFlo-aware, another process needs to send the MsgFlo discovery
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

And then run `msgflo-register` to publish the information

    msgflo-register --role A:./participants/ProcessSomething.yaml

The `queue` key supports substituting `#ROLE`. This allows a single YAML file to declare a component
which can be instantiated multiple times - each with a different role and queue name.

Several real-life examples of foreign participant declaration can be found
[in c-flo](https://github.com/c-base/c-flo/tree/master/participants).

