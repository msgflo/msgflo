
chai = require 'chai' unless chai
path = require 'path'

Coordinator = require('../src/coordinator').Coordinator
transport = require('msgflo-nodejs').transport
participants = require './fixtures/participants'
common = require '../src/common'

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
    client = transport.getClient address

    describe "#{type} transport", () ->

      before (done) ->
        broker = transport.getBroker address
        coordinator = new Coordinator broker
        coordinator.start (err) ->
          chai.expect(err).to.be.a 'null'
          return client.connect done

      after (done) ->
        coordinator.stop () ->
          coordinator = null
          return client.disconnect done

      describe 'creating participant', ->
        it 'should emit participant-added', (done) ->
          first = participants.Hello address, 'hello-first'
          coordinator.once 'participant-added', (participant) ->
            chai.expect(participant).to.be.a 'object'
            chai.expect(participant.id).to.equal first.definition.id
            done()
          first.start (err) -> chai.expect(err).to.be.a 'null'

      describe 'receiving same discovery message multiple times', ->
        added = []
        updated = []
        libraryChanged = []
        definition =
          id: 'multiple-discovery-11'
          role: 'multiple-discovery'
          component: 'MultipleDiscovery'
          inports: []
          outports: []
        eventListener = null
        libraryListener = null

        before (done) ->
          eventListener = (event, def) ->
            if event == 'added'
              added.push common.clone(def)
            else if event == 'updated'
              updated.push common.clone(def)
              return done()
            else
              return done new Error "Unexpected event #{event}"
          coordinator.on 'participant', eventListener
          libraryListener = (names) ->
            libraryChanged.push names
          coordinator.library.on 'components-changed', libraryListener

          # send two times
          client.registerParticipant definition, (err) ->
            return done err if err
            setTimeout () ->
              client.registerParticipant definition, (err) ->
                return done err if err
            , 20 # ensure there is time difference

        after (done) ->
          coordinator.removeListener 'participant', eventListener
          coordinator.library.removeListener 'components-changed', libraryListener
          return done null

        it 'should emit participant-added only once', () ->
          chai.expect(added).to.have.length 1
          d = added[0]
          chai.expect(d.id).to.equal definition.id
          chai.expect(d.extra.lastSeen).to.be.a 'date'
          chai.expect(d.extra.firstSeen).to.be.a 'date'
        it 'should update last seen time', () ->
          chai.expect(updated).to.have.length 1
          d = updated[0]
          chai.expect(d.id).to.equal definition.id
          diff = d.extra.lastSeen.getTime() - added[0].extra.lastSeen.getTime()
          chai.expect(diff, 'time difference').to.be.above 0
        it 'should emit library components-changed only once', ->
          chai.expect(libraryChanged).to.eql [
            ['MultipleDiscovery']
          ]

      describe.skip 'discovery for multiple participants with same role', ->
        # it 'should not be a new FBP node' # XXX: should be tested in ./protocol.coffee instead?

      describe 'discovery message changes component data', ->
        added = []
        updated = []
        libraryChanged = []
        definition =
          id: 'multiple-discovery-11'
          role: 'multiple-discovery'
          component: 'MultipleDiscovery'
          inports: [
            id: 'in'
            type: 'string'
            queue: 'foo'
          ]
          outports: []
        eventListener = null
        libraryListener = null
        before (done) ->
          eventListener = (event, def) ->
            if event == 'added'
              added.push common.clone(def)
            else if event == 'updated'
              updated.push common.clone(def)
              return done()
            else
              return done new Error "Unexpected event #{event}"
          coordinator.on 'participant', eventListener
          libraryListener = (names) ->
            libraryChanged.push names
          coordinator.library.on 'components-changed', libraryListener

          # send new definition
          client.registerParticipant definition, (err) ->
            done err if err

        after (done) ->
          coordinator.removeListener 'participant', eventListener
          coordinator.library.removeListener 'components-changed', libraryListener
          return done null
        it 'should send component-changed', ->
          chai.expect(updated).to.have.length 1
          d = updated[0]
          chai.expect(d.id).to.equal definition.id
        it 'should not send new participant', ->
          chai.expect(added).to.have.length 0
        it 'should emit library components-changed', ->
          chai.expect(libraryChanged).to.eql [
            ['MultipleDiscovery']
          ]
      describe 'receiving discovery message for pending connection', ->
        it 'should setup the connection'

  describe.skip 'setting up graph with mix of local and remote roles', ->
