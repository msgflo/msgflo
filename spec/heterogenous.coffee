
msgflo = require '../'
common = require '../src/common'

path = require 'path'
chai = require 'chai' unless chai
child_process = require 'child_process'

debug = require('debug')('msgflo:spec:heterogenous')

foreignParticipants =
#  'PythonRepeat': [python, path.join __dirname, 'fixtures', './repeat.py']
#  'CppRepeat': [python, path.join __dirname, 'fixtures', './repeat-cpp']

# TODO: use setup.participant + Library code
startProcess = (args, options, callback) ->
  prog = args[0]
  args = args.slice(1)
  childOptions = {}
  childOptions.env = common.clone process.env
  childOptions.env.MSGFLO_BROKER = options.broker if options.broker
  debug 'starting', prog, args.join(' ')
  child = child_process.spawn prog, args, childOptions
  debug 'started PID', child.pid
  returned = false
  child.on 'error', (err) ->
    debug 'error', err
    return if returned
    returned = true
    return callback err
  # We assume that when somethis is send on stdout, starting is complete
  child.stdout.on 'data', (data) ->
    debug 'stdout', data.toString()
    return if returned
    returned = true
    return callback null
  child.stderr.on 'data', (data) ->
    debug 'stderr', data.toString()
    return if returned
    returned = true
    return callback new Error data.toString()
  return child

startForeign = (commands, name, options, callback) ->
  args = commands[name]
  return startProcess args, options, callback

exports.testParticipant = testParticipant = (state, name, options = {}) ->
  options.timeout = 10*1000 if not options.timeout
  state.repeat = { bar: 'foo' } if typeof state.repeat == 'undefined'

  describe "#{name} participant", ->
    participant = null
    definitions = null
    onParticipantDiscovered = null

    waitDefinition = (waitForComponent, cb) ->
      checkAndCallback = () ->
        console.log 'disc', definitions.length, waitForComponent, definitions
        for def in definitions
          if def.component == waitForComponent
            return cb def
      checkAndCallback()
      onParticipantDiscovered = checkAndCallback

    beforeEach (done) ->
      @timeout options.timeout
      definitions = []

      onDiscovery = (msg) ->
        if msg.data.protocol == 'discovery' and msg.data.command == 'participant'
          def = msg.data.payload
          definitions.push def
          state.broker.ackMessage msg
          if typeof onParticipantDiscovered == 'function'
            onParticipantDiscovered def, definitions
        else
          console.log "WARNING", 'unknown discovery message:', msg.data.protocol, msg.data.command
      state.broker.subscribeParticipantChange onDiscovery

      participant = startForeign state.commands, name, options, done
    afterEach (done) ->
      participant.kill()
      done()

    describe 'when started', ->
      it 'sends definition on fbp queue', (done) ->
        @timeout options.timeout

        waitDefinition name, (def) ->
          chai.expect(def).to.be.an 'object'
          chai.expect(def).to.have.keys ['id', 'icon', 'role', 'component', 'label', 'inports', 'outports']
          done()

    describe 'sending data on inport queue', ->
      @timeout options.timeout
      it 'repeats the same data on outport queue', (done) ->
        broker = state.broker

        onReceive = (msg) ->
          broker.ackMessage msg
          chai.expect(msg.data).to.eql state.repeat
          done()

        # TODO: look up in definition
        waitDefinition name, (def) ->

          inQueue = null
          outQueue = null
          for port in def.inports
            inQueue = port.queue if port.id == 'in'
          for port in def.outports
            outQueue = port.queue if port.id == 'out'

          receiveQueue = 'test.RECEIVE'
          binding = { type: 'pubsub', src: outQueue, tgt: receiveQueue }

          send = () ->
            broker.sendTo 'inqueue', inQueue, state.repeat, (err) ->
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
    commands: foreignParticipants
    repeat: undefined # default

  beforeEach (done) ->
    g.broker = msgflo.transport.getBroker address
    g.broker.connect done
  afterEach (done) ->
    g.broker.disconnect done

  names = Object.keys g.commands
  names.forEach (name) ->
    testParticipant g, name


