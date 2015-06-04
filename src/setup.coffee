
common = require './common'

transport = require('msgflo-nodejs').transport
fbp = require 'fbp'
async = require 'async'

addBindings = (broker, bindings, callback) ->
  addBinding = (b, cb) ->
    broker.addBinding b, cb
  async.map bindings, addBinding, callback

queueName = (c) ->
  return common.queueName c.process, c.port

# Extact the queue bindings, including types from an FBP graph definition
exports.graphBindings = graphBindings = (graph) ->
  bindings = []
  roundRobins = {}
  for name, process of graph.processes
    continue if process.component != 'msgflo/RoundRobin'
    roundRobins[name] =
      type: 'roundrobin'

  roundRobinNames = Object.keys roundRobins
  for conn in graph.connections
    if conn.src.process in roundRobinNames
      binding = roundRobins[conn.src.process]
      if conn.src.port == 'deadletter'
        binding.deadletter = queueName conn.tgt
      else
        binding.tgt = queueName conn.tgt
    else if conn.tgt.process in roundRobinNames
      binding = roundRobins[conn.tgt.process]
      binding.src = queueName conn.src
    else
      # ordinary connection
      bindings.push
        type: 'pubsub'
        src: queueName conn.src
        tgt: queueName conn.tgt

  for n, binding of roundRobins
    bindings.push binding

  return bindings

exports.normalizeOptions = normalize = (options) ->
  options.broker = process.env['MSGFLO_BROKER'] if not options.broker
  options.broker = process.env['CLOUDAMQP_URL'] if not options.broker
  return options

exports.bindings = setupBindings = (options, callback) ->
  options = normalize options
  common.readGraph options.graphfile, (err, graph) ->
    return callback err if err
    bindings = graphBindings graph

    broker = transport.getBroker options.broker
    broker.connect (err) ->
      return callback err if err

      addBindings broker, bindings, (err) ->
        return callback err, bindings, graph

exports.parse = parse = (args) ->
  graph = null
  program
    .arguments('<graph.fbp/.json>')
    .option('--broker <URL>', 'URL of broker to connect to', String, null)
    .action (gr, env) ->
      graph = gr
    .parse args

  program.graphfile = graph
  return program

exports.prettyFormatBindings = pretty = (bindings) ->
  lines = []
  for b in bindings
    type = b.type.toUpperCase()
    if b.type == 'roundrobin'
      if b.tgt and b.deadletter
        lines.push "DEADLETTER:\t #{b.tgt} -> #{b.deadletter}"
      if b.tgt and b.src
        lines.push "ROUNDROBIN:\t #{b.src} -> #{b.tgt}"
    else if b.type == 'pubsub'
      lines.push "PUBSUB: \t #{b.src} -> #{b.tgt}"
    else
      lines.push "UNKNOWN binding type: #{b.type}"

  return lines.join '\n'

exports.main = main = () ->
  options = parse process.argv

  if not options.graphfile
    console.error 'ERROR: No graph file specified'
    program.help()
    process.exit()

  setupBindings options, (err, bindings) ->
    throw err if err

    console.log 'Set up bindings:\n', pretty bindings

