
EventEmitter = require('events').EventEmitter
fs = require 'fs'
async = require 'async'

ParticipantManager = require('./manager').ParticipantManager

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


class Coordinator extends EventEmitter
  constructor: (@broker, @initialGraph) ->
    @participants = {}
    @connections = {} # connId -> function
    @iips = {} # iipId -> value
    @started = false
    @manager = null
  
  start: (callback) ->
    @broker.connect (err) =>
      console.log 'coordinator connected', err
      return callback err if err
      @broker.createQueue 'fbp', (err) =>
        console.log 'fbp queue created', err
        return callback err if err
        @broker.subscribeToQueue 'fbp', (msg) =>
          @handleFbpMessage msg
          @broker.ackMessage msg
        , (err) =>
          @started = if err then false else true
          console.log 'coordinator started', err, @started
          return callback err

  stop: (callback) ->
    @started = false
    @broker.disconnect (err) =>
      return callback err if err
      if @manager
        @manager.stop callback
      else
        return callback null


  handleFbpMessage: (msg) ->
    data = msg.data
    if data.protocol == 'discovery' and data.command == 'participant'
      @addParticipant data.payload
    else
      throw new Error 'Unknown FBP message'

  addParticipant: (definition) ->
    console.log 'addParticipant', definition.id
    @participants[definition.id] = definition
    @emit 'participant-added', definition
    console.log 'addParticipant DONE', definition.id

  removeParticipant: (id) ->
    definition = @participants[id]
    @emit 'participant-removed', definition

  sendTo: (participantId, inport, message) ->
    console.log 'cordinator sendTo', participantId, inport, message
    part = @participants[participantId]
    port = findPort part, 'inport', inport
    @broker.sendToQueue port.queue, message, (err) ->
      throw err if err

  subscribeTo: (participantId, outport, handler) ->
    part = @participants[participantId]
    console.log 'cordinator subscribeTo', participantId, outport
    port = findPort part, 'outport', outport
    ackHandler = (msg) =>
      return if not @started
      handler msg
      @broker.ackMessage msg
    @broker.subscribeToQueue port.queue, ackHandler, (err) ->
      throw err if err

  unsubscribeFrom: () -> # FIXME: implement

  connect: (fromId, fromPort, toId, toName) ->
    emitEdgeData = (data) =>
      @emit 'data', fromId, fromPort, toId, toName, data
    handler = (msg) =>
      console.log 'edge message', msg
      @sendTo toId, toName, msg.data
      # NOTE: should respect "edges" message. Requires fixing Flowhub
      emitEdgeData msg.data
    @subscribeTo fromId, fromPort, handler
    id = connId fromId, fromPort, toId, toName
    @connections[id] = handler

  disconnect: (fromId, fromPortId, toId, toPortId) -> # FIXME: implement


  addInitial: (partId, portId, data) ->
    id = iipId partId, portId
    @iips[id] = data
    @sendTo partId, portId, data if @started

  removeInitial: (partId, portId) -> # FIXME: implement
    # Do we need to remove it from the queue??

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
        component: part['class']

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

  loadGraphFile: (path, callback) ->
    fs.readFile path, {encoding:'utf-8'}, (err, contents) =>
      return callback err if err
      try
        graph = JSON.parse contents
      catch e
        return callback e if e
      @loadGraph graph, callback

  loadGraph: (graph, callback) ->
    # TODO: clear existing state?

    # Waiting until all participants have registerd
    waitForParticipant = (processId, callback) =>
      return callback null, @participants[processId] if @participants[processId]

      onTimeout = () =>
        return callback new Error 'Participant discovery timeout'
      timeout = setTimeout onTimeout, 10000

      onParticipantAdded = (part) =>
        if part.id == processId
          console.log 'onParticipant', part.id
          clearTimeout timeout
          @removeListener 'participant-added', onParticipantAdded
          return callback null
      @on 'participant-added', onParticipantAdded

    # Connecting edges
    connectEdge = (edge, callback) =>
      console.log 'CONNECT EDGE', edge
      @connect edge.src.process, edge.src.port, edge.tgt.process, edge.tgt.port
      return callback null

    # Sending IIPs
    sendInitial = (iip, callback) =>
      @addInitial iip.tgt.process, iip.tgt.port, iip.data
      return callback null

    async.map Object.keys(graph.processes), waitForParticipant, (err) =>
      @started = err != null
      console.log 'loaded participants', err
      return callback err if err

      edges = []
      iips = []
      for conn in graph.connections
        target = if conn.src then edges else iips
        target.push conn
      console.log edges

      async.map edges, connectEdge, (err) =>
        console.log 'edges connected', err
        return callback err if err

        async.map iips, sendInitial, (err) =>
          console.log 'IIPs sent'
          @started = (err != null)
          return callback err if err
          return callback null

    # For testing, start participants
    @manager = new ParticipantManager @broker.address, graph
    @manager.start (err) ->
      throw err if err


exports.Coordinator = Coordinator
