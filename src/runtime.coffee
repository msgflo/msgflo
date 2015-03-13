
protocol = require './protocol'
transport = require './transport'
coordinator = require './coordinator'
querystring = require 'querystring'

debug = require('debug')('msgflo:runtime')
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

    ws.on 'request', (request) =>
      subProtocol = if request.requestedProtocols.indexOf("noflo") != -1 then "noflo" else null
      connection = request.accept subProtocol, request.origin
      @connections.push connection

      connection.on 'message', (message) ->
        handleMessage message, connection
      connection.on 'close', () =>
        connIndex = @connections.indexOf connection
        return if connIndex == -1
        @connections.splice connIndex, 1

  send: (protocol, command, payload, ctx) ->
    connection = ctx
    msg =
      protocol: protocol
      command: command
      payload: payload
    debug 'SEND', msg
    send connection, msg

  sendAll: (protocol, command, payload) ->
    msg =
      protocol: protocol
      command: command
      payload: payload
    debug 'SENDALL', @connections.length, msg
    for connection in @connections
      send connection, msg

  emitMessage: (msg, ctx) ->
    @emit 'message', msg.protocol, msg.command, msg.payload, ctx

class Runtime
  constructor: (@options) ->
    @server = null
    @transport = null
    @protocol = null
    @broker = transport.getBroker @options.broker
    @coordinator = new coordinator.Coordinator @broker

  start: (callback) ->
    @server = http.createServer()
    @transport = new WebSocketTransport @server
    @protocol = protocol.Protocol @transport, @coordinator

    @server.on 'request', (request, response) =>
      @serveFrontpage request, response

    @server.listen @options.port, (err) =>
      return callback err if err
      @coordinator.start (err) =>
        return callback err if err
        onLoaded = (err) =>
          return callback err, @address(), @liveUrl()
        if @options.graph
          @coordinator.loadGraphFile @options.graph, onLoaded
        else
          onLoaded null

  stop: (callback) ->
    @server.close callback

  address: () ->
    scheme = 'ws://'
    address = scheme + @options.host + ':' + @options.port

  liveUrl: () ->
    params = querystring.escape "protocol=websocket&address=#{@address()}"
    url = "#{@options.ide}#runtime/endpoint?#{params}"

  serveFrontpage: (req, res) ->
    html = """
    <a id="flowhub_url">Open in Flowhub</a>
    <script>
      var addr = window.location.origin.replace("http://", "ws://");
      addr = addr.replace("https://", "ws://");
      var ide = "#{@options.ide}";
      var url = ide+"/#runtime/endpoint?protocol=websocket&address="+encodeURIComponent(addr);
      var a = document.getElementById("flowhub_url");
      a.href = url;
    </script>
    """
    res.statusCode = 200
    res.setHeader "Content-Type", "text/html"
    res.write html
    res.end()

exports.Runtime = Runtime

