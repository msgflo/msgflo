## Next

Released: N/A

* ?

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
