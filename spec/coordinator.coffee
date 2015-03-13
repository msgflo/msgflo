
chai = require 'chai' unless chai
path = require 'path'

Coordinator = require('../src/coordinator').Coordinator
transport = require '../src/transport'
participants = require './fixtures/participants'

# Note: most require running an external broker service
transports =
  'direct': 'direct://broker1'
  'MQTT': 'mqtt://localhost'
  'AMQP': 'amqp://localhost'

participantLibrary =
  Hello: participants.Hello

describe 'Coordinator', ->

  Object.keys(transports).forEach (type) =>
    address = transports[type]
    coordinator = null
    first = null

    describe ", transport=#{type}: ", () ->

      beforeEach (done) ->
        broker = transport.getBroker address
        coordinator = new Coordinator broker
        coordinator.start (err) ->
          chai.expect(err).to.be.a 'null'
          done()

      afterEach (done) ->
        coordinator.stop () ->
          coordinator = null
          done()

      describe 'creating participant', ->
        it 'should emit participant-added', (done) ->
          first = participants.Hello transport.getClient address
          coordinator.once 'participant-added', (participant) ->
            chai.expect(participant).to.be.a 'object'
            chai.expect(participant.id).to.equal first.definition.id
            done()
          first.start (err) -> chai.expect(err).to.be.a 'null'

      describe 'sending data into participant input queue', ->
        it 'should receive results on output queue', (done) ->
          @timeout 4000
          first = participants.Hello transport.getClient address
          coordinator.once 'participant-added', (participant) ->
            id = first.definition.id
            coordinator.subscribeTo id, 'out', (msg) ->
              chai.expect(msg.data).to.equal 'Hello Jon'
              done()
            coordinator.sendTo id, 'name', 'Jon'
          first.start (err) -> chai.expect(err).to.be.a 'null'

      describe 'sending data to participant connected to another', ->
        it 'should receive results at end of flow', (done) ->
          @timeout 4000
          first = participants.Hello transport.getClient address
          second = participants.Hello transport.getClient address
          participantsNumber = 0
          coordinator.on 'participant-added', (participant) ->
            participantsNumber = participantsNumber+1
            return if participantsNumber != 2
            coordinator.connect first.definition.id, 'out', second.definition.id, 'name'
            coordinator.subscribeTo second.definition.id, 'out', (msg) ->
              chai.expect(msg.data).to.equal 'Hello Hello Johnny'
              done()
            coordinator.sendTo first.definition.id, 'name', 'Johnny'
          first.start (err) -> chai.expect(err).to.be.a 'null'
          second.start (err) -> chai.expect(err).to.be.a 'null'

      describe 'loading graph as json', ->
        it 'should not return error', (done) ->
          coordinator.manager.library = participantLibrary
          coordinator.loadGraphFile 'graphs/hello.json', (err) ->
            chai.expect(err).to.be.a 'null'
            done()

        it 'should set up participants', (done) ->
          participantsNumber = 0
          coordinator.manager.library = participantLibrary
          coordinator.on 'participant-added', (participant) ->
            participantsNumber = participantsNumber+1
            return if participantsNumber != 3
            done()
          coordinator.loadGraphFile 'graphs/hello.json', (err) ->
            chai.expect(err).to.be.a 'null'

        it 'should set up connections', (done) ->
          @timeout 4000
          coordinator.manager.library = participantLibrary
          coordinator.loadGraphFile 'graphs/hello.json', (err) ->
            chai.expect(err).to.be.a 'null'
            coordinator.subscribeTo 'helloC', 'out', (msg) ->
              return if msg.data == 'Hello Hello Hello World' # IIP
              chai.expect(msg.data).to.equal 'Hello Hello Hello JSON'
              done()
            coordinator.sendTo 'helloA', 'name', 'JSON'

