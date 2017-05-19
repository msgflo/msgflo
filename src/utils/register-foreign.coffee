program = require 'commander'
msgflo_nodejs = require 'msgflo-nodejs'
fs = require 'fs'
path = require 'path'
foreigner = require '../foreign-participant'
common = require '../common'
yaml = require 'js-yaml'

onError = (err) ->
  console.log err
  process.exit 1

onComplete = ->
  process.exit 0

main = ->
  program
    .option('--broker <uri>', 'Broker address', String, '')
    .option('--role <role>', 'Role of this instance', String, '')
    .option('--interval <SECONDS>', 'How often to send discovery message', Number, 60)
    .option('--forever <true>', 'Keep running forever', Boolean, false)
    .usage('[options] <definition>')
    .parse(process.argv)
  program = common.normalizeOptions program

  console.error "DEPRECATED: Instead use msgflo-register --role A:./filename.yaml - which also supports multiple roles"

  defPath = path.resolve process.cwd(), program.args[0]
  fs.readFile defPath, 'utf-8', (err, contents) ->
    return onError err if err
    return onError "No definition found in #{defPath}" unless contents
    try
      definition = yaml.safeLoad contents
    catch e
      return onError e

    if not definition.component
      return onError new Error ".component is not defined"
    definition.role = program.role if program.role
    if not definition.role
      return onError new Error ".role is not defined for component #{definition.component}"
    definition.id = definition.role if not definition.id

    definition = foreigner.mapPorts definition
    messaging = msgflo_nodejs.transport.getClient program.broker
    messaging.connect (err) ->
      return onError err if err
      foreigner.register messaging, definition, (err) ->
        return onError err if err
        console.log 'Sent discovery message for', definition.id

        if program.forever
          console.log '--forever enabled'
          setInterval () ->
            foreigner.register messaging, definition, (err) ->
              console.log 'Warning: Failed to send discovery message:', err if err
          , program.interval*1000/2.2
        else
          onComplete()

exports.main = main
