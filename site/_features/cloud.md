---
title: Horizontally scalable web services
cover: /assets/msgflo-system-example-cloud.png
score: 10
---
A web service built using several groups of workers,
each performing a set of tasks, and communicating with eachother using a messaging queue service.
Some of the participants may provide HTTP REST interfaces or persistance to SQL/noSQL database,
others just perform computation.
Typical execution environments include Heroku, Amazon EC2, OpenStack, OpenShift.
Typical messaging system used are AMQP, ZeroMQ, Amazon Simple Queue Service, Google Cloud Pubsub.
