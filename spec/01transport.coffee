
chai = require 'chai' unless chai
path = require 'path'
async = require 'async'

Coordinator = require('../src/coordinator').Coordinator
transport = require '../src/transport'
common = require '../src/common'
participants = require './fixtures/participants'

# Note: most require running an external broker service
transports =
  'direct': 'direct://broker2'
  'MQTT': 'mqtt://localhost'
  'AMQP': 'amqp://localhost'

randomString = (n) ->
  text = ""
  possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  for i in [0...n]
    idx = Math.floor Math.random()*possible.length
    text += possible.charAt idx
  return text

zip = () ->
  lengthArray = (arr.length for arr in arguments)
  length = Math.min(lengthArray...)
  for i in [0...length]
    arr[i] for arr in arguments

#
createConnectClients = (address, names, callback) ->
  createConnect = (name, cb) ->
    client = transport.getClient address
    client.connect (err) ->
      cb err, client

  async.map names, createConnect, (err, clients) ->
    return callback err if err
    ret = {}
    for nc in zip names, clients
      ret[nc[0]] = nc[1]
    return callback null, ret

createQueues = (queueMapping, callback) ->
  createQueue = (det, cb) ->
    [client, type, queueName] = det
    client.removeQueue type, queueName, (err) ->
      return cb err if err
      client.createQueue type, queueName, cb

  async.map queueMapping, createQueue, callback

createBindQueues = (broker, queueMapping, callback) ->
  createBindQueue = (det, cb) ->
    [client, type, srcQ, tgtQ] = det
    createQ = if type == 'outqueue' then srcQ else tgtQ
    client.removeQueue type, createQ, (err) ->
      return cb err if err
      client.createQueue type, createQ, (err) ->
        return cb err if err
        broker.addBinding {type:'pubsub', src:srcQ, tgt:tgtQ}, cb

  async.map queueMapping, createBindQueue, callback

sendPackets = (packets, callback) ->
  send = (p, cb) ->
    [client, queue, data] = p
    client.sendToQueue queue, data, cb

  async.map packets, send, callback

subscribeData = (handlers, callback) ->
  sub = (h, cb) ->
    [client, queue, handler] = h
    ackHandler = (msg) ->
      client.ackMessage msg
      return handler msg
    client.subscribeToQueue queue, ackHandler, cb

  async.map handlers, sub, callback

subscribeDataNoAck = (handlers, callback) ->
  sub = (h, cb) ->
    [client, queue, handler] = h
    client.subscribeToQueue queue, handler, cb
  async.map handlers, sub, callback


setupBindings = (broker, bindings, callback) ->
  send = (b, cb) ->
    broker.addBinding b, cb

  async.map bindings, send, callback
# End utils


