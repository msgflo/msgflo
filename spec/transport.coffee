
chai = require 'chai' unless chai
path = require 'path'
async = require 'async'

Coordinator = require('../src/coordinator').Coordinator
transport = require '../src/transport'
participants = require './fixtures/participants'

# Note: most require running an external broker service
transports =
  'direct': 'direct://broker2'
  'MQTT': 'mqtt://localhost'
  'AMQP': 'amqp://localhost'


connectAll = (clients, callback) ->
  connect = (c, cb) ->
    c.connect cb
  async.map clients, connect, callback


describe 'Transport', ->

  Object.keys(transports).forEach (type) =>
    address = transports[type]
    broker = null

    describe "#{type}", () ->

      beforeEach (done) ->
        broker = transport.getBroker address
        broker.connect (err) ->
          err = null if not err?
          chai.expect(err).to.be.a 'null'
          done()

      afterEach (done) ->
        broker.disconnect () ->
          broker = null
          done()

      describe 'starting client', ->
        it 'should not error', (done) ->
          clientA = transport.getClient address
          clientA.connect (err) ->
            done err

      describe 'subscribing to queue', ->
        it 'should produce data when sending there', (done) ->
          sender = transport.getClient address
          receiver = transport.getClient address
          payload = { foo: 'bar91' }
          sharedQueue = 'myqueue33'
          onReceive = (msg) ->
            chai.expect(msg).to.include.keys 'data'
            chai.expect(msg.data).to.eql payload
            done()
          connectAll [sender, receiver], (err) ->
            receiver.createQueue 'inqueue', sharedQueue, (err) ->
              chai.expect(err).to.be.a 'null'
              receiver.subscribeToQueue sharedQueue, onReceive, (err) ->
                chai.expect(err).to.be.a 'null'
              sender.sendToQueue sharedQueue, payload, (err) ->
                chai.expect(err).to.be.a 'null'



