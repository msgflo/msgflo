
common = require './common'
{ Library } = require './library'

transport = require('msgflo-nodejs').transport
fbp = require 'fbp'
async = require 'async'
debug = require('debug')('msgflo:setup')
child_process = require 'child_process'
path = require 'path'
program = require 'commander'

addBindings = (broker, bindings, callback) ->
  addBinding = (b, cb) ->
    broker.addBinding b, cb
  async.map bindings, addBinding, callback

queueName = (c) ->
  return common.queueName c.process, c.port

startProcess = (cmd, options, callback) ->
  env = process.env
  env['MSGFLO_BROKER'] = options.broker
  if options.shell
    prog = options.shell
    args = ['-c', cmd]
  else
    prog = cmd.split(' ')[0]
    args = cmd.split(' ').splice(1)
  execCmd = prog + ' ' + args.join(' ')

  childoptions =
    env: env
  debug 'participant process start', execCmd
  child = child_process.spawn prog, args, childoptions
  returned = false
  child.on 'error', (err) ->
    debug 'participant error', prog, args.join(' ')
    return if returned
    returned = true
    return callback err, child
  # We assume that when somethis is send on stdout, starting is complete
  child.stdout.on 'data', (data) ->
    process.stdout.write(data.toString()) if options.forward.indexOf('stdout') != -1
    debug 'participant stdout', data.toString()
    return if returned
    returned = true
    return callback null, child
  child.stderr.on 'data', (data) ->
    process.stderr.write(data.toString()) if options.forward.indexOf('stderr') != -1
    debug 'participant stderr', data.toString()
    #return if returned
    #returned = true
    #return callback new Error data.toString(), child
  child.on 'exit', (code, signal) ->
    debug 'child exited', code, signal
    return if returned
    returned = true
    return callback new Error "Child '#{execCmd}' (pid=#{child.pid}) exited with #{code} #{signal}"
  return child

participantCommands = (graph, library, only, ignore) ->
  isParticipant = (name) ->
    return common.isParticipant graph.processes[name]

  commands = {}
  participants = Object.keys(graph.processes)
  participants = only if only?
  participants = participants.filter isParticipant
  for name in participants
    continue if ignore.indexOf(name) != -1
    component = graph.processes[name].component
    iips = common.iipsForRole graph, name
    cmd = library.componentCommand component, name, iips
    commands[name] = cmd
  return commands

exports.startProcesses = startProcesses = (commands, options, callback) ->
  start = (name, cb) =>
    cmd = commands[name]
    startProcess cmd, options, (err, child) ->
      return cb err if err
      return cb err, { name: name, command: cmd, child: child }

  debug 'starting participants', Object.keys(commands)
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
    if process.component == 'msgflo/RoundRobin'
      roundRobins[name] =
        type: 'roundrobin'

  isParticipant = (node) ->
    return common.isParticipant graph.processes[node]

  roundRobinNames = Object.keys roundRobins
  for conn in graph.connections

    if conn.data
        # IIP
    else if conn.src.process in roundRobinNames
      binding = roundRobins[conn.src.process]
      if conn.src.port == 'deadletter'
        binding.deadletter = queueName conn.tgt
      else
        binding.tgt = queueName conn.tgt
    else if conn.tgt.process in roundRobinNames
      binding = roundRobins[conn.tgt.process]
      binding.src = queueName conn.src
    else if isParticipant(conn.tgt.process) and isParticipant(conn.src.process)
      # ordinary connection
      bindings.push
        type: 'pubsub'
        src: queueName conn.src
        tgt: queueName conn.tgt
    else
      debug 'no binding for', queueName conn.src, queueName conn.tgt

  for n, binding of roundRobins
    bindings.push binding

  return bindings

staticGraphBindings = (broker, graph, callback) ->
  bindings = graphBindings graph
  return callback null, bindings

# callbacks with bindings
discoverParticipantQueues = (broker, graph, options, callback) ->
  foundParticipantsByRole = {}

  broker = transport.getBroker broker if typeof broker == 'string'
  broker.connect (err) ->
    return callback err if err

    addParticipant = (definition) ->
      foundParticipantsByRole[definition.role] = definition

      # determine if we are still lacking any definitions
      wantedRoles = []
      for name, proc of graph.processes
        wantedRoles.push name
      foundRoles = Object.keys foundParticipantsByRole
      missingRoles = []
      for wanted in wantedRoles
        idx = foundRoles.indexOf wanted
        found = idx != -1
        #console.log 'found?', wanted, found
        missingRoles.push wanted if not found

      debug 'addparticipant', definition.role, missingRoles
      #console.log 'wanted, found, missing', wantedRoles, foundRoles, missingRoles

      if missingRoles.length == 0
        return if not callback
        callback null, foundParticipantsByRole
        callback = null
        return

    onTimeout = () =>
      return if not callback
      callback new Error 'setup: Participant discovery timed out'
      callback = null
      return
    timeout = setTimeout onTimeout, options.timeout

    broker.subscribeParticipantChange (msg) =>
      data = msg.data
      if data.protocol == 'discovery' and data.command == 'participant'
        addParticipant data.payload
        broker.ackMessage msg
      else
        broker.nackMessage msg
        throw new Error 'Unknown FBP message'

