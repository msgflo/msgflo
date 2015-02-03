
randomstring = require 'randomstring'
async = require 'async'

findPort = (def, type, portName) ->
  ports = if type == 'inport' then def.inports else def.outports
  for port in ports
    return port if port.id == portName
  return null

class Participant
  # @func gets called with inport, , and should return outport, outdata
  constructor: (@messaging, @definition, @func) ->
    @running = false

  start: (callback) ->
    @messaging.connect (err) =>
      console.log 'participant connected', err
      return callback err if err
      @setupPorts (err) =>
        @running = true
        return callback err if err
        @register (err) ->
          return callback err

  stop: (callback) ->
    console.log 'stopping participant'
    @running = false
    @messaging.removeQueue 'fbp', (err) =>
      @messaging.disconnect callback

  setupPorts: (callback) ->
    setupPort = (def, callback) =>
      @messaging.createQueue def.queue, callback

    sendFunc = (output) =>
      port = findPort @definition, 'outport', output[0]
      @messaging.sendToQueue port.queue, output[1], (err) ->

    subscribePort = (def, callback) =>
      callFunc = (msg) =>
        return if not @running
        output = @func def.id, msg
        return sendFunc output if output

      @messaging.subscribeToQueue def.queue, callFunc, callback

    allports = @definition.outports.concat @definition.inports

    async.map allports, setupPort, (err) =>
      return callback err if err
      async.map @definition.inports, subscribePort, (err) =>
        return callback err if err
        return callback null
  

  register: (callback) ->
    # Send discovery package to broker on 'fbp' queue
    @messaging.createQueue 'fbp', (err) =>
      # console.log 'fbp queue created'
      return callback err if err
      # TODO: be able to define in/outports and metadata
      msg =
        protocol: 'discovery'
        command: 'participant'
        payload: @definition
      @messaging.sendToQueue 'fbp', msg, (err) ->
        return callback err if err
        return callback null

# TODO: consider making component api a bit more like NoFlo.WirePattern
#
# inputs = { portA: { data: dataA1, groups: ['A', '1'] }, portB: { data: B1 } }
# outfunc = (type, outputs) -> # type can be 'data', 'end'
# process(inputs, outfunc)
#
# Core ideas:
# groups attached to the packet, avoids separate lifetime handling, but still allows modification
# should one enforce use of promises? calling process returns a promise?

HelloParticipant = (client, customId) ->
  id = 'hello-' + randomstring.generate 6
  id = customId if customId

  definition =
    id: id
    'class': 'Hello'
    icon: 'file-word-o'
    label: 'Prepends "Hello" to any input'
    inports: [
      id: 'name'
      queue: id+'-inputq'
      type: 'string'
    ]
    outports: [
      id: 'out'
      queue: id+'-outputq'
      type: 'string'
    ]
  process = (inport, indata) ->
    return ['out', "Hello " + indata]
  return new Participant client, definition, process

startParticipant = (client, componentName, id, callback) ->
  library =
    'Hello': HelloParticipant
  console.log 'starting', componentName, id

  component = library[componentName]
  part = component client, id
  part.start callback

exports.HelloParticipant = HelloParticipant
exports.Participant = Participant
exports.startParticipant = startParticipant
