
protocol = require './protocol'
coordinator = require './coordinator'
common = require './common'

querystring = require 'querystring'
transport = require('msgflo-nodejs').transport
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
        msg = JSON.parse(message.utf8Data)
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
    if command == 'error'
      console.error "#{protocol}:error", payload.message

    connection = ctx
    msg =
      protocol: protocol
      command: command
      payload: payload
    debug 'SEND', msg
    send connection, msg

  sendAll: (protocol, command, payload) ->
    if command == 'error'
      console.error "#{protocol}:error", payload.message

    msg =
      protocol: protocol
      command: command
      payload: payload
    debug 'SENDALL', @connections.length, msg
    for connection in @connections
      send connection, msg

  emitMessage: (msg, ctx) ->
    @emit 'message', msg.protocol, msg.command, msg.payload, ctx

# atomic
saveGraphFile = (graph, filepath, callback) ->
  fs = require 'fs'
  temppath = filepath + ".msgflo-autosave-#{Date.now()}"
  json = JSON.stringify graph, null, 2
  fs.open temppath, 'wx', (err, fd) ->
    return callback err if err
    fs.write fd, json, (err) ->
      return callback err if err
      fs.fsync fd, (err) ->
        return callback err if err
        fs.rename temppath, filepath, (err) ->
          fs.unlink temppath, (e) ->
            return callback err

class Runtime
  constructor: (@options) ->
    @server = null
    @transport = null
    @protocol = null
    @broker = transport.getBroker @options.broker
    @coordinator = new coordinator.Coordinator @broker, @options

    @saveGraph = common.debounce () =>
      debug 'saving graph changes', @options.graph
      graph = @coordinator.serializeGraph 'main'
      saveGraphFile graph, @options.graph, (err) ->
        console.log "ERROR: Failed to save graph file", err if err
    , 500
    if @options.graph and @options.autoSave
      debug 'enabling autosave'
      @coordinator.on 'graph-changed', () =>
        @saveGraph()

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
          @coordinator.loadGraphFile @options.graph, @options, onLoaded
        else
          onLoaded null

  stop: (callback) ->
    @coordinator.stop (stopErr) =>
      @server.close (closeErr) ->
        return callback stopErr if stopErr
        return callback closeErr if closeErr
        return callback null

  address: () ->
    scheme = 'ws://'
    address = scheme + @options.host + ':' + @options.port

  liveUrl: () ->
    params = querystring.escape "protocol=websocket&address=#{@address()}&id=#{@options.runtimeId}"
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

