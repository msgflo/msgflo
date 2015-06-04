program = require 'commander'
msgflo_nodejs = require 'msgflo-nodejs'

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
  messaging = msgflo_nodejs.transport.getClient program.broker,
    prefetch: 1
  messaging.connect (err) ->
    return onError err if err
    packetsReceived = []

    onResult = (msg) ->
      packetsReceived.push msg.data
      messaging.ackMessage msg
      return unless packetsReceived.length >= program.amount
      if program.amount is 1
        console.log JSON.stringify packetsReceived[0]
      else
        console.log JSON.stringify packetsReceived
      messaging.disconnect (disconnectErr) ->
        return onError disconnectErr if disconnectErr
        onComplete()

    messaging.subscribeToQueue program.queue, onResult, (err) ->
      return onError err if err

exports.main = main
