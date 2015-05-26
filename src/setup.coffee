
common = require './common'

fbp = require 'fbp'
async = require 'async'

addBindings = (broker, bindings, callback) ->
  addBinding = (b, cb) ->
    broker.addBinding b, cb
  async.map bindings, addBinding, callback

queueName = (c) ->
  return common.queueName c.process, c.port

# Extact the queue bindings, including types from an FBP graph definition
graphBindings = (graph) ->
  bindings = []
  roundRobins = []
  for name, process of graph
    roundRobins.push name if process.component == 'msgflo/RoundRobin'

  for conn in graph
    if conn.src.process in roundRobins
      bindings.push
        type: 'roundrobin'
    else if conn.tgt.process in roundRobins
      bindings.push
        type: 'roundrobin'
    else
      # ordinary connection
      bindings.push
        type: 'pubsub'
        src: queueName conn.src
        tgt: queueName conn.src

  return bindings

exports.bindings = setupBindings = (options, callback) ->
  common.readGraph options.graphfile, (err, graph) ->
    return callback err if err
    bindings = graphBindings graph

    broker = transport.getBroker options.broker
    broker.connect (err) ->
      return callback err if err

      addBindings broker, bindings, (err) ->
        return callback err, bindings

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

pretty = (bindings) ->
  lines = []
  for b in bindings
    type = b.type.toUpperCase()
    if b.type == 'roundrobin'
      if b.tgt and b.deadletter
        lines.push "DEADLETTER #{b.tgt} -> #{b.deadletter}"
      if b.tgt and b.src 
        lines.push "ROUNDROBIN #{b.src} -> #{b.tgt}"
    else if b.type == 'pubsub'
      lines.push "#{type} #{b.src} -> #{b.tgt}"
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

