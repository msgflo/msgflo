## 0.10.23 | released 02.06.2017

* Fix `getSource` for participants started by the runtime

## 0.8.0 | released 03.08.2016

* Fix spec/heterogenous participant test enforcing wrong discovery message.
The messages sent to `fbp` topic must have a wrapper with protocol=discovery and command=participant.

## 0.7.0 | released 06.06.2016

* Update to msgflo-nodejs 0.5.x, which does not install transport libraries (`mqtt` or `amqplib`) automatically.
You must now install these as dependencies yourself.

## 0.6.0 | released 21.04.2016

* Initial support for [fbp-spec](https://github.com/flowbased/fbp-spec), a data-driven testing tool

## 0.5.1 - 0.5.33

* Added `msgflo-send-message` utility program, send message to MQTT/AMQP queues
* Added `msgflo-register-foreign` utility, allows to declare MsgFlo participant discovery data
for existing systems which don't have native MsgFlo support.
* Added `msgflo-jobstats-newrelic` tool, for downloading statistics from the New Relic integration
about how long it takes to execute jobs. Can for instance be used to tune an autoscaler like [guv](https://github.com/the-grid/guv)

## 0.5.0

Released: 15 June, 2016

* Added ability to define component libraries in `.json` file.
Each compononent has a command which can be used to instantiate such a component.
By default the key `msgflo.components` in `package.json` is used.
* Added `msgflo-procfile` for generating [Heroku Procfile](https://devcenter.heroku.com/articles/procfile) stansa, from component library + FBP graph.
* Added ability for `msgflo-setup` to also start up participants, from component library + FBP graph.

## 0.4.0

Released: 4 June, 2015

* New C++ and Python participant libraries:
[msgflo-cpp](https://github.com/msgflo/msgflo-cpp) and [msgflo-python](https://github.com/msgflo/msgflo-cpp)
* Moved out `participant` and `transport` modules to separate
[msgflo-nodejs](https://github.com/msgflo/msgflo-nodejs) library.
For compatibility, msgflo currently forwards these APIs.
* Moved git repository from the-grid to msgflo organization on Github, https://github.com/msgflo/msgflo

## 0.3.0

Released: 30 May, 2015

* Added `msgflo.setup` API and `msgflo-setup` executable,
for setting up queue bindings between participants from a FBP graph.
* Using the special FBP component `msgflo/RoundRobin` in FBP graphs
allows to specify roundrobin (including deadlettering) binding instead of the default pubsub.
* Added `msgflo-dump-message` executable, for getting messages from a queue

## 0.2.0

Released: 21 May, 2015

* First version used in production for [api.thegrid.io](http://developer.thegrid.io)

## 0.1.0

Released: 5 April, 2015

* First version used in production in [imgflo-server](http://github.com/jonnor/imgflo-server)
