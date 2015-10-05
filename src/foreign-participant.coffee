msgflo_nodejs = require 'msgflo-nodejs'

EventEmitter = require('events').EventEmitter

class ForeignParticipant extends EventEmitter
  constructor: (client, def) ->
    client = msgflo_nodejs.transport.getClient(client) if typeof client == 'string'
    @messaging = client

  register: (callback) ->
    @messaging.registerParticipant @definition, (err) ->
      return callback err

exports.ForeignParticipant = ForeignParticipant
exports.register = (client, definition, callback) ->
  participant = new ForeignParticipant client, definition
  participant.register callback
