
chai = require 'chai' unless chai
path = require 'path'

Coordinator = require('../src/coordinator').Coordinator
runtime = require '../src/fakeruntime'
direct = require '../src/direct'

address = 'broker1'

describe 'Coordinator', ->
  coordinator = null
  first = null

  beforeEach (done) ->
    broker = new direct.MessageBroker address
    coordinator = new Coordinator broker
    done()
  afterEach (done) ->
    @timeout 200
    coordinator = null
    done()

  describe 'participant registration', ->
    it 'should emit participant-added', (done) ->
      client = new direct.Client address
      first = runtime.HelloParticipant client
      coordinator.on 'participant-added', (participant) ->
        chai.expect(participant).to.be.a 'object'
        done()
      first.start()


