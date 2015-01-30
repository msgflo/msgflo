
# Implementation of the FBP protocol
# http://noflojs.org/documentation/protocol

EventEmitter = require('events').EventEmitter

handleMessage = (proto, sub, cmd, payload, ctx) ->
  console.log 'FBP RECV:', sub, cmd, payload

  if sub == 'runtime' and cmd == 'getruntime'
    runtime =
      type: 'msgflo'
      version: '0.4'
      capabilities:
        'protocol:component'
      graph: 'default'
    proto.transport.send 'runtime', 'runtime', runtime, ctx

class Protocol
  constructor: (@transport, @coordinator) ->
    @transport.on 'message', (protocol, command, payload, ctx) =>
      handleMessage @, protocol, command, payload, ctx

exports.Protocol = Protocol
