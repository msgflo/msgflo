
EventEmitter = require('events').EventEmitter

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
    @emit 'participant-added', definition

  removeParticipant: (id) ->
    definition = @participants[id]
    @emit 'participant-removed', definition

exports.Coordinator = Coordinator
