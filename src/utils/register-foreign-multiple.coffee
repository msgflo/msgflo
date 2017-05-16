program = require 'commander'
msgflo_nodejs = require 'msgflo-nodejs'
fs = require 'fs'
path = require 'path'
foreigner = require '../foreign-participant'
common = require '../common'
yaml = require 'js-yaml'
Promise = require 'bluebird'

onError = (err) ->
  console.log err
  process.exit 1

onComplete = ->
  process.exit 0

collectMap = (val, map) ->
  [role, definition] = val.split ':'
  map[role] = definition
  return map

main = ->
  program
    .option('--broker <uri>', 'Broker address', String, '')
    .option('--role <role:definition>', 'Map of roles and definition files', collectMap, {})
    .option('--interval <SECONDS>', 'How often to send discovery message', Number, 60)
    .option('--forever <true>', 'Keep running forever', Boolean, true)
    .usage('[options]')
    .parse(process.argv)
  program = common.normalizeOptions program
  program.roles = program.role

  readFile = Promise.promisify fs.readFile
  messaging = msgflo_nodejs.transport.getClient program.broker
  register = Promise.promisify foreigner.register.bind foreigner
  Promise.map Object.keys(program.roles), (role) ->
    defPath = path.resolve process.cwd(), program.roles[role]
    readFile defPath, 'utf-8'
    .then (contents) ->
      return Promise.reject "No definition found in #{defPath}" unless contents
      definition = yaml.safeLoad contents
      return Promise.reject new Error ".component is not defined" unless definition.component
      definition.role = role
      definition.id = definition.role unless definition.id
      definition = foreigner.mapPorts definition
      Promise.resolve definition
  .then (definitions) ->
    connect = Promise.promisify messaging.connect.bind messaging
    connect()
    .then ->
      Promise.map definitions, (definition) ->
        register messaging, definition
        .then ->
          console.log 'Sent discovery message for', definition.id
          Promise.resolve definition
  .then (definitions) ->
    onComplete() unless program.forever
    setInterval ->
      Promise.map definitions, (definition) ->
        register messaging, definition
      .asCallback (err) ->
        console.log 'Warning: Failed to send discovery message:', err if err
    , program.interval*1000/2.2

exports.main = main
