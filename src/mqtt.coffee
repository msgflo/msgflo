
debug = require('debug')('msgflo:mqtt')
mqtt = require 'mqtt'

interfaces = require './interfaces'
routing = require './routing'

class Client extends interfaces.MessagingClient
  constructor: (@address, @options) ->
    @client = null
    @subscribers = {} # queueName -> [handler1, ...]

  ## Broker connection management
  connect: (callback) ->
    @client = mqtt.connect @address
    onConnected = (err) =>
      debug 'connected'
      @client.on 'message', (topic, message) =>
        @_onMessage topic, message
      return callback err
    @client.once 'connect', onConnected

  disconnect: (callback) ->
    @client.removeAllListeners 'message'
    @client.removeAllListeners 'connect'
    @subscribers = {}
    @client.end (err) =>
      debug 'disconnected'
      @client = null
      return callback err

  ## Manipulating queues
  createQueue: (type, queueName, callback) ->
    # Noop, in MQTT one can send messages on 'topics' at any time
    return callback null

  removeQueue: (type, queueName, callback) ->
    # Noop, in MQTT one can send messages on 'topics' at any time
    return callback null

  ## Sending/Receiving messages
  sendTo: (type, queueName, message, callback) ->
    published = (err, granted) =>
      debug 'published', err, granted
      return callback err if err
      return callback null
    data = JSON.stringify message
    debug 'publishing', queueName, data
    @client.publish queueName, data, published

  subscribeToQueue: (queueName, handler, callback) ->
    debug 'subscribing', queueName
    @client.subscribe queueName, (err) =>
      debug 'subscribed', queueName, err
      return callback err if err
      subs = @subscribers[queueName]
      if subs then subs.push handler else @subscribers[queueName] = [ handler ]
      return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    return
  nackMessage: (message) ->
    return

  _onMessage: (topic, message) ->
    return if not @client
    return if not Object.keys(@subscribers).length > 0

    msg = null
    try
      msg = JSON.parse message.toString()
    catch e
      debug 'JSON parse exception:', e
    handlers = @subscribers[topic]

    debug 'message', handlers.length, msg != null
    return if not msg or not handlers
    out =
      data: msg
      mqtt: message
    for handler in handlers
      handler out

  registerParticipant: (part, callback) ->
    msg =
      protocol: 'discovery'
      command: 'participant'
      payload: part
    @sendToQueue 'fbp', msg, callback

class MessageBroker extends Client
  constructor: (address, options) ->
    super address, options
    routing.binderMixin this

  # Participant registration
  subscribeParticipantChange: (handler) ->
    @createQueue '', 'fbp', (err) =>
      @subscribeToQueue 'fbp', handler, () ->

exports.Client = Client
exports.MessageBroker = MessageBroker
