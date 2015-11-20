
msgflo_nodejs = require 'msgflo-nodejs'
Promise = require 'bluebird'

SpyParticipant = (address, role, queueMapping) ->

  definition =
    component: 'test/SpyParticipant'
    label: 'Lets you snoop on data!'
    inports: []
    outports: []

  for name, exchange of queueMapping
    definition.inports.push
      id: name
      hidden: false
    definition.outports.push
      id: name
      hidden: true

  part = null
  func = (portname, indata, send) ->
    part.data[portname].push indata
    send portname, null, indata

  part = new msgflo_nodejs.participant.Participant address, definition, func, role
  part.reset = () ->
    part.data = {}
    for name, _ of queueMapping
      part.data[name] = []

  # connects to the queues
  part.setupBindings = (callback) ->
    # need Broker interface to do bindings
    client = msgflo_nodejs.transport.getBroker address

    addBinding = (name, _i, _j, cb) ->
      srcExchange = queueMapping[name]
      return cb null if not srcExchange # no binding
      binding =
        type: 'pubsub'
        src: srcExchange
        tgt: "#{role}.#{name.toUpperCase()}"
      client.addBinding binding, cb

    returnResults = (err, data) ->
      client.disconnect () ->
        return callback err, data

    client.connect (err) ->
      return callback err if err
      names = Object.keys queueMapping
      Promise.map(names, Promise.promisify(addBinding))
        .then((data) ->  returnResults null, data)
        .catch(returnResults)

  # Convenience for starting participant and setting up bindings
  part.startSpying = (callback) ->
    part.start (err) ->
      return callback err if err
      part.setupBindings callback

  part.getMessages = (port, number, callback) ->
    checkSendMessages = () ->
      messages = part.data[port]
      #console.log 'SpyParticipant.checkSendMessages', port, messages
      return if not messages?
      return if messages.length < number
      messages = messages.splice(0, number)
      #console.log 'SpyParticipant.getMessages returning', messages, part.data
      part.removeListener 'data', checkSendMessages
      return callback messages

    part.on 'data', checkSendMessages
    checkSendMessages() # we might already have the requested data

  part.reset()
  return part

module.exports = SpyParticipant
