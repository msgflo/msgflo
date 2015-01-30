
# Implementation of the FBP protocol
# http://noflojs.org/documentation/protocol

EventEmitter = require('events').EventEmitter

handleMessage = (proto, sub, cmd, payload, ctx) ->
  console.log 'FBP RECV:', sub, cmd, payload

  defaultGraph = 'default'

  if sub == 'runtime' and cmd == 'getruntime'
    runtime =
      type: 'msgflo'
      version: '0.4'
      capabilities: [
        'protocol:component'
        'protocol:graph'
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

    console.log 'Protocol, attempting to list componenents'

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
    return if payload.name != defaultGraph

  else
    console.log 'Unhandled FBP protocol message: ', sub, cmd


class Protocol
  constructor: (@transport, @coordinator) ->
    throw Error 'Protocol' if not @coordinator

    @transport.on 'message', (protocol, command, payload, ctx) =>
      handleMessage @, protocol, command, payload, ctx

exports.Protocol = Protocol
