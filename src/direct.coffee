
debug = require('debug')('msgflo:direct')
EventEmitter = require('events').EventEmitter

interfaces = require './interfaces'
routing = require './routing'

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

  _assertBroker: (callback) ->
    err = new Error "no broker connected #{@address}" if not @broker
    return callback err if err

  ## Manipulating queues
  createQueue: (type, queueName, callback) ->
#    console.log 'client create queue', queueName
    @_assertBroker callback
    @broker.createQueue type, queueName, callback

  removeQueue: (type, queueName, callback) ->
    @_assertBroker callback
    @broker.removeQueue type, queueName, callback

  ## Sending/Receiving messages
  sendTo: (type, queueName, message, callback) ->
    @_assertBroker callback
    @broker.sendTo type, queueName, message, callback

  subscribeToQueue: (queueName, handler, callback) ->
    @_assertBroker callback
    @broker.subscribeToQueue queueName, handler, callback

  ## ACK/NACK messages
  ackMessage: (message) ->
    return
  nackMessage: (message) ->
    return

  # Participant discovery
  registerParticipant: (part, callback) ->
    @createQueue '', 'fbp', (err) =>
      msg =
        protocol: 'discovery'
        command: 'participant'
        payload: part
      @sendToQueue 'fbp', msg, callback

class Queue extends EventEmitter
  constructor: () ->

  send: (msg) ->
    @_emitSend msg

  _emitSend: (msg) ->
    @emit 'message', msg

class MessageBroker extends interfaces.MessageBroker
  constructor: (@address) ->
    routing.binderMixin this
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
  createQueue: (type, queueName, callback) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    return callback null

  removeQueue: (type, queueName, callback) ->
    delete @queues[queueName]
    return callback null

  ## Sending/Receiving messages
  sendTo: (type, queueName, message, callback) ->
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

  subscribeParticipantChange: (handler) ->
    @createQueue '', 'fbp', (err) =>
      @subscribeToQueue 'fbp', handler, () ->

exports.MessageBroker = MessageBroker
exports.Client = Client

