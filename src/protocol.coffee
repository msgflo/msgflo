
# Implementation of the FBP protocol
# http://noflojs.org/documentation/protocol

debug = require('debug')('msgflo:fbp')
EventEmitter = require('events').EventEmitter

handleMessage = (proto, sub, cmd, payload, ctx) ->
  debug 'RECV:', sub, cmd, payload

  defaultGraph = 'default/main'

  if sub == 'runtime' and cmd == 'getruntime'
    runtime =
      type: 'msgflo'
      version: '0.4'
      capabilities: [
        'protocol:component'
        'protocol:graph'
        'protocol:network'
        'component:getsource'
      ]
      graph: defaultGraph
    proto.transport.send 'runtime', 'runtime', runtime, ctx
  else if sub == 'component' and cmd == 'list'
    getPorts = (participant, type) ->
      out = []
      for port in participant[type]
        m =
          id: port.id
          type: port.type
          description: ""
          addressable: false
          required: false # TODO: implement
        out.push m
      return out

    debug 'attempting to list componenents'

    classes = []
    for name, part of proto.coordinator.participants
      return if part['class'] in classes # Avoid duplicates
      classes.push part['class']
      component =
        name: part['class']
        description: part.label or "" # FIXME: should be .description instead?
        icon: part.icon
        subgraph: false # TODO: implement
        inPorts: getPorts part, 'inports'
        outPorts: getPorts part, 'outports'
      proto.transport.send 'component', 'component', component, ctx

  else if sub == 'component' and cmd == 'getsource'
    return debug 'ERROR: cannot get source for #{payload.name}' if payload.name != defaultGraph

    sendSource = () ->
      graph = proto.coordinator.serializeGraph 'main'
      resp =
        code: JSON.stringify graph
        name: 'main'
        library: 'default'
        language: 'json'
      proto.transport.send 'component', 'source', resp, ctx

    setTimeout sendSource, 0

  else if sub == 'graph'
    handleGraphMessage proto, cmd, payload, ctx

  else
    debug 'Unhandled FBP protocol message: ', sub, cmd


handleGraphMessage = (proto, cmd, payload, ctx) ->
  graph = payload.graph

  if cmd == 'addedge'
    debug 'addedge', payload
    p = payload
    proto.coordinator.connect p.src.node, p.src.port, p.tgt.node, p.tgt.port
    proto.transport.sendAll 'graph', 'addedge', payload
  else if cmd == 'removeedge'
    p = payload
    proto.coordinator.disconnect p.src.node, p.src.port, p.tgt.node, p.tgt.port
    proto.transport.sendAll 'graph', 'removeedge', payload
  else if cmd == 'addinitial'
    proto.coordinator.addInitial payload.tgt.node, payload.tgt.port, payload.src.data
    proto.transport.sendAll 'graph', 'addinitial', payload
  else if cmd == 'removeinitial'
    proto.coordinator.removeInitial payload.tgt.node, payload.tgt.port
    proto.transport.sendAll 'graph', 'removeinitial', payload
  else
    debug 'Unhandled FBP protocol message: ', 'graph', cmd

class Protocol
  constructor: (@transport, @coordinator) ->
    throw Error 'Protocol' if not @coordinator

    @transport.on 'message', (protocol, command, payload, ctx) =>
      handleMessage @, protocol, command, payload, ctx

    @coordinator.on 'data', (from, fromPort, to, toPort, data) =>
      debug 'on data', from, fromPort, data

      id = "#{from}() #{fromPort.toUpperCase()} -> #{toPort.toUpperCase()} #{to}()"
      msg =
        id: id # FIXME: https://github.com/noflo/noflo-ui/issues/293
        graph: 'default/main' # FIXME: unhardcode
        src:
          node: from
          port: fromPort
        tgt:
          node: to
          port: toPort
        data: data
      @transport.sendAll 'network', 'data', msg

exports.Protocol = Protocol
