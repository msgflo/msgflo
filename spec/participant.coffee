
msgflo = require '../'
participants = require './fixtures/participants'

chai = require 'chai' unless chai

describe 'Participant', ->
  address = 'direct://broker3'
  broker = null

  before (done) ->
    broker = msgflo.transport.getBroker address
    return broker.connect done
  after (done) ->
    return broker.disconnect done

  describe 'Source participant', ->
    source = null
    beforeEach () ->
      source = participants.FooSource address, 'foo'

    it 'has inports without queues', ->
      ports = source.definition.inports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'interval'
      chai.expect(ports[0].queue).to.be.a 'undefined'
    it 'has outports with queues', ->
      ports = source.definition.outports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'out'
      chai.expect(ports[0].queue).to.be.a 'string'
      chai.expect(ports[0].queue).to.contain 'foo'
      chai.expect(ports[0].queue).to.contain 'OUT'
    describe 'running data', ->
      messages = []
      beforeEach (done) ->
        source.start done
      afterEach (done) ->
        source.stop done

      it 'does nothing when just started'

      it 'produces data when sending interval=100', (done) ->
        onOutput = (msg) ->
          messages.push msg
          done() if messages.length == 3
        observer = msgflo.transport.getClient address
        observer.connect (err) ->
          chai.expect(err).to.be.a 'null'
          port = source.definition.outports[0] # out
          observer.subscribeToQueue port.queue, onOutput, (err) ->
            chai.expect(err).to.be.a 'null'
          source.send 'interval', 100
      it 'stops producing when sending interval=0'


  describe 'Transform participant', ->
    source = null
    beforeEach () ->
      source = participants.Hello address, 'hello'
    it 'has inports with queues', ->
      ports = source.definition.inports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'name'
      chai.expect(ports[0].queue).to.be.a 'string'
      chai.expect(ports[0].queue).to.contain 'NAME'
      chai.expect(ports[0].queue).to.contain 'hello'
    it 'has outports with queues', ->
      ports = source.definition.outports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'out'
      chai.expect(ports[0].queue).to.be.a 'string'
      chai.expect(ports[0].queue).to.contain 'OUT'
      chai.expect(ports[0].queue).to.contain 'hello'
    describe 'sending data on input queue', ->
      it 'produces data on output queue'


  describe 'Sink participant', ->
    sink = null
    beforeEach (done) ->
      sink = participants.DevNullSink address, 'devnull'
      sink.start done
    afterEach (done) ->
      sink.stop done

    it 'has inports with queues', ->
      ports = sink.definition.inports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'drop'
      chai.expect(ports[0].queue).to.be.a 'string'
      chai.expect(ports[0].queue).to.contain 'DROP'
      chai.expect(ports[0].queue).to.contain 'devnull'
    it 'has outports without queues', ->
      ports = sink.definition.outports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'dropped'
      chai.expect(ports[0].queue).to.be.a 'undefined'
    describe 'sending data on input queue', ->
      it 'produces data on output port', (done) ->
        sink.on 'data', (outport, data) ->
          chai.expect(outport).to.equal 'dropped'
          chai.expect(data).to.equal 'myinput32'
          done()
        sink.send 'drop', "myinput32", () ->

