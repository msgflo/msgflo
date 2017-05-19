---
title: imgflo
subtitle: Distributed computing with MsgFlo
cover: /assets/imgflo-cassowary.png
---
[imgflo](http://www.imgflo.org/) is a on-demand image processing server based on [GEGL](http://gegl.org/). Processing pipelines can be created interactively using the visual, node-based IDE [Flowhub](https://flowhub.io).

The server shipping with imgflo uses MsgFlo to coordinate processing tasks between workers.

![MsgFlo graph for imgflo](/assets/msgflo-imgflograph.png)

The graph above represents how different roles are wired together. There may be 1-N participants in the same role, for instance 10 dynos of the same dyno type on Heroku.
There can also be multiple participants in a single process. This can be useful to make different independent facets show up as independent nodes in a graph, even if they happen to be executing in the same process. One could use the same mechanism to implement a shared-nothing message-passing multithreading model, with the limitation that every message will pass through a broker.

Connections have pub-sub semantics, so generally each of the individual dynos will receive messages sent on the connection.

The special component _msgflo/RoundRobin_ specifies that messages should be delivered in a round-robin fashion: new message goes only to the next process in that role with available capacity. The RoundRobin component also supports dead-lettering, so failed jobs can be routed to another queue. For instance to be re-processed at a later point automatically, or manually after developers have located and fixed the issue. This way one never loose pending work.
On AMQP roundrobin delivery and deadlettering can be fulfilled by the broker (e.g. RabbitMQ), so there is no dedicated process for that node.

The imgflo MsgFlo setup can be seen at <https://github.com/imgflo/imgflo-server>. There is also one-click support for deploying your own on Heroku.
