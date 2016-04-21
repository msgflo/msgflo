
chai = require 'chai' unless chai
path = require 'path'

Coordinator = require('../src/coordinator').Coordinator
transport = require('msgflo-nodejs').transport
participants = require './fixtures/participants'

# Note: most require running an external broker service
transports =
  'direct': 'direct://broker1'
  'MQTT': 'mqtt://localhost'
  'AMQP': 'amqp://localhost'

describe 'Coordinator', ->

  Object.keys(transports).forEach (type) =>
    address = transports[type]
    coordinator = null
    first = null

    describe "#{type} transport", () ->

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
          first = participants.Hello address, 'hello-first'
          coordinator.once 'participant-added', (participant) ->
            chai.expect(participant).to.be.a 'object'
            chai.expect(participant.id).to.equal first.definition.id
            done()
          first.start (err) -> chai.expect(err).to.be.a 'null'

