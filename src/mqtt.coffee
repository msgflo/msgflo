
debug = require('debug')('msgflo:mqtt')
mqtt = require 'mqtt'

interfaces = require './interfaces'

class Client
  constructor: (@address) ->
    @client = null
    @subscribers = {} # queueName -> [handler1, ...]

  ## Broker connection management
  connect: (callback) ->
    @client = mqtt.connect @address
    onConnected = (err) =>
      @client.on 'message', (topic, message) =>
        @_onMessage topic, message
      return callback err
    @client.once 'connect', onConnected

  disconnect: (callback) ->
    @client.removeAllListeners 'message'
    @client.removeAllListeners 'connect'
    @subscribers = {}
    @client.end (err) =>
      @client = null
      return callback err

  ## Manipulating queues
  createQueue: (queueName, callback) ->
    # Noop, in MQTT one can send messages on 'topics' at any time
    return callback null

  removeQueue: (queueName, callback) ->
    # Noop, in MQTT one can send messages on 'topics' at any time
    return callback null

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
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


exports.Client = Client
exports.MessageBroker = Client