bindingsFromDefinitions = (graph, definitions) ->
  bindings = []
  isParticipant = (node) ->
    return common.isParticipant graph.processes[node]

  findQueue = (ports, portname) ->
    found = null
    for port in ports
      #console.log 'port', port.id, portname, port.id == portname, port.queue
      if port.id == portname
        found = port.queue
    throw new Error "Could not find #{portname} in #{JSON.stringify(ports)}" if not found
    return found

  for conn in graph.connections
    continue unless conn.src # IIP
    if isParticipant(conn.tgt.process) and isParticipant(conn.src.process)
      # ordinary connection
      srcDef = definitions[conn.src.process]
      tgtDef = definitions[conn.tgt.process]
      srcQueue = findQueue srcDef.outports, conn.src.port
      tgtQueue = findQueue tgtDef.inports, conn.tgt.port
      console
      bindings.push
        type: 'pubsub'
        src: srcQueue
        tgt: tgtQueue
    else
      debug 'no binding for', queueName conn.src, queueName conn.tgt

  return bindings


exports.normalizeOptions = normalize = (options) ->
  common.normalizeOptions options
  options.libraryfile = path.join(process.cwd(), 'package.json') if not options.libraryfile

  options.only = options.only.split(',') if typeof options.only == 'string' and options.only
  options.ignore = options.ignore.split(',') if typeof options.ignore == 'string' and options.ignore
  options.forward = options.forward.split(',') if typeof options.forward == 'string' and options.forward
  options.only = null if not options.only
  options.ignore = [] if not options.ignore
  options.forward = [] if not options.forward
  options.extrabindings = [] if not options.extrabindings
  options.discover = false if not options.discover?
  options.forever = false if not options.forever?
  options.timeout = 10000 if not options.timeout?

  return options

exports.bindings = setupBindings = (options, callback) ->
  options = normalize options

  getBindings = staticGraphBindings # use queue name convention, read directly from graph file
  if options.discover
    # wait for FBP discovery messsages, use queues from there
    getBindings = (broker, graph, cb) ->
      discoverParticipantQueues options.broker, graph, options, (err, defs) ->
        return cb err if err
        #console.log 'got defs', definitions
        bindings = bindingsFromDefinitions graph, defs
        return cb null, bindings

  throw new Error 'ffss' if not callback
  common.readGraph options.graphfile, (err, graph) ->
    return callback err if err

    broker = transport.getBroker options.broker
    broker.connect (err) ->
      return callback err if err
      getBindings broker, graph, (err, bindings) ->
        return callback err if err

        bindings = bindings.concat options.extrabindings
        addBindings broker, bindings, (err) ->
          return callback err, bindings, graph

exports.participants = setupParticipants = (options, callback) ->
  options = normalize options
  common.readGraph options.graphfile, (err, graph) ->
    return callback err if err

    lib = new Library { configfile: options.libraryfile, componentdir: options.componentdir }
    lib.load (err) ->
      return callback err if err
      commands = participantCommands graph, lib, options.only, options.ignore
      return startProcesses commands, options, callback

exports.parse = parse = (args) ->
  graph = null
  program
    .arguments('<graph.fbp/.json>')
    .option('--broker <URL>', 'URL of broker to connect to', String, null)
    .option('--participants [BOOL]', 'Also set up participants, not just bindings', Boolean, false)
    .option('--only <one,two,three>', 'Only set up participants for these roles', String, '')
    .option('--ignore <one,two,three>', 'Do not set up participants for these roles', String, null)
    .option('--library <FILE.json>', 'Library definition to use', String, 'package.json')
    .option('--componentdir <DIR>', 'Directory where components are located', String, '')
    .option('--forward [stderr,stdout]', 'Forward child process stdout and/or stderr', String, '')
    .option('--discover [BOOL]', 'Whether to wait for FBP discovery messages for queue info', Boolean, false)
    .option('--timeout <SECONDS>', 'How long to wait for discovery messages', Number, 30)
    .option('--forever [BOOL]', 'Keep running until killed by signal', Boolean, false)
    .option('--shell [shell]', 'Run participant commands in a shell', String, '')
    .action (gr, env) ->
      graph = gr
    .parse args

  program.libraryfile = program.library
  program.graphfile = graph
  program.timeout = program.timeout*1000
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
    console.log 'Set up participants', Object.keys(p)

    setupBindings options, (err, bindings) ->
      throw err if err
      console.log 'Set up bindings:\n', pretty bindings

      if options.forever
        console.log '--forever enabled, keeping alive'
        setInterval () ->
          null # just keep alive
        , 1000
      else
        process.exit 0

