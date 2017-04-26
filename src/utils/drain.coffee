msgflo_nodejs = require 'msgflo-nodejs'

exports.drainQueue = (broker, queue, callback) ->
  messaging = msgflo_nodejs.transport.getClient broker,
    prefetch: 1
  timeout = 1000
  messaging.connect (err) ->
    return callback err if err
    messaging.subscribeToQueue queue, (msg) ->
      # Just drop all messages
      messaging.ackMessage msg
    , (err) ->
      return callback err if err
      # Wait until timeout so we can drain the queue
      setTimeout ->
        messaging.disconnect (err) ->
          messaging = null
          callback err
        return
      , timeout
