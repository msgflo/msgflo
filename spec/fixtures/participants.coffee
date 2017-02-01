
msgflo = require '../..'


HelloParticipant = (client, role) ->

  definition =
    component: 'Hello'
    icon: 'file-word-o'
    label: 'Prepends "Hello" to any input'
    inports: [
      id: 'name'
      type: 'string'
    ]
    outports: [
      id: 'out'
      type: 'string'
    ]
  process = (inport, indata, callback) ->
    return callback 'out', null, "Hello " + indata
  return new msgflo.participant.Participant client, definition, process, role

exports.Hello = (c, i) -> new HelloParticipant c, i


FooSourceParticipant = (client, role) ->

  definition =
    component: 'FooSource'
    icon: 'file-word-o'
    label: 'Says "Foo" continiously when interval is non-0'
    inports: [
      id: 'interval'
      type: 'number'
      description: 'time between each Foo (in milliseconds)'
      default: 0
      hidden: true
    ]
    outports: [
      id: 'out'
      type: 'string'
    ]
  process = (inport, indata, send) ->
    return unless inport == 'interval'

    # Hack for storing state
    sayFoo = () ->
        return send 'out', null, "Foo"
    if indata == 0
        clearInterval @interval if @interval? and @interval
    else
        @interval = setInterval sayFoo, indata

  part = new msgflo.participant.Participant client, definition, process, role
  originalStop = part.stop.bind part
  part.stop = (cb) ->
    part.send 'interval', 0
    return originalStop cb
  return part

exports.FooSource = (c, i) -> new FooSourceParticipant c, i


DevNullParticipant = (client, role) ->

  definition =
    component: 'DevNullSink'
    icon: 'file-word-o'
    label: 'Drops all input'
    inports: [
      id: 'drop'
      type: 'any'
    ]
    outports: [
      id: 'dropped'
      type: 'string'
      description: 'Confirmation port for dropped input' 
      hidden: true
    ]
  process = (inport, indata, send) ->
    return unless inport == 'drop'
    return send 'dropped', null, indata

  return new msgflo.participant.Participant client, definition, process, role

exports.DevNullSink = (c, i) -> new DevNullParticipant c, i
exports.Drop = exports.DevNullSink


RepeatParticipant = (client, role) ->

  definition =
    component: 'Repeat'
    icon: 'file-word-o'
    label: 'Repeats in data without changes'
    inports: [
      id: 'in'
      type: 'any'
    ]
    outports: [
      id: 'out'
      type: 'any'
    ]
  process = (inport, indata, callback) ->
    return callback 'out', null, indata
  return new msgflo.participant.Participant client, definition, process, role

exports.Repeat = (c, i) -> new RepeatParticipant c, i

ErrorIfParticipant = (client, role) ->

  definition =
    component: 'ErrorIf'
    icon: 'file-word-o'
    label: 'Outputs Error if input is truthy else sends input on unchanged'
    inports: [
      id: 'in'
      type: 'any'
    ]
    outports: [
        id: 'out'
        type: 'any'
      ,
        id: 'error'
        type: 'error'
    ]
  process = (inport, indata, callback) ->
    if indata.error
      return callback 'error', new Error err.error, indata
    else
      return callback 'out', null, indata
  return new msgflo.participant.Participant client, definition, process, role

exports.ErrorIf = (c, i) -> new ErrorIfParticipant c, i

exports.main = main = () ->
  throw new Error 'Wrong number of arguments, expected 2: COMPONENT NAME' if process.argv.length != 4

  component = process.argv[2]
  role = process.argv[3]

  Part = exports[component]
  throw new Error "No such component #{component}" if not part and part

  broker = process.env['MSGFLO_BROKER']
  throw new Error 'Missing MSGFLO_BROKER environment variable' if not broker

  part = Part broker, role
  part.start (err) ->
    throw err if err
    console.log "#{role}(#{component}) connected to #{broker}"

main() if not module.parent

