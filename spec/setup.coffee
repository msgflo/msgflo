
msgflo = require '../'
setup = msgflo.setup

chai = require 'chai' unless chai
path = require 'path'

fixtureGraph = (name, callback) ->
  p = path.join __dirname, 'fixtures', name
  msgflo.common.readGraph p, callback

linesContaining = (lines, str) =>
  lines = lines.split '\n'
  containing = lines.filter (s) -> s.indexOf(str) != -1

describe 'Setup bindings', ->
  address = 'direct://broker4'
  bindings = null
  graph = null
  beforeEach (done) ->
    fixtureGraph 'imgflo-server.fbp', (err, gr) ->
      graph = gr
      chai.expect(err).to.not.exist
      bindings = setup.graphBindings graph
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
      pretty = setup.prettyFormatBindings bindings
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
