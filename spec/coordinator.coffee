
chai = require 'chai' unless chai
path = require 'path'

Coordinator = require('../src/coordinator').Coordinator
runtime = require '../src/fakeruntime'
transport = require '../src/transport'

address = 'direct://broker1'
address = 'amqp://localhost'

describe 'Coordinator', ->
  coordinator = null
  first = null

  beforeEach (done) ->
    broker = transport.getBroker address
    coordinator = new Coordinator broker
    coordinator.start () ->
      done()

  afterEach (done) ->
    @timeout 200
    coordinator.stop () ->
      coordinator = null
      done()

  describe 'creating participant', ->
    it 'should emit participant-added', (done) ->
      first = runtime.HelloParticipant transport.getClient address
      coordinator.on 'participant-added', (participant) ->
        chai.expect(participant).to.be.a 'object'
        chai.expect(participant.id).to.equal first.definition.id
        done()
      first.start()

  describe 'sending data into participant input queue', ->
    it 'should receive results on output queue', (done) ->
      first = runtime.HelloParticipant transport.getClient address
      coordinator.on 'participant-added', (participant) ->
        id = first.definition.id
        coordinator.subscribeTo id, 'out', (data) ->
          chai.expect(data).to.equal 'Hello Jon'
          done()
        coordinator.sendTo id, 'name', 'Jon'
      first.start()

  describe 'sending data to participant connected to another', ->
    it 'should receive results at end of flow', (done) ->
      first = runtime.HelloParticipant transport.getClient address
      second = runtime.HelloParticipant transport.getClient address
      participants = 0
      coordinator.on 'participant-added', (participant) ->
        participants = participants+1
        return if participants != 2
        coordinator.connect first.definition.id, 'out', second.definition.id, 'name'
        coordinator.subscribeTo second.definition.id, 'out', (data) ->
          chai.expect(data).to.equal 'Hello Hello Johnny'
          done()
        coordinator.sendTo first.definition.id, 'name', 'Johnny'
      first.start()
      second.start()
