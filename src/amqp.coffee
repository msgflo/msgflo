
amqp = require 'amqplib/callback_api'
debug = require('debug')('msgflo:amqp')

interfaces = require './interfaces'

class Client
  constructor: (@address, @options={}) ->
    @connection = null
    @channel = null
    @options.prefetch = 2 if not @options.prefetch?

  ## Broker connection management
  connect: (callback) ->
    debug 'connect'
    amqp.connect @address, (err, conn) =>
      debug 'connected', err
      return callback err if err
      @connection = conn
      conn.createChannel (err, ch) =>
        debug 'channel created', err
        return callback err if err
        @channel = ch
        debug 'setting prefetch', @options.prefetch
        @channel.prefetch @options.prefetch
        @channel.on 'close', () ->
          debug 'channel closed'
        @channel.on 'error', (err) ->
          throw err if err
        return callback null

  disconnect: (callback) ->
    @channel.close (err) =>
      debug 'close', err
      return callback err

  ## Manipulating queues
  createQueue: (type, queueName, callback) ->
    @channel.assertQueue queueName
    return callback null

  removeQueue: (type, queueName, callback) -> # FIXME: do something here?
    return callback null

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
    # queue must exists
    debug 'send', queueName
    data = new Buffer JSON.stringify message
    @channel.sendToQueue queueName, data, (err) ->
      throw err if err
    return callback null

  subscribeToQueue: (queueName, handler, callback) ->
    debug 'subscribe', queueName
    # queue must exists
    deserialize = (message) =>
      debug 'receive on queue', queueName, message.fields.deliveryTag
      data = null
      try
        data = JSON.parse message.content.toString()
      catch e
        debug 'JSON exception:', e
      out =
        amqp: message
        data: data
      return handler out
    @channel.consume queueName, deserialize
    debug 'subscribed', queueName
    return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    fields = message.amqp.fields
    debug 'ACK', fields.routingKey, fields.deliveryTag
    # NOTE: server will only give us new message after this
    @channel.ack message.amqp, false
  nackMessage: (message) ->
    fields = message.amqp.fields
    debug 'NACK', fields.routingKey, fields.deliveryTag
    @channel.nack message.amqp, false

  # Participant registration
  registerParticipant: (part, callback) ->
    msg =
      protocol: 'discovery'
      command: 'participant'
      payload: part
    @channel.assertQueue 'fbp'
    data = new Buffer JSON.stringify msg
    return @channel.sendToQueue 'fbp', data, callback

class MessageBroker extends Client
  constructor: (address, options) ->
    super address, options

  bindQueue: (from, to, callback) ->
    return callback null
  unbindQueue: (from, to, callback) ->
    return callback null
  listBindings: (from, callback) ->
    return callback null
    
  # Participant registration
  subscribeParticipantChange: (handler) ->
    deserialize = (message) =>
      debug 'receive on fbp', message.fields.deliveryTag
      data = null
      try
        data = JSON.parse message.content.toString()
      catch e
        debug 'JSON exception:', e
      out =
        amqp: message
        data: data
      return handler out

    @channel.assertQueue 'fbp'
    @channel.consume 'fbp', deserialize

exports.Client = Client
exports.MessageBroker = MessageBroker
