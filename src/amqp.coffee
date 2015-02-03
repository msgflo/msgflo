
amqp = require 'amqplib/callback_api'

interfaces = require './interfaces'

class Client
  constructor: (@address) ->
    @connection = null
    @channel = null

  ## Broker connection management
  connect: (callback) ->
    console.log 'client connect'
    amqp.connect @address, (err, conn) =>
      console.log 'amqp connected', err
      return callback err if err
      @connection = conn
      conn.createChannel (err, ch) =>
        console.log 'amqp channel created', err
        return callback err if err
        @channel = ch
        return callback null

  disconnect: (callback) ->
    @channel.close (err) =>
      console.log 'CLOSE ', err
      return callback err

  ## Manipulating queues
  createQueue: (queueName, callback) ->
    @channel.assertQueue queueName
    return callback null

  removeQueue: (queueName, callback) ->
    throw new Error 'Not Implemented'

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
    # queue must exists
    console.log 'amqp send to queue', queueName, message
    data = new Buffer JSON.stringify message
    @channel.sendToQueue queueName, data
    return callback null

  subscribeToQueue: (queueName, handler, callback) ->
    console.log 'amqp subscribe', queueName
    # queue must exists
    deserialize = (message) =>
      console.log 'amqp recv'
      data = null
      try
        data = JSON.parse message.content.toString()
      catch e
        console.log 'JSON parse exception:', e
      console.log 'amqp receive on queue', queueName, data
      out =
        amqp: message
        data: data
      @ackMessage out # TEMP: should be done by consumers
      return handler out
    @channel.consume queueName, deserialize
    console.log 'amqp done subscribe', queueName
    return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    @channel.ack message.amqp
  nackMessage: (message) ->
    @channel.nack message.amqp

exports.Client = Client
exports.MessageBroker = Client
