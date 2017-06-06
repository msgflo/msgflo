
debug = require('debug')('msgflo:coordinator')
EventEmitter = require('events').EventEmitter
fs = require 'fs'
path = require 'path'
async = require 'async'
https = require 'https'
url = require 'url'

setup = require './setup'
library = require './library'
common = require './common'

findPort = (def, type, portName) ->
  ports = if type == 'inport' then def.inports else def.outports
  for port in ports
    return port if port.id == portName
  return null

connId = (fromId, fromPort, toId, toPort) ->
  return "#{fromId} #{fromPort} -> #{toPort} #{toId}"
fromConnId = (id) ->
  t = id.split ' '
  return [ t[0], t[1], t[4], t[3] ]
iipId = (part, port) ->
  return "#{part} #{port}"
fromIipId = (id) ->
  return id.split ' '

participantsByRole = (participants, role) ->
  matchRole = (id) =>
    part = participants[id]
    return part.role == role

  m = Object.keys(participants).filter matchRole
  return m

# XXX: there is now a mixture of participant id and role used here
findQueue = (participants, partId, dir, portName) =>
  part = participants[partId]
  partIdByRole = participantsByRole(participants, partId)[0]
  part = participants[partIdByRole] if not part?
  throw new Error "No participant info found for '#{partId}'" if not part?
  for port in part[dir]
    if port.id == portName
      throw new Error "Queue for #{dir} '#{portName}' missing in #{JSON.stringify(part)}" if not port.queue
      return port.queue
  throw new Error "No matching port found for #{dir} '#{portName}' in #{JSON.stringify(part)}"

connectionFromBinding = (participants, binding) ->
  byRole = {}
  for id, part of participants
    byRole[part.role] = part

  findNodePort = (queue, dir) ->
    for role, part of byRole
      for port in part[dir]
        if port.queue == queue
          r =
            node: role
            port: port.id
          return r

  connection =
    src: findNodePort binding.src, 'outports'
    tgt: findNodePort binding.tgt, 'inports'
  return connection

waitForParticipant = (coordinator, role, callback) ->
  existing = participantsByRole coordinator.participants, role
  return callback null, coordinator.participants[existing[0]] if existing.length

  onTimeout = () =>
    return callback new Error "Waiting for participant #{role} timed out"
  timeout = setTimeout onTimeout, coordinator.options.waitTimeout*1000

  onParticipantAdded = (part) =>
    if part.role == role
      debug 'onParticipantAdded', part.role # FIXME: take into account multiple participants with same role
      clearTimeout timeout
      coordinator.removeListener 'participant-added', onParticipantAdded
      return callback null
  coordinator.on 'participant-added', onParticipantAdded

pingUrl = (address, method, callback) ->
  u = url.parse address
  u.port = 80 if u.protocol == 'http' and not u.port
  u.method = method
  u.timeout = 10*1000
  req = https.request u, (res) ->
    status = res.statusCode
    return callback new Error "Ping #{method} #{address} failed with #{status}" if status != 200
    return callback null
  req.on 'error', (err) ->
    return callback err
  req.end()

