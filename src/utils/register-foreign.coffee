program = require 'commander'
msgflo_nodejs = require 'msgflo-nodejs'
fs = require 'fs'
path = require 'path'
foreigner = require '../foreign-participant'
yaml = require 'js-yaml'

onError = (err) ->
  console.log err
  process.exit 1

onComplete = ->
  process.exit 0

main = ->
  program
    .option('--broker <uri>', 'Broker address', String, 'amqp://localhost')
    .usage('[options] <definition>')
    .parse(process.argv)

  defPath = path.resolve process.cwd(), program.args[0]
  fs.readFile defPath, 'utf-8', (err, contents) ->
    return onError err if err
    return onError "No definition found in #{defPath}" unless contents
    try
      definition = yaml.safeLoad contents
    catch e
      return onError e
    definition.id = path.basename defPath, path.extname defPath unless definition.id
    definition.role = path.basename defPath, path.extname defPath unless definition.role

    inPorts = definition.inports or {}
    definition.inports = Object.keys(inPorts).map (id) ->
      def = inPorts[id]
      def.id = id
      def
    outPorts = definition.outports or {}
    definition.outports = Object.keys(outPorts).map (id) ->
      def = outPorts[id]
      def.id = id
      def

    messaging = msgflo_nodejs.transport.getClient program.broker
    messaging.connect (err) ->
      return onError err if err
      foreigner.register messaging, definition, (err) ->
        return onError err if err
        onComplete()

exports.main = main
