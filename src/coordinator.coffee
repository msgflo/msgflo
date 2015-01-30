
EventEmitter = require('events').EventEmitter

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

class Coordinator extends EventEmitter
  constructor: (@broker) ->
    @participants = {}
    @connections = {}
  
  start: (callback) ->
    @broker.connect (err) =>
      console.log 'coordinator connected', err
      return callback err if err
      @broker.createQueue 'fbp', (err) =>
        console.log 'fbp queue created', err
        return callback err if err
        @broker.subscribeToQueue 'fbp', (msg) =>
          @handleFbpMessage msg
        , (err) ->
          console.log 'coordinator started', err
          return callback null

  stop: (callback) ->
    @broker.disconnect callback

  handleFbpMessage: (msg) ->
    if msg.protocol == 'discovery' and msg.command == 'participant'
      @addParticipant msg.payload
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
    console.log 'cordinator sendTo', participantId, inport
    part = @participants[participantId]
    port = findPort part, 'inport', inport
    @broker.sendToQueue port.queue, message, (err) ->

  subscribeTo: (participantId, outport, handler) ->
    part = @participants[participantId]
    console.log 'cordinator subscribeTo', participantId, outport
    port = findPort part, 'outport', outport
    @broker.subscribeToQueue port.queue, handler, (err) ->

  unsubscribeFrom: () -> # FIXME: implement

  connect: (fromId, fromPort, toId, toName) ->
    handler = (msg) =>
      @sendTo toId, toName, msg
    @subscribeTo fromId, fromPort, handler
    id = connId fromId, fromPort, toId, toName
    @connections[id] = handler

  disconnect: (fromId, fromPortId, toId, toPortId) -> # FIXME: implement


  serializeGraph: (name) ->
    graph =
      properties:
        name: name
      processes: []
      connections: []
      inports: []
      outports: []

    for id, part in @participants
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

exports.Coordinator = Coordinator
