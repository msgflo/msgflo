
debug = require('debug')('msgflo:routing')

# Used to bind one queue/exchange to another when the Broker
# of the transport cannot provide this functionality, like on MQTT
class Binder
  constructor: (@transport) ->

  bindQueue: (from, to, callback) ->
    debug 'Binder.bindQueue'
  
  ### TODO: implement like in Coordinator
    emitEdgeData = (data) =>
      @emit 'data', fromId, fromPort, toId, toName, data
    handler = (msg) =>
      debug 'edge message', msg
      @sendTo toId, toName, msg.data
      # NOTE: should respect "edges" message. Requires fixing Flowhub
      emitEdgeData msg.data

    @subscribeTo fromId, fromPort, handler
    id = connId fromId, fromPort, toId, toName
    @connections[id] = handler
  ###

  unbindQueue: (from, to, callback) ->
    debug 'Binder.unbindQueue'

  listBindings: (callback) ->
    debug 'Binder.listBindings'


exports.Binder = Binder
exports.binderMixin = (transport) ->
  b = new Binder transport
  transport._binder = b
  transport.bindQueue = b.bindQueue.bind b
  transport.unbindQueue = b.unbindQueue.bind b
  transport.listBindings = b.listBindings.bind b

