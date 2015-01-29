
EventEmitter = require('events').EventEmitter

findPort = (def, type, portName) ->
  ports = if type == 'inport' then def.inports else def.outports
  for port in ports
    return port if port.id == portName
  return null

class Coordinator extends EventEmitter
  constructor: (@broker) ->

    @broker.subscribeToQueue 'fbp', (msg) =>
      @handleFbpMessage msg
    @participants = {}
  
  handleFbpMessage: (msg) ->
    if msg.protocol == 'discovery' and msg.command == 'participant'
      @addParticipant msg.payload
    else
      throw new Error 'Unknown FBP message'

  addParticipant: (definition) ->
    @participants[definition.id] = definition
    @emit 'participant-added', definition

  removeParticipant: (id) ->
    definition = @participants[id]
    @emit 'participant-removed', definition

  sendTo: (participantId, inport, message) ->
    part = @participants[participantId]
    port = findPort part, 'inport', inport
    @broker.sendToQueue port.queue, message, (err) ->

  subscribeTo: (participantId, outport, handler) ->
    part = @participants[participantId]
    port = findPort part, 'outport', outport
#    console.log participantId, @participants, part, port
    @broker.subscribeToQueue port.queue, handler, (err) ->

exports.Coordinator = Coordinator
