
debug = require('debug')('msgflo:direct')
EventEmitter = require('events').EventEmitter
uuid = require 'uuid'

interfaces = require './interfaces'
routing = require './routing'

brokers = {}

newMessageId = () ->
  return "msg-#{uuid.v4()}"

class Client extends interfaces.MessagingClient
  constructor: (@address, @options) ->
#    console.log 'client', @address
    @broker = null
    @id = "client-#{uuid.v4()}"
  
  ## Broker connection management
  connect: (callback) ->
    debug 'client connect'
    @broker = brokers[@address]
    @broker._clientConnect this
    return callback null
  disconnect: (callback) ->
    debug 'client disconnect'
    @broker._clientDisconnect this
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
  sendToQueue: (queueName, message, callback) ->
    @_assertBroker callback
    @broker.sendToQueue queueName, message, callback

  subscribeToQueue: (queueName, handler, callback) ->
    @_assertBroker callback
    @broker.subscribeToQueue queueName, handler, callback

  ## ACK/NACK messages
  ackMessage: (message) ->
    @_assertBroker callback
    @broker._clientAckMessage this, message

  nackMessage: (message) ->
    @_assertBroker callback
    @broker._clientNackMessage this, message

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


class ClientData
  constructor: () ->
    @messages = {}

class MessageBroker extends interfaces.MessageBroker
  constructor: (@address) ->
    routing.binderMixin this
    @queues = {}
    @clientData = {} # client.id -> ClientData
    @id = @address
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

  _clientConnect: (client) ->
    @clients[client.id] = client
  _clientDisconnect: (client) ->
    delete @clients[client.id]

  ## Manipulating queues
  createQueue: (type, queueName, callback) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    return callback null

  removeQueue: (type, queueName, callback) ->
    delete @queues[queueName]
    return callback null

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
#    console.log 'broker sendToQueue', queueName, Object.keys(@queues), @queues[queueName]
    @queues[queueName].send message
    return callback null

  subscribeToQueue: (queueName, handler, callback) ->
    @_clientSubscribeToQueue this, queueName, handler, callback

  _clientSubscribeToQueue: (client, queueName, handler, callback) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    @queues[queueName].on 'message', (data) ->
      out =
        direct:
          id: newMessageId()
        data: data
      return handler out
    return callback null

  _clientAckMessage: (client, message) ->
    msgId = message.direct.id
    return
  _clientNackMessage: (client, message) ->
    return

  ## ACK/NACK messages
  ackMessage: (message) ->
    @_clientAckMessage this, message
  nackMessage: (message) ->
    @_clientAckMessage this, message

  subscribeParticipantChange: (handler) ->
    @createQueue '', 'fbp', (err) =>
      @subscribeToQueue 'fbp', handler, () ->

exports.MessageBroker = MessageBroker
exports.Client = Client

