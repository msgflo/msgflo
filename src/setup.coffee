
common = require './common'
{ Library } = require './library'

transport = require('msgflo-nodejs').transport
fbp = require 'fbp'
async = require 'async'
debug = require('debug')('msgflo:setup')
child_process = require 'child_process'
path = require 'path'

addBindings = (broker, bindings, callback) ->
  addBinding = (b, cb) ->
    broker.addBinding b, cb
  async.map bindings, addBinding, callback

queueName = (c) ->
  return common.queueName c.process, c.port

startProcess = (cmd, broker, callback) ->
  env = process.env
  env['MSGFLO_BROKER'] = broker
  options =
    env: env
  prog = cmd.split(' ')[0]
  args = cmd.split(' ').splice(1)
#  console.log 'start', prog, args.join(' ')
  child = child_process.spawn prog, args, options
  returned = false
  child.on 'error', (err) ->
#    console.log 'error', err
    return if returned
    returned = true
    return callback err, child
  # We assume that when somethis is send on stdout, starting is complete
  child.stdout.on 'data', (data) ->
#    console.log 'stdout', data.toString()
    return if returned
    returned = true
    return callback null, child
  child.stderr.on 'data', (data) ->
    debug 'participant stderr', data.toString()
    #return if returned
    #returned = true
    #return callback new Error data.toString(), child
  child.on 'exit', (code, signal) ->
    debug 'child exited', code, signal
    return if returned
    returned = true
    return callback new Error "Child exited with #{code} #{signal}"
  return child

participantCommands = (graph, library, only, ignore) ->
  isParticipant = (name) ->
    component = graph.processes[name].component
    return component != 'msgflo/RoundRobin'

  commands = {}
  participants = Object.keys(graph.processes)
  participants = only if only?.length > 0
  participants = participants.filter isParticipant
  for name in participants
    continue if ignore.indexOf(name) != -1
    component = graph.processes[name].component
    cmd = library.componentCommand component, name
    commands[name] = cmd
  return commands

startProcesses = (commands, broker, callback) ->
  start = (name, cb) =>
    cmd = commands[name]
    startProcess cmd, broker, (err, child) ->
      return cb err if err
      return cb err, { name: name, command: cmd, child: child }

  debug 'starting participants', commands
  names = Object.keys commands
  async.map names, start, (err, processes) ->
    return callback err if err
    processMap = {}
    for p in processes
      processMap[p.name] = p.child
    return callback null, processMap

exports.killProcesses = (processes, signal, callback) ->
  return callback null if not processes
  signal = 'SIGTERM' if not signal

  kill = (name, cb) ->
    child = processes[name]
    return cb null if not child
    child.once 'exit', (code, signal) ->
      return cb null
    child.kill signal

  pids = Object.keys(processes).map (n) -> return processes[n].pid
  debug 'killing participants', pids
  names = Object.keys processes
  return async.map names, kill, callback

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
  options.libraryfile = path.join(process.cwd(), 'package.json') if not options.libraryfile

  options.only = options.only.split(',') if typeof options.only == 'string'
  options.ignore = options.ignore.split(',') if typeof options.ignore == 'string'
  options.only = [] if not options.only
  options.ignore = [] if not options.ignore

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

exports.participants = setupParticipants = (options, callback) ->
  options = normalize options
  common.readGraph options.graphfile, (err, graph) ->
    return callback err if err

    lib = new Library { configfile: options.libraryfile }
    commands = participantCommands graph, lib, options.only, options.ignore
    startProcesses commands, options.broker, callback

exports.parse = parse = (args) ->
  graph = null
  program
    .arguments('<graph.fbp/.json>')
    .option('--broker <URL>', 'URL of broker to connect to', String, null)
    .option('--participants', 'Also set up participants, not just bindings', Boolean, false)
    .option('--only', 'Only set up these participants', String, '')
    .option('--ignore', 'Do not set up these participants', String, '')
    .option('--library <FILE.json>', 'Library definition to use', String, 'package.json')
    .action (gr, env) ->
      graph = gr
    .parse args

  program.libraryfile = program.library
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

  maybeSetupParticipants = (options, callback) ->
    return callback null, {}
  maybeSetupParticipants = setupParticipants if options.participants

  maybeSetupParticipants options, (err, p) ->
    throw err if err
    console.log 'Set up participants', p

    setupBindings options, (err, bindings) ->
      throw err if err
      console.log 'Set up bindings:\n', pretty bindings

