
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
        @channel.on 'close', () ->
          console.log 'AQMP CLOSED'
        @channel.on 'error', (err) ->
          throw err if err
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
    console.log 'amqp send to queue', queueName
    data = new Buffer JSON.stringify message
    @channel.sendToQueue queueName, data, (err) ->
      throw err if err
    return callback null

  subscribeToQueue: (queueName, handler, callback) ->
    console.log 'amqp subscribe', queueName
    # queue must exists
    deserialize = (message) =>
      data = null
      try
        data = JSON.parse message.content.toString()
      catch e
        console.log 'JSON parse exception:', e
      console.log 'amqp receive on queue', queueName
      out =
        amqp: message
        data: data
      return handler out
    @channel.consume queueName, deserialize
    console.log 'amqp done subscribe', queueName
    return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    console.log 'ampq ACK'
    # NOTE: server will only give us new message after this
    @channel.ack message.amqp, (err) -> throw err
  nackMessage: (message) ->
    @channel.nack message.amqp, (err) -> throw err

exports.Client = Client
exports.MessageBroker = Client
