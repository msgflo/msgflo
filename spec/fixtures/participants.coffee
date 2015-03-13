
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