class Coordinator extends EventEmitter
  constructor: (@broker, @options = {}) ->
    @participants = {} # participantId -> Definition (from discovery)
    @connections = {} # connId -> { queue: opt String, handler: opt function }
    @iips = {} # iipId -> { metadata, data }
    @nodes = {} # role -> { metadata: {} }
    @started = false
    @processes = {}
    libraryOptions =
      configfile: @options.library
      componentdir: @options.componentdir
      config: @options.config
    @library = new library.Library libraryOptions
    @exported =
      inports: {}
      outports: {}
    @options.waitTimeout = 40 if not @options.waitTimeout?
    @graphName = null
    @on 'participant', @checkParticipantConnections

    @alivePingInterval = null

  clearGraph: (graphName, callback) ->
    @connections = {}
    @iips = {}
    @graphName = graphName
    @nodes = {}
    @participants = {} # NOTE: also removes discovered things, not setup by us. But should soon be discovered again
    setup.killProcesses @processes, 'SIGTERM', (err) =>
      @processes = {}
      return callback err

  start: (callback) ->
    @library.load (err) =>
      return callback err if err
      @broker.connect (err) =>
        debug 'connected', err
        return callback err if err
        @broker.subscribeParticipantChange (msg) =>
          try
            @handleFbpMessage msg.data
          catch e
            console.error 'Participant discovery failed:', e.message, '\n', e.stack, '\n', JSON.stringify(msg.data, 2, null)
          @broker.ackMessage msg
        @started = true
        debug 'started', err, @started

        alivePing = () =>
          return if not @options.pingInterval
          pingUrl @options.pingUrl, @options.pingMethod, (err) ->
            return debug 'alive-ping-error', err if err
            debug 'alive-ping-success'
        @alivePingInterval = setInterval alivePing, @options.pingInterval*1000
        alivePing()

        return callback null

  stop: (callback) ->
    @clearGraph @graphName, (clearErr) =>
      @broker.disconnect (err) =>
        return callback clearErr if clearErr
        return callback err

  handleFbpMessage: (data) ->
    if data.protocol == 'discovery' and data.command == 'participant'
      @participantDiscovered data.payload
    else
      throw new Error "Unknown FBP message: #{typeof(data)} #{data?.protocol}:#{data?.command}"

  participantDiscovered: (definition) ->
    throw new Error "Discovery message missing .id" if not definition.id
    throw new Error "Discovery message missing .component" if not definition.component
    throw new Error "Discovery message missing .role" if not definition.role
    throw new Error "Discovery message missing .inports" if not definition.inports
    throw new Error "Discovery message missing .outports" if not definition.outports
    if @participants[definition.id]
      @updateParticipant definition
    else
      @addParticipant definition

  updateParticipant: (definition) ->
    debug 'updateParticipant', definition.id
    original = @participants[definition.id]
    definition.extra = {} if not definition.extra
    definition.extra.lastSeen = new Date
    newDefinition = common.clone definition
    for k, v of original
      newDefinition[k] = v if not newDefinition[k]
    @participants[definition.id] = newDefinition
    @library._updateDefinition newDefinition.component, newDefinition
    @emit 'participant-updated', newDefinition
    @emit 'participant', 'updated', newDefinition

  addParticipant: (definition) ->
    debug 'addParticipant', definition.id
    definition.extra = {} if not definition.extra
    definition.extra.firstSeen = new Date
    definition.extra.lastSeen = new Date
    @participants[definition.id] = definition

    # Ensure we have a node also for discovered participants
    @nodes[definition.role] = { metadata: {} } if not @nodes[definition.role]
    @nodes[definition.role].component = definition.component

    @library._updateDefinition definition.component, definition
    @emit 'participant-added', definition
    @emit 'participant', 'added', definition
    @emit 'graph-changed'

  removeParticipant: (id) ->
    definition = @participants[id]
    delete @participants[id]
    @emit 'participant-removed', definition
    @library._updateDefinition definition.component, null
    @emit 'participant', 'removed', definition
    @emit 'graph-changed'

  addComponent: (name, language, code, callback) ->
    @library.addComponent name, language, code, callback

  getComponentSource: (component, callback) ->
    return @library.getSource component, callback

  startParticipant: (node, component, metadata, callback) ->
    if typeof metadata is 'function'
      callback = metadata
      metadata = {}
    metadata = {} unless metadata
    if @options.ignore?.length and node in @options.ignore
      console.log "WARNING: Not restarting ignored participant #{node}"
      return callback null
    if not @library.components[component]?.command
      console.log "WARNING: Attempting to start participant with missing component: #{node}(#{component})"
      # XXX: should be an error, but Flowhub does this in project mode..
      return callback null

    @nodes[node] = { metadata: {} } if not @nodes[node]
    @nodes[node].metadata = metadata
    @nodes[node].component = component

    iips = {}
    cmd = @library.componentCommand component, node, iips
    commands = {}
    commands[node] = cmd
    options =
      broker: @options.broker
      forward: @options.forward or ''
    setup.startProcesses commands, options, (err, processes) =>
      return callback err if err
      for k, v of processes
        @processes[k] = v
      waitForParticipant @, node, (err) ->
        return callback err, processes

  stopParticipant: (node, component, callback) ->
    return callback new Error "stopParticipant(): Missing node argument" if not (node? and typeof node == 'string')

    processes = {}
    for k, v of @processes
      if k == node
        processes[k] = v
    delete @nodes[node]

    removeDiscoveredParticipants = (role) =>
      keep = {}
      for id, def of @participants
        match = def.role == role
        keep[id] = def if not match
      @participants = keep

    # we know it should stop sending discovery, pre-emptively remove
    removeDiscoveredParticipants node
    @emit 'graph-changed'
    setup.killProcesses processes, 'SIGTERM', (err) =>
      return callback err if err
      for k, v of processes
        delete @processes[k]
      # might have been discovered again during shutdown
      removeDiscoveredParticipants node
      return callback null, processes

  updateNodeMetadata: (node, metadata, callback) ->
    metadata = {} unless metadata
    process = null
    if not @nodes[node]
      return callback new Error "Node #{node} not found"
    @nodes[node].metadata = metadata
    return callback null

  sendTo: (participantId, inport, message, callback) ->
    debug 'sendTo', participantId, inport, message
    defaultCallback = (err) ->
      throw err if err
    callback = defaultCallback if not callback

    part = @participants[participantId]
    id = participantsByRole(@participants, participantId)[0]
    part = @participants[id] if not part?

    port = findPort part, 'inport', inport
    return callback new Error "Cannot find inport #{inport}" if not port
    return @broker.sendTo 'inqueue', port.queue, message, callback

  subscribeTo: (participantId, outport, handler, callback) ->
    defaultCallback = (err) ->
      throw err if err
    callback = defaultCallback if not callback

    part = @participants[participantId]
    id = participantsByRole(@participants, participantId)[0]
    part = @participants[id] if not part?

    debug 'subscribeTo', participantId, outport
    port = findPort part, 'outport', outport
    ackHandler = (msg) =>
      return if not @started
      handler msg
      @broker.ackMessage msg

    return callback new Error "Could not find outport #{outport} for role #{participantId}" if not port

    # Cannot subscribe directly to an outqueue, must create and bind an inqueue
    readQueue = 'msgflo-export-' + Math.floor(Math.random()*999999)
    @broker.createQueue 'inqueue', readQueue, (err) =>
      return callback err if err
      @broker.addBinding {type: 'pubsub', src: port.queue, tgt: readQueue}, (err) =>
        return callback err if err
        @broker.subscribeToQueue readQueue, ackHandler, (err) ->
          return callback err, readQueue # caller should teardown readQueue

  unsubscribeFrom: () -> # FIXME: implement

  connect: (fromId, fromPort, toId, toName, metadata, callback) ->
    if typeof metadata is 'function'
      callback = metadata
      metadata = {}
    metadata = {} unless metadata
    callback = ((err) ->) if not callback
 
    # NOTE: adding partial connection info to make checkParticipantConnections logic work
    edgeId = connId fromId, fromPort, toId, toName
    edge =
      fromId: fromId
      fromPort: fromPort
      toId: toId
      toName: toName
      srcQueue: null
      tgtQueue: null
      metadata: metadata
    debug 'connect', edge
    @connections[edgeId] = edge

    # might be that it was just added/started, not yet discovered
    waitForParticipant @, fromId, (err) =>
      return callback err if err
      waitForParticipant @, toId, (err) =>
        return callback err if err
        # TODO: support roundtrip
        @connections[edgeId].srcQueue = findQueue @participants, fromId, 'outports', fromPort
        @connections[edgeId].tgtQueue = findQueue @participants, toId, 'inports', toName
        edgeWithQueues = @connections[edgeId]
        @emit 'graph-changed'
        binding =
          type: 'pubsub'
          src: edgeWithQueues.srcQueue
          tgt: edgeWithQueues.tgtQueue
        if not binding.src
          return callback new Error "Source queue for connection #{fromId} #{fromPort} not found"
        if not binding.tgt
          return callback new Error "Target queue for connection #{toName} #{toPort} not found"
        @broker.addBinding binding, (err) =>
          return callback err

  disconnect: (fromId, fromPort, toId, toPort, callback) ->
    edgeId = connId fromId, fromPort, toId, toPort
    edge = @connections[edgeId]
    return callback new Error "Could not find connection #{edgeId}" if not edge
    return callback new Error "No queues for connection #{edgeId}" if not edge.srcQueue and edge.tgtQueue
    @broker.removeBinding { type: 'pubsub', src: edge.srcQueue, tgt: edge.tgtQueue }, (err) =>
      return callback err if err
      delete @connections[edgeId]
      @emit 'graph-changed'
      return callback null

  updateEdge: (fromId, fromPort, toId, toPort, metadata, callback) ->
    metadata = {} unless metadata
    edgeId = connId fromId, fromPort, toId, toPort
    edge = @connections[edgeId]
    return callback new Error "Could not find connection #{edgeId}" if not edge
    @connections[edgeId].metadata = metadata
    return callback null

  checkParticipantConnections: (action, participant) ->
    findConnectedPorts = (dir, srcPort) =>
      conn = []
      # return conn if not srcPort.queue
      for id, part of @participants
        for port in part[dir]
          continue if not port.queue
          conn.push { part: part, port: port } if port.queue == srcPort.queue
      return conn

    isConnected = (e) =>
      [fromId, fromPort, toId, toPort] = e
      id = connId fromId, fromPort, toId, toPort
      return @connections[id]?

    if action == 'added'
      role = participant.role
      # inbound
      for port in participant.inports
        matches = findConnectedPorts 'outports', port
        for m in matches
          e = [m.part.role, m.port.id, role, port.id]
          @connect e[0], e[1], e[2], e[3] if not isConnected e

      # outbound
      for port in participant.outports
        matches = findConnectedPorts 'inports', port
        for m in matches
          e = [role, port.id, m.part.role, m.port.id]
          @connect e[0], e[1], e[2], e[3] if not isConnected e

    else if action == 'removed'
      null # TODO: implement

    else
      null # ignored

  addInitial: (partId, portId, data, metadata, callback) ->
    if typeof metadata is 'function'
      callback = metadata
      metadata = {}
    metadata = {} unless metadata
    id = iipId partId, portId
    @iips[id] =
      data: data
      metadata: metadata
    waitForParticipant @, partId, (err) =>
      return callback err if err
      if @started
        @sendTo partId, portId, data, (err) ->
          return callback err
      else
        return callback null

  removeInitial: (partId, portId) -> # FIXME: implement
    # Do we need to remove it from the queue??

  exportPort: (direction, external, node, internal, metadata, callback) ->
    if typeof metadata is 'function'
      callback = metadata
      metadata = {}
    metadata = {} unless metadata
    target = if direction.indexOf("in") == 0 then @exported.inports else @exported.outports
    target[external] =
      role: node
      port: internal
      subscriber: null
      queue: null
    graph = null # FIXME: capture
    # Wait for target node to exist
    waitForParticipant @, node, (err) =>
      return callback err if err

      if direction.indexOf('out') == 0
        handler = (msg) =>
          @emit 'exported-port-data', external, msg.data, graph
        @subscribeTo node, internal, handler, (err, readQueue) ->
          return callback err if err
          target[external].subscriber = handler
          target[external].queue = readQueue
          return callback null
      else
        return callback null

  unexportPort: () -> # FIXME: implement

  sendToExportedPort: (port, data, callback) ->
    # FIXME lookup which node, port this corresponds to
    internal = @exported.inports[port]
    debug 'sendToExportedPort', port, internal
    return callback new Error "Cannot find exported port #{port}" if not internal
    @sendTo internal.role, internal.port, data, callback

  startNetwork: (networkId, callback) ->
    # Don't have a concept of started/stopped so far, no-op
    setTimeout callback, 10

  stopNetwork: (networkId, callback) ->
    # Don't have a concept of started/stopped so far, no-op
    setTimeout callback, 10
  
  _onConnectionData: (binding, data) =>
    connection = connectionFromBinding @participants, binding
    connection.graph = @graphName
    @emit 'connection-data', connection, data

  clearSubscriptions: (callback) ->
    @broker.listSubscriptions (err, subs) =>
      return callback err if err
      async.map subs, (sub, cb) =>
        @broker.unsubscribeData sub, @_onConnectionData, cb
      , callback

  subscribeConnection: (fromRole, fromPort, toRole, toPort, callback) ->
    waitForParticipant @, fromRole, (err) =>
      return callback err if err
      waitForParticipant @, toRole, (err) =>
        return callback err if err
        binding =
          src: findQueue @participants, fromRole, 'outports', fromPort
          tgt: findQueue @participants, toRole, 'inports', toPort
        @broker.subscribeData binding, @_onConnectionData, callback

  unsubscribeConnection: (fromRole, fromPort, toRole, toPort, callback) ->
    waitForParticipant @, fromRole, (err) =>
      return callback err if err
      waitForParticipant @, toRole, (err) =>
        return callback err if err
        binding =
          src: findQueue @participants, fromRole, 'outports', fromPort
          tgt: findQueue @participants, toRole, 'inports', toPort
        @broker.unsubscribeData binding, @_onConnectionData, callback
        return callback null

  serializeGraph: (name) ->
    graph =
      properties:
        name: name
        environment:
          type: 'msgflo'
      processes: {}
      connections: []
      inports: []
      outports: []

    nodeNames = Object.keys(@nodes).sort()
    for name in nodeNames
      node = @nodes[name]
      graph.processes[name] =
        component: node.component
        metadata: node.metadata or {}

    connectionIds = Object.keys(@connections).sort()
    for id in connectionIds
      conn = @connections[id]
      parts = fromConnId id
      edge =
        src:
          process: parts[0]
          port: parts[1]
        tgt:
          process: parts[2]
          port: parts[3]
        metadata: @connections[id].metadata
      graph.connections.push edge

    iipIds = Object.keys(@iips).sort()
    for id in iipIds
      iip = @iips[id]
      parts = fromIipId id
      edge =
        data: iip.data
        tgt:
          process: parts[0]
          port: parts[1]
        metadata: iip.metadata
      graph.connections.push edge

    return graph

  loadGraphFile: (path, opts, callback) ->
    debug 'loadGraphFile', path
    options =
      graphfile: path
      libraryfile: @library.configfile
    for k, v of opts
      options[k] = v

    # Avoid trying to instantiate
    # Probably these are external participants, which *should* be running
    # TODO: check whether the participants do indeed show up
    rolesWithComponent = []
    rolesNoComponent = []
    availableComponents = Object.keys @library.components
    common.readGraph options.graphfile, (err, graph) =>
      return callback err if err
      for role, process of graph.processes
        if process.component in availableComponents
          rolesWithComponent.push role
        else
          rolesNoComponent.push role
      if rolesNoComponent.length
        console.log 'Skipping setup for participants without component available. Assuming already setup:'
      for role in rolesNoComponent
        componentName = graph.processes[role].component
        console.log "\t#{role}(#{componentName})"

      rolesToSetup = rolesWithComponent.concat([]).filter (r) ->
        return r not in options.ignore
      options.only = rolesToSetup

      setupParticipants = (setupCallback) =>
        participantStartConcurrency = 10
        async.mapLimit options.only, participantStartConcurrency, (role, cb) =>
          componentName = graph.processes[role].component
          metadata = graph.processes[role].metadata or {}
          @startParticipant role, componentName, metadata, cb
        , setupCallback

      setupConnections = (setupCallback) =>
        async.map graph.connections, (c, cb) =>
          if c.data
            @addInitial c.tgt.process, c.tgt.port, c.data, c.metadata, cb
          else
            @connect c.src.process, c.src.port, c.tgt.process, c.tgt.port, c.metadata, cb
        , setupCallback

      async.parallel
        connections: setupParticipants
        participants: setupConnections
      , (err, results) ->
        return callback err if err
        return callback null

exports.Coordinator = Coordinator
