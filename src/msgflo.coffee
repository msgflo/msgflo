
runtime = require '../src/runtime'

## Main
program = require 'commander'

main = () ->
  program
    .option('--host <hostname>', 'Host', String, 'localhost')
    .option('--port <port>', 'Port', Number, 3569)
    .option('--broker <uri>', 'Broker address', String, 'amqp://localhost')
    .parse(process.argv);

  r = new runtime.Runtime program
  r.start (err, address) ->
    throw err if err
    console.log "msgflo started on #{address}"

exports.main = main
