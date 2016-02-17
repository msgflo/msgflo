
exports.clone = clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance

exports.readGraph = (filepath, callback) ->
  path = require 'path'
  fs = require 'fs'
  fbp = require 'fbp'

  ext = path.extname filepath
  fs.readFile filepath, { encoding: 'utf-8' }, (err, contents) ->
    return callback err if err
    try
      if ext == '.fbp'
        graph = fbp.parse contents
      else
        graph = JSON.parse contents
    catch e
      return callback e
    return callback null, graph

exports.normalizeOptions = (options) ->
  options.broker = process.env['MSGFLO_BROKER'] if not options.broker
  options.broker = process.env['CLOUDAMQP_URL'] if not options.broker
  options.broker = 'amqp://localhost' if not options.broker
  return options

# Note: relies on convention
exports.queueName = (role, port) ->
  return "#{role}.#{port.toUpperCase()}"

exports.isParticipant = (p) ->
  return p.component? and p.component != 'msgflo/RoundRobin' and p.component != 'msgflo/PubSub'

exports.iipsForRole = (graph, role) ->
  iips = {}
  for conn in graph.connections
    continue if not conn.data?
    continue if conn.tgt.process != role
    iips[conn.tgt.port] = conn.data
  return iips
