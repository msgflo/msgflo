
chance = require 'chance'

msgflo = require '../..'

random = new chance.Chance 10202

HelloParticipant = (client, customId) ->
  id = 'hello-' + random.string {pool: 'abcdef', length: 4}
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
  process = (inport, indata, callback) ->
    return callback 'out', null, "Hello " + indata
  return new msgflo.participant.Participant client, definition, process

exports.Hello = (c, i) -> new HelloParticipant c, i


FooSourceParticipant = (client, customId) ->
  id = 'foosource-' + random.string {pool: 'abcdef', length: 4}
  id = customId if customId

  definition =
    id: id
    'class': 'FooSource'
    icon: 'file-word-o'
    label: 'Says "Foo" continiously when interval is non-0'
    inports: [
      id: 'interval'
      type: 'number'
      description: 'time between each Foo (in milliseconds)'
      default: 0
    ]
    outports: [
      id: 'out'
      type: 'string'
      queue: id+'-outputq'
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

  return new msgflo.participant.Participant client, definition, process

exports.FooSource = (c, i) -> new FooSourceParticipant c, i


DevNullParticipant = (client, customId) ->
  id = 'devnullsink-' + random.string {pool: 'abcdef', length: 4}
  id = customId if customId

  definition =
    id: id
    'class': 'DevNullSink'
    icon: 'file-word-o'
    label: 'Drops all input'
    inports: [
      id: 'drop'
      type: 'any'
      queue: id+'-dropq'
    ]
    outports: [
      id: 'dropped'
      type: 'string'
      description: 'Confirmation port for dropped input' 
    ]
  process = (inport, indata, send) ->
    return unless inport == 'drop'
    return send 'dropped', null, indata

  return new msgflo.participant.Participant client, definition, process

exports.DevNullSink = (c, i) -> new DevNullParticipant c, i

