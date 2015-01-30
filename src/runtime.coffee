
protocol = require './protocol'

http = require 'http'
EventEmitter = require('events').EventEmitter
WebSocketServer = require('websocket').server

send = (connection, msg) ->
  connection.sendUTF JSON.stringify msg

class WebSocketTransport extends EventEmitter
  constructor: (@server) ->
    @connections = []
    ws = new WebSocketServer { httpServer: @server }

    handleMessage = (message, connection) =>
      return if message.type != 'utf8'
      try
        msg = JSON.parse(message.utf8Data);
      catch e
        return null
      @emitMessage msg, connection

    ws.on 'request', (request) ->
      subProtocol = if request.requestedProtocols.indexOf("noflo") != -1 then "noflo" else null
      connection = request.accept subProtocol, request.origin
      @connections.push connection

      connection.on 'message', (message) ->
        handleMessage message, connection
      connection.on 'close', () ->
        connIndex = @connections.indexOf connection
        return if connIndex == -1
        runtime.connections.splice connIndex, 1

  send: (protocol, command, payload, ctx) ->
    connection = ctx
    msg =
      protocol: protocol
      command: command
      payload: payload
    send connection, msg

  sendAll: (protocol, command, payload) ->
    msg =
      protocol: protocol
      command: command
      payload: payload
    for connection in @connections
      send connection, msg

  emitMessage: (msg, ctx) ->
    @emit 'message', msg.protocol, msg.command, msg.payload, ctx


class Runtime
  constructor: (@options) ->
    @server = null
    @transport = null
    @protocol = null

  start: (callback) ->
    @server = http.createServer()
    @transport = new WebSocketTransport @server
    @protocol = protocol.Protocol @transport

    @server.listen @options.port, (err) =>
      return callback err if err
      scheme = 'ws://'
      address = scheme + @options.host + ':' + @options.port
      return callback null, address

  stop: (callback) ->
    @server.close callback


exports.Runtime = Runtime

