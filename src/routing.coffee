
debug = require('debug')('msgflo:routing')

# Used to bind one queue/exchange to another when the Broker
# of the transport cannot provide this functionality, like on MQTT
bindingId = (f, t) ->
  return "#{f}-#{t}"

class Binder
  constructor: (@transport) ->
    @bindings = {}

  bindQueue: (from, to, callback) ->
    id = bindingId from, to
    debug 'Binder.bindQueue', id
    return callback null if @bindings[id] or from == to

    handler = (msg) =>
      debug 'edge message', msg
      @transport.sendToQueue to, msg.data, (err) ->
        throw err if err
    @transport.subscribeToQueue from, handler, (err) =>
      return callback err if err
      @bindings[id] = handler
      return callback null

  unbindQueue: (from, to, callback) -> # FIXME: implement
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

