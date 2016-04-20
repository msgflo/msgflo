
msgflo = require '../'
participants = require './fixtures/participants'
foreignParticipants = require './fixtures/foreign'

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
    it 'should have one binding per non-roundrobin connection or IIP', () ->
      chai.expect(bindings.length).to.equal graph.connections.length-3
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
  options = null
  client = null
  bindings = null
  participants = null

  beforeEach (done) ->
    @timeout 8000
    options =
      graphfile: fixturePath 'simple.fbp'
      libraryfile: fixturePath 'library-simple.json'
      broker: address
      forward: 'stderr,stdout'
    client = msgflo.transport.getClient address

    setupParticipants = (callback) ->
      msgflo.setup.participants options, (err, p) ->
        participants = p
        return callback err
    setupBindings = (callback) ->
      msgflo.setup.bindings options, (err, b, graph) ->
        bindings = b if b
        return callback err
    async.series [
      setupParticipants
      client.connect.bind client
      setupBindings
    ], (err) ->
      chai.expect(err).to.not.exist
      done()

  afterEach (done) ->
    @timeout 4000
    killParticipants = (callback) ->
      return msgflo.setup.killProcesses participants, 'SIGKILL', callback
    async.series [
      client.disconnect.bind client
      killParticipants
    ], (err) ->
      chai.expect(err).to.not.exist
      done()

  describe 'Setting up simple FBP graph', ->
    it 'should return bindings made', (done) ->
      chai.expect(bindings).to.be.an 'array'
      chai.expect(bindings.length).to.equal 4-2
      pretty = msgflo.setup.prettyFormatBindings bindings
      done()

    it 'should have set up src->tgt binding', (done) ->
      input =
        foo: 'bar'
      onMessage = (msg) ->
        chai.expect(msg.data).to.eql input
        done()
      client.createQueue 'inqueue', 's_worker.OUT', (err) ->
        chai.expect(err).to.not.exist
        client.subscribeToQueue 's_worker.OUT', onMessage, (err) ->
          chai.expect(err).to.not.exist
          client.sendTo 'inqueue', 's_api.IN', input, (err) ->
            chai.expect(err).to.not.exit

    it 'should have set up deadlettering'

describe 'foreign MQTT participants', () ->

  address = 'mqtt://localhost'
  toggleswitch = new foreignParticipants.ToggleSwitch address
  lightbulb = new foreignParticipants.LightBulb address

  before (done) ->
    toggleswitch.start (err) ->
      chai.expect(err).to.not.exist
      lightbulb.start (err) ->
        chai.expect(err).to.not.exist
        return done err

  after (done) ->
    toggleswitch.stop (err) ->
      chai.expect(err).to.not.exist
      lightbulb.stop (err) ->
        chai.expect(err).to.not.exist
        return done err

  it 'should setup OK', (done) ->
    @timeout 2000
    options =
      graphfile: fixturePath 'mqtt-switch.fbp'
      broker: address
      discover: true

    msgflo.setup.bindings options, (err, b) ->
      chai.expect(err).to.not.exist
      done()

    setTimeout () ->
      foreignParticipants.sendDeclarations address, (err) ->
        chai.expect(err).to.not.exist
    , 1000

  it 'switch should be toggling lightbulb on/off', (done) ->
    observer = msgflo.transport.getClient address
    outtopic = '/mylightbulb/ffo/1/is-on'
    handler = (message) =>
      chai.expect(message.data.data).to.be.a 'boolean'
      observer.ackMessage message
      done()

    observer.connect (err) ->
      chai.expect(err).to.not.exist
      observer.subscribeToQueue outtopic, handler, (err) ->
        chai.expect(err).to.not.exist

