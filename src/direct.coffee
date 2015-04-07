
debug = require('debug')('msgflo:direct')
interfaces = require './interfaces'
EventEmitter = require('events').EventEmitter

brokers = {}


class Client extends interfaces.MessagingClient
  constructor: (@address, @options) ->
#    console.log 'client', @address
    @broker = null
  
  ## Broker connection management
  connect: (callback) ->
    debug 'client connect'
    @broker = brokers[@address]
    return callback null
  disconnect: (callback) ->
    debug 'client disconnect'
    @broker = null
    return callback null

  ## Manipulating queues
  createQueue: (queueName, callback) ->
#    console.log 'client create queue', queueName
    @broker.createQueue queueName, callback

  removeQueue: (queueName, callback) ->
    @broker.removeQueue queueName, callback

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
    @broker.sendToQueue queueName, message, callback

  subscribeToQueue: (queueName, handler, callback) ->
    @broker.subscribeToQueue queueName, handler, callback

  ## ACK/NACK messages
  ackMessage: (message) ->
    return
  nackMessage: (message) ->
    return


class Queue extends EventEmitter
  constructor: () ->

  send: (msg) ->
    @_emitSend msg

  _emitSend: (msg) ->
    @emit 'message', msg

class MessageBroker extends interfaces.MessageBroker
  constructor: (@address) ->
    @queues = {}
#    console.log 'broker', @address

  ## Broker connection management
  connect: (callback) ->
    debug 'broker connect'
    brokers[@address] = this
    return callback null
  disconnect: (callback) ->
    debug 'broker disconnect'
    delete brokers[@address]
    return callback null

  ## Manipulating queues
  createQueue: (queueName, callback) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    return callback null

  removeQueue: (queueName, callback) ->
    delete @queues[queueName]
    return callback null

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
#    console.log 'broker sendToQueue', queueName, Object.keys(@queues), @queues[queueName]
    @queues[queueName].send message
    return callback null

  subscribeToQueue: (queueName, handler, callback) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    @queues[queueName].on 'message', (data) ->
      out =
        direct: null
        data: data
      return handler out
    return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    return
  nackMessage: (message) ->
    return

exports.MessageBroker = MessageBroker
exports.Client = Client

