
runtime = require '../src/runtime'

## Main
program = require 'commander'

main = () ->
  program
    .option('--host <hostname>', 'Host', String, 'localhost')
    .option('--port <port>', 'Port', Number, 3569)
    .option('--broker <uri>', 'Broker address', String, 'amqp://localhost')
    .option('--ide <uri>', 'FBP IDE address', String, 'http://app.flowhub.io')
    .option('--graph <file.json>', 'Initial graph to load', String, '')
    .parse(process.argv)

  r = new runtime.Runtime program
  r.start (err, address, liveUrl) ->
    throw err if err
    console.log "msgflo started on #{address}"
    console.log 'Open in Flowhub: ' + liveUrl

exports.main = main
exports.transport = require('msgflo-nodejs').transport
exports.participant = require('msgflo-nodejs').participant
exports.foreignParticipant = require '../src/foreign-participant'

exports.coordinator = require '../src/coordinator'
exports.runtime = require '../src/runtime'
exports.common = require '../src/common'
exports.setup = require '../src/setup'
exports.library = require '../src/library'
exports.procfile = require '../src/procfile'
exports.utils =
  spy: require '../src/utils/spy'
