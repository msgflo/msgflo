
# Abstraction of the concrete message queue system used
# Examples: AMQP, MQTT
class MessagingSystem
  constructor: (address) ->

  ## Broker connection management
  connect: (callback) ->
    throw new Error 'Not Implemented'
  disconnect: (callback) ->
    throw new Error 'Not Implemented'

  ## Manipulating queues
  createQueue: (queueName, callback) ->
    throw new Error 'Not Implemented'
  removeQueue: (queueName, callback) ->
    throw new Error 'Not Implemented'

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
    throw new Error 'Not Implemented'
  subscribeToQueue: (queueName, handler, callback) ->
    throw new Error 'Not Implemented'

  ## ACK/NACK messages
  ackMessage: (message) ->
    throw new Error 'Not Implemented'
  nackMessage: (message) ->
    throw new Error 'Not Implemented'

exports.MessageBroker = MessagingSystem
exports.MessagingClient = MessagingSystem
