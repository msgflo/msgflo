
amqp = require 'amqplib/callback_api'
debug = require('debug')('msgflo:amqp')

interfaces = require './interfaces'

class Client extends interfaces.MessagingClient
  constructor: (@address, @options={}) ->
    @connection = null
    @channel = null
    @options.prefetch = 2 if not @options.prefetch?

  ## Broker connection management
  connect: (callback) ->
    debug 'connect', @address
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
    debug 'disconnect'
    @channel.close (err) =>
      debug 'close', err
      return callback err

  ## Manipulating queues
  createQueue: (type, queueName, callback) ->
    debug 'create queue', type, queueName
    queueOptions =
      deadLetterExchange: 'dead-'+queueName # if not existing, messages will be dropped
    exchangeOptions = {}
    if type == 'inqueue'
      @channel.assertQueue queueName, queueOptions, callback
    else
      exchangeName = queueName
      @channel.assertExchange exchangeName, 'fanout', exchangeOptions, (err) =>
        return callback err if err
        # HACK: to make inqueue==outqueue work:
        @channel.assertQueue queueName, queueOptions, (err) =>
          return callback err if err
          @channel.bindQueue exchangeName, queueName, '', {}, callback

  removeQueue: (type, queueName, callback) ->
    debug 'remove queue', type, queueName
    if type == 'inqueue'
      @channel.deleteQueue queueName, {}, callback
    else
      exchangeName = queueName
      @channel.deleteExchange exchangeName, {}, (err) =>
        return callback err if err
        @channel.deleteQueue queueName, {}, callback

  ## Sending/Receiving messages
  sendTo: (type, name, message, callback) ->
    # queue must exists
    debug 'sendTo', type, name, message
    data = new Buffer JSON.stringify message
    if type == 'inqueue'
      # direct to queue
      exchange = ''
      routingKey = name
    else
      # to fanout exchange
      exchange = name
      routingKey = ''
    @channel.publish exchange, routingKey, data
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
    @channel.nack message.amqp, false, false

  # Participant registration
  registerParticipant: (part, callback) ->
    msg =
      protocol: 'discovery'
      command: 'participant'
      payload: part
    @channel.assertQueue 'fbp'
    data = new Buffer JSON.stringify msg
    @channel.sendToQueue 'fbp', data
    return callback null

class MessageBroker extends Client
  constructor: (address, options) ->
    super address, options

  addBinding: (binding, callback) ->
    # TODO: support roundrobin type
    debug 'Broker.addBinding', binding
    if binding.type == 'pubsub'
      @channel.bindQueue binding.tgt, binding.src, '', {}, callback
    else if binding.type == 'roundrobin'
      # Create a direct exchange, for round-robin sending to consumers
      deadLetterExchange = 'dead-'+binding.tgt
      directExchange = 'out-'+binding.src

      # XXX: do we have to pass routingKey=queueName when sending now??
      pattern = ''
      directOptions = {}
      @channel.assertExchange directExchange, 'direct', directOptions, (err) =>
        return callback err if err
        # bind input
        @channel.bindExchange directExchange, binding.src, pattern, (err), =>
          return callback err if err
          # bind output
          @channel.bindQueue binding.tgt, directExchange, pattern, {}, (err) =>
            return callback err if err

          # Setup the deadletter exchange, bind to deadletter queue
          # TODO: allow to as two independent steps? bind normal out, bind deadletter?
          deadLetterOptions = {}
          @channel.assertExchange deadLetterExchange, 'fanout', deadLetterOptions, (err) =>
            return callback err if err
            console.log 'binding deadletter', deadLetterExchange
            @channel.bindQueue binding.deadletter, deadLetterExchange, pattern, {}, callback
    else
      return callback new Error 'Unsupported binding type: '+binding.type
  removeBinding: (binding, callback) ->
    # FIXME: implement
    return callback null
  listBindings: (from, callback) ->
    return callback null, []
    
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
