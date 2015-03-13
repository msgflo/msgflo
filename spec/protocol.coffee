
chai = require 'chai'
EventEmitter = require('events').EventEmitter
websocket = require 'websocket'

Runtime = require('../src/runtime').Runtime

class MockUi extends EventEmitter
  constructor: ->
    @connection = null
    @client = new websocket.client()
    @client.on 'connect', (connection) =>
      @connection = connection
      @connection.on 'error', (error) =>
        throw error
      @connection.on 'close', (error) =>
        @emit 'disconnected'
      @connection.on 'message', (message) =>
        @handleMessage message
      @emit 'connected', connection

  connect: (port) ->
    @client.connect "ws://localhost:#{port}/", "noflo"
  disconnect: ->
    @connection.close() if @connection
    @emit 'disconnected'

  send: (protocol, command, payload) ->
    msg =
      protocol: protocol
      command: command
      payload: payload || {}
    @sendMsg msg
  sendMsg: (msg) ->
    @connection.sendUTF JSON.stringify msg

  handleMessage: (message) ->
    if not message.type == 'utf8'
      throw new Error "Received non-UTF8 message: " + message
    d = JSON.parse message.utf8Data
    @emit 'message', d, d.protocol, d.command, d.payload



describe 'FBP runtime protocol', () ->
  runtime = null
  ui = new MockUi

  before (done) ->
    options =
      broker: 'direct://broker111'
      port: 3333
      host: 'localhost'
    runtime = new Runtime options
    runtime.start (err, url) ->
      chai.expect(err).to.be.a 'null'
      ui.once 'connected', () ->
        done()
      ui.connect options.port
  after (done) ->
    ui.once 'disconnected', () ->
      runtime.stop () ->
        runtime = null
        done()
    ui.disconnect()

  describe 'runtime info', ->
    info = null
    it 'should be returned on getruntime', (done) ->
      ui.send "runtime", "getruntime"
      ui.on 'message', (d, protocol, command, payload) ->
        info = payload
        chai.expect(info).to.be.an 'object'
        done()
    it 'type should be "msgflo"', ->
      chai.expect(info.type).to.equal "msgflo"
    it 'protocol version should be "0.4"', ->
      chai.expect(info.version).to.be.a "string"
      chai.expect(info.version).to.equal "0.4"
    describe 'capabilities"', ->
      it 'should be an array', ->
        chai.expect(info.capabilities).to.be.an "array"
      it 'should include "protocol:component"', ->
        chai.expect(info.capabilities).to.include "protocol:component"
      it 'should include "protocol:graph"', ->
        chai.expect(info.capabilities).to.include "protocol:graph"
      it 'should include "protocol:network"', ->
        chai.expect(info.capabilities).to.include "protocol:network"
      it 'should include "component:getsource"', ->
        chai.expect(info.capabilities).to.include "component:getsource"


