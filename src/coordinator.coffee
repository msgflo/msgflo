
debug = require('debug')('msgflo:coordinator')
EventEmitter = require('events').EventEmitter
fs = require 'fs'
path = require 'path'
async = require 'async'

setup = require './setup'
library = require './library'

findPort = (def, type, portName) ->
  ports = if type == 'inport' then def.inports else def.outports
  for port in ports
    return port if port.id == portName
  return null

connId = (fromId, fromPort, toId, toPort) ->
  return "#{fromId} #{fromPort} -> #{toPort} #{toId}"
fromConnId = (id) ->
  t = id.split ' '
  return [ t[0], t[1], t[4], t[3] ]
iipId = (part, port) ->
  return "#{part} #{port}"
fromIipId = (id) ->
  return id.split ' '


waitForParticipant = (coordinator, role, callback) ->
  existing = coordinator.participantsByRole role
  return callback null, coordinator.participants[existing[0]] if existing.length

  onTimeout = () =>
    return callback new Error "Waiting for participant #{role} timed out"
  timeout = setTimeout onTimeout, 10000

  onParticipantAdded = (part) =>
    if part.role == role
      debug 'onParticipantAdded', part.role # FIXME: take into account multiple participants with same role
      clearTimeout timeout
      coordinator.removeListener 'participant-added', onParticipantAdded
      return callback null
  coordinator.on 'participant-added', onParticipantAdded


