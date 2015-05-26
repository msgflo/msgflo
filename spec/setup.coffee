
msgflo = require '../'
participants = require './fixtures/participants'

async = require 'async'
chai = require 'chai' unless chai
path = require 'path'

fixturePath = (name) ->
  path.join __dirname, 'fixtures', name
fixtureGraph = (name, callback) ->
  p = fixturePath name
  msgflo.common.readGraph p, callback

linesContaining = (lines, str) =>
  lines = lines.split '\n'
  containing = lines.filter (s) -> s.indexOf(str) != -1

describe 'Setup functions', ->
  bindings = null
  graph = null

  beforeEach (done) ->
    fixtureGraph 'imgflo-server.fbp', (err, gr) ->
      graph = gr
      chai.expect(err).to.not.exist
      bindings = msgflo.setup.graphBindings graph
      done()

  describe 'Extracting from imgflo-server.fbp', ->
    it 'should have one binding per non-roundrobin connection', () ->
      console.log graph.connections
      console.log bindings
      chai.expect(bindings.length).to.equal graph.connections.length-2
    it 'should extract all pubsub bindings', () ->
      pubsubs = bindings.filter (b) -> b.type == 'pubsub'
      chai.expect(pubsubs).to.have.length 1
    it 'should extract roundrobin binding', () ->
      roundrobins = bindings.filter (b) -> b.type == 'roundrobin'
      chai.expect(roundrobins).to.have.length 1
  describe 'Pretty formatting bindings', ->
    pretty = null
    beforeEach () ->
      pretty = msgflo.setup.prettyFormatBindings bindings
    it 'should return one line per binding', () ->
      chai.expect(pretty.split('\n')).to.have.length bindings.length+1 # roundrobin also has deadletter
    it 'should have one roundrobin', () ->
      match = linesContaining pretty, 'ROUNDROBIN'
      chai.expect(match).to.have.length 1
    it 'should have one deadletter', () ->
      match = linesContaining pretty, 'DEADLETTER'
      chai.expect(match).to.have.length 1
    it 'should have one pubsub', () ->
      match = linesContaining pretty, 'PUBSUB'
      chai.expect(match).to.have.length 1

describe 'Setup bindings', ->
  address = 'amqp://localhost'
  manager = null
  options = null
  client = null
  broker = null
  bindings = null

  beforeEach (done) ->
    options =
      graphfile: fixturePath 'simple.fbp'
      broker: address
    client = msgflo.transport.getClient address
    broker = msgflo.transport.getBroker address
    manager = new msgflo.manager.ParticipantManager address, 'ss'
    manager.library = participants

    readGraph = (callback) ->
      msgflo.common.readGraph options.graphfile, (err, graph) ->
        manager.graph = graph if graph
        return callback err
    setupBindings = (callback) ->
      msgflo.setup.bindings options, (err, b, graph) ->
        bindings = b if b
        return callback err
    async.series [
      readGraph
      broker.connect.bind broker
      manager.start.bind manager
      client.connect.bind client
      setupBindings
    ], (err) ->
      chai.expect(err).to.not.exist
      done()

  describe 'Setting up simple FBP graph', ->
    it 'should return bindings made', (done) ->
      console.log 'return bindings'
      chai.expect(bindings).to.be.an 'array'
      chai.expect(bindings.length).to.equal manager.graph.connections.length-2
      pretty = msgflo.setup.prettyFormatBindings bindings
      done()

    it 'should have set up src->tgt binding', (done) ->
      console.log 'src->tgt'
      input =
        foo: 'bar'
      onMessage = (msg) ->
        chai.expect(msg.data).to.eql input
        done()
      client.subscribeToQueue 's_worker.OUT', onMessage, (err) ->
        chai.expect(err).to.not.exist
        client.sendTo 'inqueue', 's_api.IN', input, (err) ->
          chai.expect(err).to.not.exit

    it 'should have set up deadlettering'
