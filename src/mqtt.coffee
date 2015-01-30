
mqtt = require 'mqtt'

interfaces = require './interfaces'

class Client
  constructor: (@address) ->
    @client = null

  ## Broker connection management
  connect: (callback) ->
    @client = mqtt.connect @address
    console.log 'mqtt connected'
    return callback null

  disconnect: (callback) ->
    @client.end callback

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
      console.log 'mqtt published', err, granted
      return callback err if err
      return callback null
    data = JSON.stringify message
    console.log 'mqtt publishing', queueName, data
    @client.publish queueName, data, published

  subscribeToQueue: (queueName, handler, callback) ->
    onMessage = (topic, message) =>
      return if topic != queueName

      msg = null
      try
        msg = JSON.parse message.toString()
      catch e
        console.log 'JSON parse exception:', e
      return handler msg if msg
    options = {}

    console.log 'mqtt subscribing', queueName
    @client.subscribe queueName, (err) =>
      console.log 'mqtt DONE subscribing', queueName, err
      return callback err if err
      @client.on 'message', onMessage
      return callback null


exports.Client = Client
exports.MessageBroker = Client
