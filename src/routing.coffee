
debug = require('debug')('msgflo:routing')

# Used to bind one queue/exchange to another when the Broker
# of the transport cannot provide this functionality, like on MQTT
bindingId = (f, t) ->
  return "#{f}-#{t}"

class Binder
  constructor: (@transport) ->
    @bindings = {}

  addBinding: (binding, callback) ->
    from = binding.src
    to = binding.tgt
    # TODO: handle non-pubsub types
    id = bindingId from, to
    debug 'Binder.addBinding', binding.type, id
    return callback null if @bindings[id] or from == to

    handler = (msg) =>
      debug 'edge message', msg
      @transport.sendToQueue to, msg.data, (err) ->
        throw err if err
    @transport.subscribeToQueue from, handler, (err) =>
      return callback err if err
      @bindings[id] = handler
      return callback null

  removeBinding: (binding, callback) -> # FIXME: implement
    debug 'Binder.removeBinding', binding

  listBindings: (callback) ->
    debug 'Binder.listBindings'


exports.Binder = Binder
exports.binderMixin = (transport) ->
  b = new Binder transport
  transport._binder = b
  transport.addBinding = b.addBinding.bind b
  transport.removeBinding = b.removeBinding.bind b
  transport.listBindings = b.listBindings.bind b

