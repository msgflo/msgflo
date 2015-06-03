
msgflo = require '../'

path = require 'path'
chai = require 'chai' unless chai
child_process = require 'child_process'

python = process.env.PYTHON or 'python'
foreignParticipants =
  'PythonRepeat': [python, path.join __dirname, 'fixtures', './repeat.py']
#  'CppRepeat': [python, path.join __dirname, 'fixtures', './repeat-cpp']

startProcess = (args, callback) ->
  prog = args[0]
  args = args.slice(1)
#  console.log 'start', prog, args.join(' ')
  child = child_process.spawn prog, args
  returned = false
  child.on 'error', (err) ->
#    console.log 'error', err
    return if returned
    returned = true
    return callback err
  # We assume that when somethis is send on stdout, starting is complete
  child.stdout.on 'data', (data) ->
#    console.log 'stdout', data.toString()
    return if returned
    returned = true
    return callback null
  child.stderr.on 'data', (data) ->
#    console.log 'stderr', data.toString()
    return if returned
    returned = true
    return callback new Error data.toString()
  return child

startForeign = (name, callback) ->
  args = foreignParticipants[name]
  return startProcess args, callback

testParticipant = (state, name) ->

  describe "#{name} participant", ->
    participant = null
    beforeEach (done) ->
      @timeout 4000
      participant = startForeign name, done
    afterEach (done) ->
      participant.kill()
      done()

    describe 'when started', ->
      it 'sends definition on fbp queue', (done) ->
        broker = state.broker

        onDiscovery = (msg) ->
          def = msg.data
          chai.expect(def).to.be.an 'object'
          chai.expect(def).to.have.keys ['id', 'icon', 'component', 'label', 'inports', 'outports']
          state.broker.ackMessage msg
          return if def.component != name
          done()
        state.broker.subscribeParticipantChange onDiscovery

    describe 'sending data on inport queue', ->
      it 'repeats the same data on outport queue', (done) ->
        broker = state.broker

        input = { bar: 'foo' }
        onReceive = (msg) ->
          broker.ackMessage msg
          chai.expect(msg.data).to.eql input
          done()

        # TODO: look up in definition
        receiveQueue = 'test.RECEIVE'
        inQueue = 'repeat.IN'
        outQueue = 'repeat.OUT'
        binding = { type: 'pubsub', src: outQueue, tgt: receiveQueue }

        send = () ->
          broker.sendTo 'inqueue', inQueue, input, (err) ->
            chai.expect(err).to.not.exist

        broker.createQueue 'inqueue', receiveQueue, (err) ->
          chai.expect(err).to.not.exist
          broker.addBinding binding, (err) ->
            chai.expect(err).to.not.exist
            broker.subscribeToQueue receiveQueue, onReceive, (err) ->
              chai.expect(err).to.not.exist
              setTimeout send, 1000 # HACK: wait for inqueue to be setup



describe 'Heterogenous', ->
  address = 'amqp://localhost'
  g =
    broker: null

  beforeEach (done) ->
    g.broker = msgflo.transport.getBroker address
    g.broker.connect done
  afterEach (done) ->
    g.broker.disconnect done

  names = Object.keys foreignParticipants
  names.forEach (name) ->
    testParticipant g, name


