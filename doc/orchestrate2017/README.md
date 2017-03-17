
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


# Notes

## TODO

msgflo-nodejs, AMQP/RabbitMQ backend

* Support edge data instrospection
* Support/test live-changes to data-routing
