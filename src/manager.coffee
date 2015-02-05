
async = require 'async'

fakeruntime = require './fakeruntime'
transport = require './transport'

startProcesses = (address, runtime, processes, callback) ->
  # Loading fake participants, mostly for testing
  # one type could allow definiton a component library (in JSON),
  # where each component has a command for starting an executable
  # taking the broker address and participant identifier

  start = (processId, cb) =>
    component = processes[processId].component
    client = transport.getClient address
    fakeruntime.startParticipant client, component, processId, (err, part) ->
      return cb err, part

  console.log 'starting fake participants', processes
  async.map Object.keys(processes), start, (err, parts) ->
    console.log 'fake participants started', err, parts.length
    return callback err, parts

class ParticipantManager

  constructor: (@address, @graph) ->
    @participants = []

  start: (callback) ->
    runtime = @graph.properties?.environment?.runtime
    return callback null if runtime != 'fakemsgflo' # no-op

    startProcesses @address, runtime, @graph.processes, (err, parts) =>
      @participants = parts
      return callback err

  stop: (callback) ->
    stopParticipant = (part, callback) =>
      part.stop (err) =>
        return callback err if err
        return callback null

    async.map @participants, stopParticipant, (err) ->
      return callback err if err
      @participant = []
      return callback null

exports.ParticipantManager = ParticipantManager
