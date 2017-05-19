
* April 6th, 2017
* Barcelona, Spain
* Website: https://ti.to/blended/orchestrate-2017

# Presentation

* Slides [PDF](./slides.pdf) | [ODP](./slides.odp)
* Demo application: [msgflo-example-imageresize](https://github.com/msgflo/msgflo-example-imageresize)

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

Slides, with a demo split over two sections/sessions.

## Outline

The problem: Building a performant, cost-effective cloud service that is scalable. 
Solution: Use MsgFlo to separate work into dedicated workers communicating over RabbitMQ.
Use GuvScale to automatically scale the different workers according to their loads.

### Background
10 minutes.

* whoami
* This talk.
* @TheGrid. Content analysis, constraint solving, image processing.
* Distributed system. Definition, characteristics.
* Example problem/system
* What to split to background workers.
"A good rule of thumb is to avoid web requests which run longer than 500ms".
https://devcenter.heroku.com/articles/background-jobs-queueing
* ? Different communication approaches
* How AMQP/RabbitMQ works
* Why message queues/broker. Persistence/retry/resume

### MsgFlo
10 minutes.

* What is it
* What MsgFlo adds, what it does not.
* Flow-based-programming model
* Discovery message/protocol
* Polyglot/heterogenous
* Message-payload-agnostic
* Multi-transport. AMQP 0.9, MQTT
* Graph definition. Visual, .FBP DSL, .json
* () Live introspection
* () Live reprogramming
* Not. Message broker (RabbitMQ does that)
* Not. Load-balancing (RabbitMQ round-robin does that)
* Not. Executing/hosting tasks (systemd/Docker/Kubernetes/Heroku does that)
* Not. Provide persistence of jobs or results. Use Postgres/Redis/MongoDB
* Comparison with other paradigms/tools.
Stream processing (Kafka). https://www.confluent.io/blog/introducing-kafka-streams-stream-processing-made-simple/
Other task queues (Celery). http://docs.celeryproject.org/en/latest/userguide/tasks.html#task-result-backends

### Live demo
10 minutes.

* Live service existing on Heroku. What was needed to put it there
* Testing with some example data
* Showing the code, participants
* Killing the worker, processing resumes when up again.
* Overwhelming the service with requests, performance degrades.

### QA: Msgflo
5-10 minutes

### GuvScale
10 minutes

* What is it
* Setting up GuvScale
* Advantages over other autoscalers. Efficiency/utilization. Predictable performance.
Kubernetes autoscale aims for 50% utilization by default.
https://kubernetes.io/docs/user-guide/horizontal-pod-autoscaling/walkthrough/
* Running tests again, now autoscaling to maintain perf

### QA: GuvScale
5-10 minutes


Undecided

* Msgflo best practices
* GuvScale best practices
* Common architecture patterns.
Syncronous request/response.
Different processors, then combine results.
Routing for quality of service.
Autonomous system isolated from frontend/web. Process control etc
* Flowhub. Visually. Can instrospect and live-program
* Summarize each main section, key points
* Summarize everything at the end

Bonus

* 

## Key points

* Use message queues for distributed systems, instead of request/response like HTTP
* Using hetrogenous workers enables more efficient scaling, compared to homogenous all-in-frontend
Each worker has known perf bounds. Can operate very close to RAM limits. 100% utilization good not bad!
* Flowhub w/Msgflo makes it easier to understand the system.
Lifting the queue connections up, out of individual code. Visualizing your live architecture. 
* Use GuvScale on Heroku for autoscaling your system.
Maintain a predictable performance. Keep 90+% utilization.

Sidepoints

* Making the external HTTP API async allows more flexibility in scaling. create-job:response...request:status/results
* Job APIs should generally take sets (N), not invididual items, as input. Less requests, can keep closer to client model.

Misc

* Writing tests black-box. Can run against production/staging service. Ensures introspectabilty from outside.
* Storing jobs with timestamps and results/errors, lets you query it later. Debugging. Can replace analytics services.

## Calls to action

* Go to the GuvScale website. Install the beta for your Heroku system.
* Try out the Msgflo example app.
* Go to msgflo.org website. Make your next service based on message-queues with Msgflo.
* Come talk to me afterwards. About message queues, data-driven programming, autoscaling

## Not covered

Maybe just mention in brief

* MsgFlo for IoT / embedded device networks
* General-purpose programming with Flowhub (NoFlo/MicroFlo).

# Notes


# images
sequence diagram.
https://d2slcw3kip6qmk.cloudfront.net/marketing/pages/chart/uml/sequence-diagram/sequence-diagram-example-700x500.jpeg

RabbitMQ logo
https://www.cloudamqp.com/images/blog/rabbitmq.png

Constraint solving graph
http://www.cs.toronto.edu/~eihsu/tutorial7/

TheGrid content analysis
http://automata.cc/discovering-salient-regions/

Image processing
http://www.pbs.org/pov/blog/povdocs/2014/07/smart-cropping-for-video-a-tool-for-displaying-video-at-any-aspect-ratio/

# diagrams

## How broker model work

```
# DSL used: https://bramp.github.io/js-sequence-diagrams/
title: Broker model

participant web
participant worker
participant otherworker
participant RabbitMQ


web->RabbitMQ: Job {}
RabbitMQ->worker: Job {}
worker->RabbitMQ: JobResult {}
RabbitMQ->otherworker: JobResult {}
```

```
# DSL used: https://bramp.github.io/js-sequence-diagrams/
title: Direct model

participant web
participant worker
participant otherworker


web->worker: Job {}
worker->otherworker: JobResult {}
```

## TODO

Complete demo app.

### Bonus

msgflo-nodejs, AMQP/RabbitMQ backend

* Support edge data instrospection
* Support/test live-changes to data-routing