# Tests
transportTests = (type) ->
  address = transports[type]
  broker = null

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

  describe 'inqueue==outqueue without binding', ->
    it 'sending should be received on other end', (done) ->
      payload = { foo: 'bar91' }
      sharedQueue = 'myqueue33'
      onReceive = (msg) ->
        chai.expect(msg).to.include.keys 'data'
        chai.expect(msg.data).to.eql payload
        done()
      createConnectClients address, ['sender', 'receiver'], (err, clients) ->
        createQueues [
          [ clients.receiver, 'inqueue', sharedQueue ]
          [ clients.sender, 'outqueue', sharedQueue ]
        ], (err) ->
          chai.expect(err).to.not.exist

          clients.receiver.subscribeToQueue sharedQueue, onReceive, (err) ->
            chai.expect(err).to.be.a 'null'
          clients.sender.sendToQueue sharedQueue, payload, (err) ->
            chai.expect(err).to.be.a 'null'


  describe 'inqueue==outqueue with binding', ->
    it 'sending should be received on other end', (done) ->
      payload = { foo: 'bar92' }
      sharedQueue = 'myqueue35'
      onReceive = (msg) ->
        chai.expect(msg).to.include.keys 'data'
        chai.expect(msg.data).to.eql payload
        done()
      createConnectClients address, ['sender', 'receiver'], (err, clients) ->
        createQueues [
          [ clients.receiver, 'inqueue', sharedQueue ]
          [ clients.sender, 'outqueue', sharedQueue ]
        ], (err) ->
          chai.expect(err).to.not.exist

          broker.addBinding {type:'pubsub', src:sharedQueue, tgt:sharedQueue}, (err) ->
            chai.expect(err).to.be.a 'null'

            clients.receiver.subscribeToQueue sharedQueue, onReceive, (err) ->
              chai.expect(err).to.be.a 'null'
            clients.sender.sendToQueue sharedQueue, payload, (err) ->
              chai.expect(err).to.be.a 'null'


  describe 'outqueue bound to inqueue', ->
    it 'sending to inqueue, show up on outqueue', (done) ->
      payload = { foo: 'bar99' }
      inQueue = 'inqueue232'
      outQueue = 'outqueue353'
      createConnectClients address, ['sender', 'receiver'], (err, clients) ->
        createQueues [
          [ clients.receiver, 'inqueue', inQueue ]
          [ clients.sender, 'outqueue', outQueue ]
        ], (err) ->
          chai.expect(err).to.not.exist

          onReceive = (msg) ->
            clients.receiver.ackMessage msg
            chai.expect(msg).to.include.keys 'data'
            chai.expect(msg.data).to.eql payload
            done()

          broker.addBinding {type:'pubsub', src:outQueue, tgt:inQueue}, (err) ->
            chai.expect(err).to.be.a 'null'

            clients.receiver.subscribeToQueue inQueue, onReceive, (err) ->
              chai.expect(err).to.be.a 'null'
            clients.sender.sendToQueue outQueue, payload, (err) ->
              chai.expect(err).to.be.a 'null'


  describe 'multiple outqueues bound to one inqueue', ->
    it 'all sent on outqueues shows up on inqueue', (done) ->
      @timeout 3000
      senders = [ 'sendA', 'sendB', 'sendC' ]
      clientNames = ['receive']
      clientNames.push.apply clientNames, senders
      createConnectClients address, clientNames, (err, clients) ->
        chai.expect(err).to.be.a 'null'

        expect = [ {name:'sendA'}, {name:'sendB'}, {name:'sendC'} ]

        received = []
        onReceive = (msg) ->
          clients.receive.ackMessage msg
          chai.expect(msg).to.include.keys 'data'
          received.push msg.data
          if received.length == expect.length
            received.sort (a,b) ->
              return -1 if a.name < b.name
              return 1 if a.name > b.name
              return 0
            chai.expect(received).to.eql expect
            done()

        inQueue = 'inqueue27'

        createQueues [ [ clients.receive, 'inqueue', inQueue] ], (err) ->
          chai.expect(err).to.not.exist
          clients.receive.subscribeToQueue inQueue, onReceive, (err) ->
            chai.expect(err).to.not.exist

            # Bind all outqueues to same inqueue
            queueMapping = []
            for name in senders
              queueMapping.push [ clients[name], 'outqueue', name, inQueue ]
            createBindQueues broker, queueMapping, (err) ->
              chai.expect(err).to.not.exist

              packets = []
              for name in senders
                packets.push [ clients[name], name, { name: name } ]
              sendPackets packets, (err) ->
                chai.expect(err).to.not.exist


  describe 'multiple inqueues bound to one outqueue', ->
    it 'data sent on outqueue shows up on all inqueues', (done) ->
      @timeout 3000
      senders = [ 'sender' ]
      receivers = ['r1', 'r2', 'r3']
      clientNames = common.clone receivers
      clientNames.push.apply clientNames, senders
      createConnectClients address, clientNames, (err, clients) ->
        chai.expect(err).to.not.exist

        expect = [ {q:'r1',d:'ident'}, {q:'r2',d:'ident'}, {q:'r3',d:'ident'} ]

        received = []
        checkExpected = (q, msg) ->
          received.push { q: q, d: msg.data.data }
          if received.length == expect.length
            received.sort (a,b) ->
              return -1 if a.q < b.q
              return 1 if a.q > b.q
              return 0
            chai.expect(received).to.eql expect
            done()

        onReceives =
          r1: (msg) -> checkExpected 'r1', msg
          r2: (msg) -> checkExpected 'r2', msg
          r3: (msg) -> checkExpected 'r3', msg

        outQueue2 = 'outqueue39'
        createQueues [ [clients.sender, 'outqueue', outQueue2] ], (err) ->
          chai.expect(err).to.not.exist

          # Bind same outqueue to all inqueues
          queueMapping = []
          for name in receivers
            queueMapping.push [ clients[name], 'inqueue', outQueue2, name ]
          createBindQueues broker, queueMapping, (err) ->
            chai.expect(err).to.not.exist

            handlers = []
            for name in receivers
              handlers.push [ clients[name], name, onReceives[name] ]
            subscribeData handlers, (err) ->
              chai.expect(err).to.not.exist
              clients.sender.sendToQueue outQueue2, {data: 'ident'}, (err) ->
                chai.expect(err).to.not.exist

  describe 'Roundrobin binding', ->
    describe 'sending ACKed message, then NACKed message', ->
      received = null
      beforeEach (done) ->
        received = { worker1: [], worker2: [], deadletter: [] }
        r = randomString '3'
        outq =
          sender: 'outQ-'+r
        inq =
          worker1: 'workerQ-'+r
          worker2: 'workerQ-'+r
          deadletter: 'deadletterQ-'+r
        clientNames = Object.keys inq
        clientNames = clientNames.concat Object.keys(outq)
        createConnectClients address, clientNames, (err, clients) ->
          chai.expect(err).to.not.exist

          queues = []
          for clientName, queueName of outq
            queues.push [ clients[clientName], 'outqueue', queueName ]
          for clientName, queueName of inq
            queues.push [ clients[clientName], 'inqueue', queueName ]

          createQueues queues, (err) ->
            chai.expect(err).to.not.exist

            bindings = [
              { type: 'roundrobin', src: outq.sender, tgt: inq.worker1, deadletter: inq.deadletter }
            ]
            setupBindings broker, bindings, (err) ->
              chai.expect(err).to.not.exist

              # Setup queue subscribers
              ackFunc = (data) ->
                return 'nackMessage' if data.foo == 'nack'
                return 'ackMessage'
              onReceives =
                worker1: (msg) ->
                  console.log 'worker1 got', msg.data
                  received.worker1.push msg.data
                  clients.worker1[ackFunc(msg.data)] msg, () ->
                worker2: (msg) ->
                  console.log 'worker2 got', msg.data
                  received.worker2.push msg.data
                  clients.worker2[ackFunc(msg.data)] msg, () ->
                deadletter: (msg) ->
                  console.log 'deadletter got', msg.data
                  received.deadletter.push msg.data
                  clients.deadletter.ackMessage msg, () ->
                  done()
              handlers = []
              for name in Object.keys inq
                handlers.push [ clients[name], inq[name], onReceives[name] ]
              subscribeDataNoAck handlers, (err) ->
                chai.expect(err).to.not.exist

                packets = [
                  [ clients.sender, outq.sender, {foo: 'ack'} ]
                  [ clients.sender, outq.sender, {foo: 'nack'} ]
                ]
                sendPackets packets, (err) ->
                  chai.expect(err).to.not.exist

      it 'each message is only sent to one worker', () ->
        workerData = received.worker1.concat received.worker2
        chai.expect(workerData).to.have.length 2
      it 'only NACKed message is sent to deadletter', ->
        chai.expect(received.deadletter).to.eql [ { foo: 'nack'} ]

describe 'Transport', ->
  Object.keys(transports).forEach (type) =>
    describe "#{type}", () ->
      transportTests type

