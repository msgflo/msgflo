
chance = require 'chance'

msgflo = require '../..'

random = new chance.Chance 10202

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

  return new msgflo.participant.Participant client, definition, process, role

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