class Coordinator extends EventEmitter
  constructor: (@broker, @options = {}) ->
    @participants = {}
    @connections = {} # connId -> { queue: opt String, handler: opt function }
    @iips = {} # iipId -> value
    @started = false
    @processes = {}
    @library = new library.Library { configfile: @options.library, componentdir: @options.componentdir }
    @exported =
      inports: {}
      outports: {}

    @on 'participant', @checkParticipantConnections

  start: (callback) ->
    @broker.connect (err) =>
      debug 'connected', err
      return callback err if err
      @broker.subscribeParticipantChange (msg) =>
        @handleFbpMessage msg.data
        @broker.ackMessage msg
      @started = true
      debug 'started', err, @started
      return callback null

  stop: (callback) ->
    @started = false
    @broker.disconnect (err) =>
      return callback err if err
      setup.killProcesses @processes, 'SIGTERM', callback

  handleFbpMessage: (data) ->
    if data.protocol == 'discovery' and data.command == 'participant'
      @addParticipant data.payload
    else
      throw new Error 'Unknown FBP message'

  addParticipant: (definition) ->
    debug 'addParticipant', definition.id
    @participants[definition.id] = definition
    @emit 'participant-added', definition
    @emit 'participant', 'added', definition

  removeParticipant: (id) ->
    definition = @participants[id]
    @emit 'participant-removed', definition
    @emit 'participant', 'removed', definition

  addComponent: (name, language, code, callback) ->
    @library.addComponent name, language, code, callback

  startParticipant: (node, component, callback) ->
    iips = {}
    cmd = @library.componentCommand component, node, iips
    commands = {}
    commands[node] = cmd
    options =
      broker: @options.broker
      forward: '' # whether to forward subprocess communication
    setup.startProcesses commands, options, (err, processes) =>
      return callback err if err
      for k, v of processes
        @processes[k] = v
      waitForParticipant @, node, (err) ->
        return callback err, processes

  stopParticipant: (node, component, callback) ->
    processes = {}
    for k, v of @processes
      if k == node
        processes[k] = v
    setup.killProcesses processes, 'SIGTERM', (err) ->
      return callback err
      for k, v of processes
        delete @process[k]
      return callback null, processes

  sendTo: (participantId, inport, message, callback) ->
    debug 'sendTo', participantId, inport, message
    defaultCallback = (err) ->
      throw err if err
    callback = defaultCallback if not callback

    part = @participants[participantId]
    part = @participants[@participantsByRole(participantId)] if not part?
    port = findPort part, 'inport', inport
    return @broker.sendTo 'inqueue', port.queue, message, callback

  subscribeTo: (participantId, outport, handler, callback) ->
    defaultCallback = (err) ->
      throw err if err
    callback = defaultCallback if not callback

    part = @participants[participantId]
    part = @participants[@participantsByRole(participantId)] if not part?

    debug 'subscribeTo', participantId, outport
    port = findPort part, 'outport', outport
    ackHandler = (msg) =>
      return if not @started
      handler msg
      @broker.ackMessage msg

    # Cannot subscribe directly to an outqueue, must create and bind an inqueue
    readQueue = 'msgflo-export-' + Math.floor(Math.random()*999999)
    @broker.createQueue 'inqueue', readQueue, (err) =>
      return callback err if err
      @broker.addBinding {type: 'pubsub', src: port.queue, tgt: readQueue}, (err) =>
        return callback err if err
        @broker.subscribeToQueue readQueue, ackHandler, (err) ->
          return callback err, readQueue # caller should teardown readQueue

  unsubscribeFrom: () -> # FIXME: implement

  connect: (fromId, fromPort, toId, toName, callback) ->
    callback = ((err) ->) if not callback
 
    # XXX: there is now a mixture of participant id and role used here

    findQueue = (partId, dir, portName) =>
      part = @participants[partId]
      part = @participants[@participantsByRole(partId)] if not part?
      for port in part[dir]
        return port.queue if port.id == portName

    # NOTE: adding partial connection info to make checkParticipantConnections logic work
    edgeId = connId fromId, fromPort, toId, toName
    edge =
      fromId: fromId
      fromPort: fromPort
      toId: toId
      toName: toName
      srcQueue: null
      tgtQueue: null
    @connections[edgeId] = edge

    # might be that it was just added/started, not yet discovered
    waitForParticipant @, fromId, (err) =>
      return callback err if err
      waitForParticipant @, toId, (err) =>
        return callback err if err
        # TODO: support roundtrip
        @connections[edgeId].srcQueue = findQueue fromId, 'outports', fromPort
        @connections[edgeId].tgtQueue = findQueue toId, 'inports', toName
        @broker.addBinding {type: 'pubsub', src:edge.srcQueue, tgt:edge.tgtQueue}, (err) =>
          return callback err

    # TODO: introduce some "spying functionality" to provide edge messages, add tests

  disconnect: (fromId, fromPortId, toId, toPortId) -> # FIXME: implement


  checkParticipantConnections: (action, participant) ->
    findConnectedPorts = (dir, srcPort) =>
      conn = []
      # return conn if not srcPort.queue
      for id, part of @participants
        for port in part[dir]
          continue if not port.queue
          conn.push { part: part, port: port } if port.queue == srcPort.queue
      return conn

    isConnected = (e) =>
      [fromId, fromPort, toId, toPort] = e
      id = connId fromId, fromPort, toId, toPort
      return @connections[id]?

    if action == 'added'
      id = participant.id
      # inbound
      for port in participant.inports
        matches = findConnectedPorts 'outports', port
        for m in matches
          e = [m.part.id, m.port.id, id, port.id]
          @connect e[0], e[1], e[2], e[3] if not isConnected e

      # outbound
      for port in participant.outports
        matches = findConnectedPorts 'inports', port
        for m in matches
          e = [id, port.id, m.part.id, m.port.id]
          @connect e[0], e[1], e[2], e[3] if not isConnected e

    else if action == 'removed'
      null # TODO: implement

    else
      null # ignored

  addInitial: (partId, portId, data) ->
    id = iipId partId, portId
    @iips[id] = data
    @sendTo partId, portId, data if @started

  removeInitial: (partId, portId) -> # FIXME: implement
    # Do we need to remove it from the queue??

  exportPort: (direction, external, node, internal, callback) ->
    target = if direction.indexOf("in") == 0 then @exported.inports else @exported.outports
    target[external] =
      role: node
      port: internal
      subscriber: null
      queue: null
    graph = null # FIXME: capture
    # Wait for target node to exist
    waitForParticipant @, node, (err) =>
      return callback err if err

      if direction.indexOf('out') == 0
        handler = (msg) =>
          @emit 'exported-port-data', external, msg.data, graph
        @subscribeTo node, internal, handler, (err, readQueue) ->
          return callback err if err
          target[external].subscriber = handler
          target[external].queue = readQueue
          return callback null
      else
        return callback null

  unexportPort: () -> # FIXME: implement

  sendToExportedPort: (port, data, callback) ->
    # FIXME lookup which node, port this corresponds to
    internal = @exported.inports[port]
    debug 'sendToExportedPort', port, internal
    return callback new Error "Cannot find exported port #{port}" if not internal
    @sendTo internal.role, internal.port, data, callback

  startNetwork: (networkId, callback) ->
    # Don't have a concept of started/stopped so far, no-op
    setTimeout callback, 10

  stopNetwork: (networkId, callback) ->
    # Don't have a concept of started/stopped so far, no-op
    setTimeout callback, 10
  
  serializeGraph: (name) ->
    graph =
      properties:
        name: name
      processes: {}
      connections: []
      inports: []
      outports: []

    for id, part of @participants
      graph.processes[id] =
        component: part.component

    for id, conn of @connections
      parts = fromConnId id
      edge =
        src:
          process: parts[0]
          port: parts[1]
        tgt:
          process: parts[2]
          port: parts[3]
      graph.connections.push edge

    return graph

  loadGraphFile: (path, opts, callback) ->
    options =
      graphfile: path
      libraryfile: @library.configfile
    for k, v of opts
      options[k] = v
    setup.participants options, (err, proc) =>
      return callback err if err
      @processes = proc
      setup.bindings options, callback

  participantsByRole: (role) ->
    matchRole = (id) =>
      part = @participants[id]
      return part.role == role

    m = Object.keys(@participants).filter matchRole
    return m


exports.Coordinator = Coordinator
