
* April 6th, 2017
* Barcelona, Spain
* https://ti.to/blended/orchestrate-2017

# Abstract

## Scalable web services using message queues with Msgflo and GuvScale 

Different parts of your application have different performance characteristics.
Some tasks are CPU-bound, some database-limited, some limited by external APIs/services.
By splitting tasks out to dedicated workers using a message queues like RabbitMQ
we can scale each worker role independently. This can enable a higher overall application performance and cost-efficiency.
I'll show how MsgFlo tooling makes it easier to set up and understand a distributed, multi-worker system.
And then how to automatically scale the workers based on their amount of tasks, using the GuvScale Heroku addon.

# Plan

## Format

## Outline

* whoami
* Distributed system. Definition, characteristics.
* Example problem/system
* What to split to background workers.
* ? Different communication approaches
* How AMQP/RabbitMQ works
* Why message queues/broker
* What MsgFlo adds
* Deploying live service, testing with some examples
* Opening in Flowhub?? Looking at data going through?
* Killing the worker, processing resumes when up again
* Overwhelming the service with requests, degrades performance
* Setting up GuvScale
* Running tests again, now autoscaling to maintain perf

The problem: Building a performant, cost-effective cloud service that is scalable. 
Solution: Use MsgFlo to separate work into dedicated workers communicating over RabbitMQ.
Use GuvScale to automatically scale the different workers according to their loads.

## Key points

* Use message queues for distributed systems, instead of request/response like HTTP
* Using hetrogenous workers enables more efficient scaling, compared to homogenous all-in-frontend
* Flowhub w/Msgflo makes it easier to understand the system
* Use GuvScale on Heroku for autoscaling your system

Sidepoints

* Making the external HTTP API async allows more flexibility. create-job:response...request:status/results
* Job APIs should generally take sets, not invididual items, as input.

## Not covered

Maybe just mention in brief

* MsgFlo for IoT / embedded device networks
* General-purpose programming with Flowhub (NoFlo/MicroFlo).

# Notes



## TODO

msgflo-nodejs, AMQP/RabbitMQ backend

* Support edge data instrospection
* Support/test live-changes to data-routing
