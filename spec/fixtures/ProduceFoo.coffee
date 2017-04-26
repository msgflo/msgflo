msgflo = require 'msgflo-nodejs'

ProduceFoo = (client, role) ->
  definition =
    component: 'ProduceFoo'
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
    ]
  process = (inport, indata, send) ->
    return unless inport == 'interval'

    sayFoo = () ->
        return send 'out', null, "Foo"
    if indata == 0
        clearInterval @interval if @interval? and @interval
    else
        @interval = setInterval sayFoo, indata

  return new msgflo.participant.Participant client, definition, process, role

module.exports = ProduceFoo
