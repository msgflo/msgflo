program = require 'commander'
msgflo = require '../msgflo'

onError = (err) ->
  console.log err
  process.exit 1

onComplete = ->
  process.exit 0

main = ->
  program
    .option('--broker <uri>', 'Broker address', String, 'amqp://localhost')
    .option('--queue <name>', 'Queue to dump messages from', String, '')
    .option('--amount <number>', 'How many messages to dump', Number, 1)
    .parse(process.argv)

  received = 0
  messaging = msgflo.transport.getClient program.broker,
    prefetch: 1
  messaging.connect (err) ->
    return onError err if err

    onResult = (msg) ->
      console.log JSON.stringify msg.data
      received++
      messaging.ackMessage msg
      return unless received >= program.amount
      messaging.disconnect (disconnectErr) ->
        return onError disconnectErr if disconnectErr
        onComplete()

    messaging.subscribeToQueue program.queue, onResult, (err) ->
      return onError err if err

exports.main = main
