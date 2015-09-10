
debug = require('debug')('msgflo:manager')
async = require 'async'

# FIXME: replace completely with setup.participant code

common = require './common'
participant = require('msgflo-nodejs').participant
transport = require('msgflo-nodejs').transport

startProcesses = (library, address, runtime, processes, callback) ->
  # Loading participants, mostly for testing
  # one type could allow definiton a component library (in JSON),
  # where each component has a command for starting an executable
  # taking the broker address and participant identifier

  start = (processId, cb) =>
    component = processes[processId].component
    client = transport.getClient address
    participant.startParticipant library, client, component, processId, (err, part) ->
      return cb err, part

  isParticipant = (name) ->
    return common.isParticipant processes[name]

  participants = Object.keys(processes).filter isParticipant
  debug 'starting participants', participants
  async.map participants, start, (err, parts) ->
    debug 'participants started', err, parts.length
    return callback err, parts

class ParticipantManager

  constructor: (@address, @graph=null, @library={}) ->
    @participants = []

  start: (callback) ->
    runtime = @graph.properties?.environment?.runtime
    runtime = 'msgflo' if not runtime
    return callback null if runtime != 'msgflo' # no-op

    startProcesses @library, @address, runtime, @graph.processes, (err, parts) =>
      @participants = parts
      return callback err

  stop: (callback) ->
    stopParticipant = (part, callback) =>
      part.stop (err) =>
        return callback err if err
        return callback null

    async.map @participants, stopParticipant, (err) =>
      return callback err if err
      @participants = []
      return callback null

exports.ParticipantManager = ParticipantManager
