
msgflo = require '../'
participants = require './fixtures/participants'

chai = require 'chai' unless chai

describe 'Participant', ->

  describe 'Source participant', ->
    source = null
    beforeEach () ->
      address = 'direct://broker1'
      source = participants.FooSource msgflo.transport.getBroker address

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
      chai.expect(ports[0].queue).to.contain 'foosource'
      chai.expect(ports[0].queue).to.contain 'outputq'
    describe 'sending data on inport', ->
      it 'produces data on output queue'


  describe 'Transform participant', ->
    source = null
    beforeEach () ->
      address = 'direct://broker1'
      source = participants.Hello msgflo.transport.getBroker address
    it 'has inports with queues', ->
      ports = source.definition.inports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'name'
      chai.expect(ports[0].queue).to.be.a 'string'
      chai.expect(ports[0].queue).to.contain 'hello'
      chai.expect(ports[0].queue).to.contain 'inputq'
    it 'has outports with queues', ->
      ports = source.definition.outports
      chai.expect(ports).to.have.length 1
      chai.expect(ports[0].id).to.equal 'out'
      chai.expect(ports[0].queue).to.be.a 'string'
      chai.expect(ports[0].queue).to.contain 'hello'
      chai.expect(ports[0].queue).to.contain 'outputq'
    describe 'sending data on input queue', ->
      it 'produces data on output queue'

