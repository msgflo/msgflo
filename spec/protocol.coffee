
chai = require 'chai'
EventEmitter = require('events').EventEmitter
websocket = require 'websocket'
fbp = require 'fbp'
fs = require 'fs'

participants = require './fixtures/participants'
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
  options =
    broker: 'mqtt://localhost'
    port: 3333
    host: 'localhost'
    componentdir: 'spec/protocoltemp'

  before (done) ->
    fs.rmdirSync options.componentdir if fs.existsSync options.componentdir
    fs.mkdirSync options.componentdir
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
      ui.once 'message', (d, protocol, command, payload) ->
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
      it 'should include "component:setsource"', ->
        chai.expect(info.capabilities).to.include "component:setsource"

  describe 'participant queues already connected', ->
    # TODO: move IIP sending into Participant class?
    sendGraphIIPs = (part, graph) ->
      processIsParticipant = (name) ->
        process = graph.processes[name]
        return name == part.definition.id
      processes = Object.keys(graph.processes).filter processIsParticipant
      iips = graph.connections.filter (c) -> return c.data? and c.tgt.process in processes
      for iip in iips
        part.send iip.tgt.port, iip.data

    it 'should show as connected edges', (done) ->
      graph = fbp.parse " 'world' -> NAME say(Hello) OUT -> DROP sink(DevNullSink) "
      source = participants.Hello options.broker, 'say'
      sink = participants.DevNullSink options.broker, 'sink'
      source.connectGraphEdges graph
      sink.connectGraphEdges graph
      sink.start (err) ->
        chai.expect(err).to.be.a 'null'
        source.start (err) ->
          chai.expect(err).to.be.a 'null'

          ui.once 'message', (d, protocol, command, payload) ->
            chai.expect(payload).to.be.an 'object'
            chai.expect(payload).to.include.keys ['name', 'code', 'language']
            chai.expect(payload.language).to.equal 'json'
            graph = JSON.parse payload.code
            chai.expect(graph).to.include.keys ['connections', 'processes']
            chai.expect(graph.connections).to.have.length 1
            conn = graph.connections[0]
            chai.expect(conn.src.process).to.contain 'say'
            chai.expect(conn.src.port).to.equal 'out'
            chai.expect(conn.tgt.process).to.contain 'sink'
            chai.expect(conn.tgt.port).to.equal 'drop'
            done()
          setTimeout () ->
            ui.send 'component', 'getsource', { name: 'default/main' }
          , 500

    # TODO: automatically represent multiple participants of same class as subgraph
  describe 'stopping a running network', ->
    it 'should succeed'
    it 'network:getstatus shows not running'
    it 'should not respond to messages'

  describe 'starting a stopped network', ->
    it 'should succeed'
    it 'network:getstatus should show running'
    it 'should respond to messages again'

  describe 'adding an edge', ->
    it 'should succeed'
    it 'data should now be forwarded'

  describe 'removing a connected edge', ->
    it 'should succeed'
    it 'data should now be forwarded'

  describe 'adding a node', ->
    it 'should succeed'
    it 'node should produce data'

  describe 'removing a node', ->
    it 'should succeed'
    it 'node should not produce data anymore'

  describe 'adding a component', ->
    componentName = 'foo/SetSource'
    componentCode = fs.readFileSync(__dirname+'/fixtures/ProduceFoo.coffee', 'utf-8')

    it 'should become available', (done) ->
      ui.once 'message', (d, protocol, command, payload) ->
        chai.expect(payload).to.be.an 'object'
        chai.expect(payload).to.include.keys ['name', 'code', 'language']
        chai.expect(payload.language).to.equal 'coffeescript'
        chai.expect(payload.code).to.include "component: 'ProduceFoo'"
        chai.expect(payload.code).to.include "module.exports = ProduceFoo"
        done()

      source =
        name: componentName
        language: 'coffeescript'
        library: undefined
        code: componentCode
      ui.send 'component', 'source', source
    
    it 'should be returned on getsource', (done) ->
      ui.once 'message', (d, protocol, command, payload) ->
        chai.expect(payload).to.be.an 'object'
        chai.expect(protocol).to.equal 'component'
        chai.expect(command, JSON.stringify(payload)).to.equal 'source'
        chai.expect(payload).to.include.keys ['name', 'code', 'language']
        chai.expect(payload.name).to.equal componentName
        chai.expect(payload.language).to.equal 'coffeescript'
        chai.expect(payload.code).to.include "component: 'ProduceFoo'"
        chai.expect(payload.code).to.include "module.exports = ProduceFoo"
        done()

      source =
        name: componentName
      ui.send 'component', 'getsource', source

    it 'should be instantiable as new node', (done) ->
      ui.once 'message', (d, protocol, command, payload) ->
        chai.expect(protocol).to.equal 'graph'
        chai.expect(command).to.equal 'addnode'
        chai.expect(payload).to.be.an 'object'
        chai.expect(payload).to.include.keys ['id', 'graph', 'component']
        chai.expect(payload.component).to.equal componentName
        done()
      add =
        id: 'mycoffeescriptproducer'
        graph: 'default/main'
        component: componentName
      ui.send 'graph', 'addnode', add

