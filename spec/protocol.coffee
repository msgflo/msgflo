
chai = require 'chai'
EventEmitter = require('events').EventEmitter
websocket = require 'websocket'
fbp = require 'fbp'
fs = require 'fs'
path = require 'path'

participants = require './fixtures/participants'
Runtime = require('../src/runtime').Runtime

rmrf = (dir) ->
  return if not fs.existsSync dir

  for f in fs.readdirSync dir
    f = path.join dir, f
    try
      fs.unlinkSync f
    catch e
      if e.code == 'EISDIR'
        rmrf f
      else
        throw e

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
    runtimeId: '1b4628d6-a2e0-4873-92ee-eb5c4e4b06f3'
    config:
      namespace: ''
      repository: 'git://github.com/msgflo/msgflo.git'

  before (done) ->
    rmrf options.componentdir
    fs.rmdirSync options.componentdir if fs.existsSync options.componentdir
    fs.mkdirSync options.componentdir
    comp = fs.readFileSync(__dirname+'/fixtures/ProduceFoo.coffee', 'utf-8')
    comp = comp.replace /ProduceFoo/g, 'InitiallyAvailable'
    fs.writeFileSync path.join(options.componentdir,'InitiallyAvailable.coffee'), comp

    runtime = new Runtime options
    runtime.start (err, url) ->
      chai.expect(err).to.not.exist
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
    describe 'capabilities', ->
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
    it 'namespace should match namespace from config', ->
      chai.expect(info.namespace).to.be.a 'string'
      chai.expect(info.namespace).to.equal ''
    it 'repository should match repository from config', ->
      chai.expect(info.repository).to.be.a 'string'
      chai.expect(info.repository).to.contain 'git://'
      chai.expect(info.repository).to.contain 'msgflo.git'
    it 'runtime id should match options.runtimeId', ->
      chai.expect(info.id).to.be.a 'string'
      chai.expect(info.id).to.equal options.runtimeId

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
      source = participants.Hello options.broker, 'say'
      sink = participants.DevNullSink options.broker, 'sink'
      source.definition.outports[0].queue = sink.definition.inports[0].queue
      sink.start (err) ->
        chai.expect(err).to.be.a 'null'
        source.start (err) ->
          chai.expect(err).to.be.a 'null'

          checkMessage = (d, protocol, command, payload) ->
            return if command == 'component' # Ignore component update coming from instantiating

            chai.expect(payload).to.be.an 'object'
            chai.expect(payload).to.include.keys ['name', 'code', 'language']
            chai.expect(payload.language).to.equal 'json'
            graph = JSON.parse payload.code
            chai.expect(graph).to.include.keys ['connections', 'processes']
            chai.expect(graph.connections).to.have.length 1
            conn = graph.connections[0]
            chai.expect(conn.src.process).to.equal 'say'
            chai.expect(conn.src.port).to.equal 'out'
            chai.expect(conn.tgt.process).to.equal 'sink'
            chai.expect(conn.tgt.port).to.equal 'drop'
            ui.removeListener 'message', checkMessage
            done()
          ui.on 'message', checkMessage

          setTimeout () ->
            ui.send 'component', 'getsource', { name: 'default/main' }
          , 500

  describe 'stopping a running network', ->
    it 'should succeed'
    it 'network:getstatus shows not running'
    it 'should not respond to messages'

  describe 'starting a stopped network', ->
    it 'should succeed'
    it 'network:getstatus should show running'
    it 'should respond to messages again'

  describe 'adding an edge', ->
    repeatA = null
    repeatB = null
    before (done) ->
      repeatA = participants.Repeat options.broker, 'addedge-repeat-A'
      repeatA.start (err) ->
        return done err if err
        repeatB = participants.Repeat options.broker, 'addedge-repeat-B'
        return repeatB.start done
    after (done) ->
      repeatA.stop (err) ->
        return repeatB.stop done

    it 'should succeed', (done) ->
      edge =
        src: { node: 'addedge-repeat-A', port: 'out' }
        tgt: { node: 'addedge-repeat-B', port: 'in' }
        metadata:
          route: 1
      ui.once 'message', (d, protocol, command, payload) ->
        chai.expect(payload).to.be.a 'object'
        chai.expect(command, JSON.stringify(payload)).to.equal 'addedge'
        chai.expect(protocol).to.equal 'graph'
        chai.expect(payload).to.have.keys ['src', 'tgt', 'metadata']
        chai.expect(payload.src.node).to.equal edge.src.node
        chai.expect(payload.src.port).to.equal edge.src.port
        chai.expect(payload.tgt.node).to.equal edge.tgt.node
        chai.expect(payload.tgt.port).to.equal edge.tgt.port
        chai.expect(payload.metadata).to.eql edge.metadata
        return done()
      ui.send 'graph', 'addedge', edge

    it 'data should now be forwarded'

    it 'should be possible to change edge metadata', (done) ->
      checkMessage = (d, protocol, command, payload) ->
        chai.expect(command, JSON.stringify(payload)).to.equal 'changeedge'
        chai.expect(protocol).to.equal 'graph'
        chai.expect(payload).to.be.an 'object'
        chai.expect(payload).to.include.keys ['src', 'tgt', 'metadata']
        chai.expect(payload.metadata).to.eql change.metadata
        ui.removeListener 'message', checkMessage
        done()
      ui.on 'message', checkMessage
      change =
        src: { node: 'addedge-repeat-A', port: 'out' }
        tgt: { node: 'addedge-repeat-B', port: 'in' }
        metadata:
          route: 5
      ui.send 'graph', 'changeedge', change

  describe 'removing a connected edge', ->
    repeatA = null
    repeatB = null
    before (done) ->
      repeatA = participants.Repeat options.broker, 'removeedge-repeat-A'
      repeatA.start (err) ->
        return done err if err
        repeatB = participants.Repeat options.broker, 'removeedge-repeat-B'
        repeatB.start (err) ->
          edge =
            src: { node: 'removeedge-repeat-A', port: 'out' }
            tgt: { node: 'removeedge-repeat-B', port: 'in' }
          check = (d, protocol, command, payload) ->
            return if command == 'component'
            chai.expect(command).to.equal 'addedge'
            ui.removeListener 'message', check
            return done()
          ui.on 'message', check
          ui.send 'graph', 'addedge', edge
    after (done) ->
      repeatA.stop (err) ->
        return repeatB.stop done

    it 'should succeed', (done) ->
      edge =
        src: { node: 'removeedge-repeat-A', port: 'out' }
        tgt: { node: 'removeedge-repeat-B', port: 'in' }
      ui.once 'message', (d, protocol, command, payload) ->
        chai.expect(payload).to.be.a 'object'
        chai.expect(command, JSON.stringify(payload)).to.equal 'removeedge'
        chai.expect(protocol).to.equal 'graph'
        chai.expect(payload).to.have.keys ['src', 'tgt']
        chai.expect(payload.src.node).to.equal edge.src.node
        chai.expect(payload.src.port).to.equal edge.src.port
        chai.expect(payload.tgt.node).to.equal edge.tgt.node
        chai.expect(payload.tgt.port).to.equal edge.tgt.port
        return done()
      ui.send 'graph', 'removeedge', edge

    it 'data should now not be forwarded'

  describe 'adding and removing a node', ->
    responses = []
    nodeName = 'add-remove-node'
    componentName = 'InitiallyAvailable'
    onNewMessage = null
    checkMessage = (d, protocol, command, payload) ->
      responses.push
        protocol: protocol
        command: command
        payload: payload
      if onNewMessage
        onNewMessage()

    beforeEach () ->
      responses = []
      ui.on 'message', checkMessage
    afterEach () ->
      ui.removeListener 'message', checkMessage
      onNewMessage = null

    it 'adding should have one addnode response', (done) ->
      onNewMessage = () ->
        addnodes = responses.filter (r) -> r.protocol == 'graph' and r.command == 'addnode'
        return if not addnodes.length # still waiting

        chai.expect(addnodes, JSON.stringify(responses)).to.have.length 1
        addnode = addnodes[0].payload
        chai.expect(addnode).to.include.keys ['id', 'graph', 'component']
        chai.expect(addnode.id).to.equal nodeName
        chai.expect(addnode.component).to.equal componentName
        return done()

      node =
        id: nodeName
        graph: 'default/main'
        component: componentName
      ui.send 'graph', 'addnode', node

    it 'removing should have one removenode response', (done) ->
      onNewMessage = () ->
        removenodes = responses.filter (r) -> r.protocol == 'graph' and r.command == 'removenode'
        return if not removenodes.length # still waiting

        chai.expect(removenodes, JSON.stringify(responses)).to.have.length 1
        response = removenodes[0].payload
        chai.expect(response).to.include.keys ['id', 'graph', 'component']
        chai.expect(response.id).to.equal nodeName
        chai.expect(response.component).to.equal componentName
        return done()

      remove =
        id: nodeName
        graph: 'default/main'
        component: componentName
      ui.send 'graph', 'removenode', remove

    it 'after removing should not be in graph source', (done) ->
      onNewMessage = () ->
        sources = responses.filter (r) -> r.protocol == 'component' and r.command == 'source'
        return if not sources.length # still waiting

        payload = sources[0].payload
        chai.expect(payload).to.include.keys ['name', 'code', 'language']
        chai.expect(payload.language).to.equal 'json'
        graph = JSON.parse payload.code
        chai.expect(graph).to.include.keys ['processes']
        chai.expect(graph.processes).to.not.include.keys [ nodeName ]
        return done()

      ui.send 'component', 'getsource',
        name: 'default/main'

  describe 'adding a component', ->
    componentName = 'SetSource'
    componentCode = fs.readFileSync(__dirname+'/fixtures/ProduceFoo.coffee', 'utf-8')
    componentCode = componentCode.replace(/ProduceFoo/g, componentName)

    it 'should become available', (done) ->
      receivedAck = false
      receivedComponent = false
      checkMessage = (d, protocol, command, payload) ->
        chai.expect(payload).to.be.an 'object'

        if command == 'source'
          # ACK
          chai.expect(protocol).to.equal 'component'
          chai.expect(payload).to.include.keys ['name', 'code', 'language', 'library']
          chai.expect(payload.language).to.equal 'coffeescript'
          chai.expect(payload.code).to.include "component: '#{componentName}'"
          chai.expect(payload.code).to.include "module.exports = #{componentName}"
          receivedAck = true
          console.log 'got ACK'
        else if command == 'component'
          # New component
          chai.expect(protocol).to.equal 'component'
          chai.expect(payload).to.include.keys ['name', 'subgraph', 'inPorts', 'outPorts']
          chai.expect(payload.name).to.equal componentName
          receivedComponent = true
          console.log 'got Component'
        else
          chai.expect(command, "Unexpected command").to.not.exist

        if receivedAck and receivedComponent
          ui.removeListener 'message', checkMessage
          done()

      ui.on 'message', checkMessage

      source =
        name: componentName
        library: options.config.namespace
        language: 'coffeescript'
        code: componentCode
      ui.send 'component', 'source', source
    
    it 'should be returned on getsource', (done) ->
      ui.once 'message', (d, protocol, command, payload) ->
        chai.expect(payload).to.be.an 'object'
        chai.expect(command, JSON.stringify(payload)).to.equal 'source'
        chai.expect(protocol).to.equal 'component'
        chai.expect(payload).to.include.keys ['name', 'code', 'language']
        chai.expect(payload.library).to.equal options.config.namespace
        chai.expect(payload.name).to.equal 'SetSource'
        chai.expect(payload.language).to.equal 'coffeescript'
        chai.expect(payload.code).to.include "component: '#{componentName}'"
        chai.expect(payload.code).to.include "module.exports = #{componentName}"
        done()

      source =
        name: componentName
      ui.send 'component', 'getsource', source

    it 'should be instantiable as new node', (done) ->
      checkMessage = (d, protocol, command, payload) ->
        return if command == 'component' # Ignore component update coming from instantiating

        chai.expect(command, JSON.stringify(payload)).to.equal 'addnode'
        chai.expect(protocol).to.equal 'graph'
        chai.expect(payload).to.be.an 'object'
        chai.expect(payload).to.include.keys ['id', 'graph', 'component']
        chai.expect(payload.component).to.equal componentName
        chai.expect(payload.metadata).to.eql add.metadata
        ui.removeListener 'message', checkMessage
        done()
      ui.on 'message', checkMessage
      add =
        id: 'mycoffeescriptproducer'
        graph: 'default/main'
        component: componentName
        metadata:
          label: 'myproducer'
      ui.send 'graph', 'addnode', add
    it 'should be possible to change node metadata', (done) ->
      checkMessage = (d, protocol, command, payload) ->
        chai.expect(command, JSON.stringify(payload)).to.equal 'changenode'
        chai.expect(protocol).to.equal 'graph'
        chai.expect(payload).to.be.an 'object'
        chai.expect(payload).to.include.keys ['id', 'graph', 'metadata']
        chai.expect(payload.metadata).to.eql change.metadata
        ui.removeListener 'message', checkMessage
        done()
      ui.on 'message', checkMessage
      change =
        id: 'mycoffeescriptproducer'
        graph: 'default/main'
        metadata:
          label: 'mycoffeeproducer'
          x: 2
      ui.send 'graph', 'changenode', change
    it 'should include node metadata in JSON result', (done) ->
      checkMessage = (d, protocol, command, payload) ->
        return unless protocol is 'component'
        ui.removeListener 'message', checkMessage
        chai.expect(command, JSON.stringify(payload)).to.equal 'source'
        chai.expect(payload).to.include.keys ['name', 'code', 'language']
        chai.expect(payload.language).to.equal 'json'
        graph = JSON.parse payload.code
        chai.expect(graph).to.include.keys ['connections', 'processes']
        chai.expect(graph.processes).to.include.keys ['mycoffeescriptproducer']
        chai.expect(graph.processes.mycoffeescriptproducer).to.eql
          component: componentName
          metadata:
            label: 'mycoffeeproducer'
            x: 2
        done()
      ui.on 'message', checkMessage
      ui.send 'component', 'getsource',
        name: 'default/main'

  describe 'subscribing to edges', ->
    repeatA = null
    repeatB = null
    before (done) ->
      # TODO: use addnode to setup instead
      repeatA = participants.Repeat options.broker, 'edgedata-repeat-A'
      repeatA.start (err) ->
        return done err if err
        repeatB = participants.Repeat options.broker, 'edgedata-repeat-B'
        return repeatB.start done
    after (done) ->
      repeatA.stop (err) ->
        return repeatB.stop done

    it 'should emit data flowing through network', (done) ->
      edge =
        src: { node: 'edgedata-repeat-A', port: 'out' }
        tgt: { node: 'edgedata-repeat-B', port: 'in' }
      ui.send 'graph', 'addedge', edge
      indata =
        foo: 'subscribe-edge-11'
      onNetwork = (d, protocol, command, payload) ->
        chai.expect(payload).to.be.a 'object'
        if command == 'edges'
          repeatA.send 'in', indata
        else if command == 'data'
          chai.expect(payload.src).to.eql edge.src
          chai.expect(payload.tgt).to.eql edge.tgt
          chai.expect(payload.data).to.eql indata
          ui.removeListener 'network', onNetwork
          return done null
      ui.on 'message', onNetwork
      subscribe =
        edges: [ edge ]
      ui.send 'network', 'edges', subscribe

  describe 'adding an node and immediately a IIP', ->
    # stresses the case where we probably don't have complete information about the added node yet
    # as the discovery message will take a bit of time.
    # When using Flowhub in project mode this is a likely case to happen. Probably also fbp-spec
    responses = []
    componentName = 'InitiallyAvailable'

    before (done) ->
      @timeout 10*1000
      checkMessage = (d, protocol, command, payload) ->
        return if command == 'component' # Ignore component update coming from instantiating
        responses.push
          protocol: protocol
          command: command
          payload: payload
        expected = responses.filter (r) -> r.command in ['addinitial', 'addnode']
        if expected.length >= 2
          ui.removeListener 'message', checkMessage
          done()
      ui.on 'message', checkMessage

      node =
        id: 'iip-target'
        graph: 'default/main'
        component: componentName
      initial =
        tgt: { node: node.id, port: 'interval' },
        src: { data: 0 }
      ui.send 'graph', 'addnode', node
      ui.send 'graph', 'addinitial', initial

    it 'should have one addnode response', ->
      addnodes = responses.filter (r) -> r.protocol == 'graph' and r.command == 'addnode'
      chai.expect(addnodes, JSON.stringify(responses)).to.have.length 1
      addnode = addnodes[0].payload
      chai.expect(addnode).to.include.keys ['id', 'graph', 'component']
    it 'should have one addinitial response', ->
      addinitials = responses.filter (r) -> r.protocol == 'graph' and r.command == 'addinitial'
      chai.expect(addinitials, JSON.stringify(responses)).to.have.length 1
      addinitial = addinitials[0].payload
      chai.expect(addinitial).to.include.keys ['tgt', 'src']
      chai.expect(addinitial.tgt).to.include.keys ['node', 'port']
      chai.expect(addinitial.tgt.node).to.equal 'iip-target'
      chai.expect(addinitial.tgt.port).to.equal 'interval'

    it 'clearing the graph should remove processes and IIPs', (done) ->
      responses = []
      graphName = 'default/main'
      checkMessage = (d, protocol, command, payload) ->
        responses.push
          protocol: protocol
          command: command
          payload: payload
        if command == 'clear'
          chai.expect(payload).to.include.keys ['id']
          chai.expect(payload.id).to.equal graphName
          ui.send 'component', 'getsource', { name: graphName }
        else if command == 'source'
          chai.expect(payload).to.include.keys ['name', 'code', 'language']
          chai.expect(payload.name).to.equal 'main'
          graph = JSON.parse payload.code
          roles = Object.keys graph.processes
          inports = Object.keys graph.inports
          outports = Object.keys graph.outports
          chai.expect(roles, JSON.stringify(roles)).to.have.length 0
          chai.expect(graph.connections, JSON.stringify(graph.connections)).to.have.length 0
          chai.expect(inports).to.have.length 0
          chai.expect(outports).to.have.length 0
          return done()

      ui.on 'message', checkMessage
      ui.send 'graph', 'clear', { id: graphName }
