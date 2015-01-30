
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
    @channel.sendToQueue queueName, data, callback

  subscribeToQueue: (queueName, handler, callback) ->
    # queue must exists
    deserialize = (message) =>
      msg = null
      try
        msg = JSON.parse message.content.toString()
      catch e
        console.log 'JSON parse exception:', e
      console.log 'amqp receive on queue', queueName, msg
      @channel.ack message # FIXME: add proper ACK/NACK api
      return handler msg if msg
    @channel.consume queueName, deserialize
    return callback null


exports.Client = Client
exports.MessageBroker = Client
