msgflo_nodejs = require 'msgflo-nodejs'
EventEmitter = require('events').EventEmitter

library = require './library'

class ForeignParticipant extends EventEmitter
  constructor: (client, def) ->
    client = msgflo_nodejs.transport.getClient(client) if typeof client == 'string'
    @messaging = client
    @definition = def

  register: (callback) ->
    @messaging.registerParticipant @definition, (err) ->
      return callback err

exports.ForeignParticipant = ForeignParticipant
exports.register = (client, definition, callback) ->
  participant = new ForeignParticipant client, definition
  participant.register callback

exports.mapPorts = (definition) ->
  inPorts = definition.inports or {}
  definition.inports = Object.keys(inPorts).map (id) ->
    def = inPorts[id]
    def.id = id
    def.queue = library.replaceVariables def.queue, { "ROLE": definition.role }
    return def
  outPorts = definition.outports or {}
  definition.outports = Object.keys(outPorts).map (id) ->
    def = outPorts[id]
    def.id = id
    def.queue = library.replaceVariables def.queue, { "ROLE": definition.role }
    return def
  definition
