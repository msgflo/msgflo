
# Abstraction of the concrete message queue system used
# Examples: AMQP, MQTT
class MessagingSystem
  constructor: (address, options) ->

  ## Broker connection management
  connect: (callback) ->
    throw new Error 'Not Implemented'
  disconnect: (callback) ->
    throw new Error 'Not Implemented'

  ## Manipulating queues
  # @type: inqueue|outqueue
  createQueue: (type, queueName, callback) ->
    throw new Error 'Not Implemented'
  removeQueue: (type, queueName, callback) ->
    throw new Error 'Not Implemented'

  ## Sending/Receiving messages
  # queueName must be created beforehand, and be of correct type
  sendToQueue: (queueName, message, callback) ->
    throw new Error 'Not Implemented'
  # handler must call ackMessage() on succesful processing of a message
  subscribeToQueue: (queueName, handler, callback) ->
    throw new Error 'Not Implemented'

  ## ACK/NACK messages
  ackMessage: (message) ->
    throw new Error 'Not Implemented'
  nackMessage: (message) ->
    throw new Error 'Not Implemented'

class MessagingClient extends MessagingSystem

  # Participant registration
  registerParticipant: (part) ->
    throw new Error 'Not Implemented'

exports.MessagingClient = MessagingClient

class MessageBroker extends MessagingSystem

  # Manipulating queue bindings
  # Binding object:
  # {
  #   type: 'roundrobin'|'pubsub'
  #   src: 'source queue'
  #   tgt: 'target queue'
  #   $type: { 'type-specific-bar': 'foo' }
  #   deadletter: 'queue name' # only for roundrobin
  # }
  # Types:
  # pubsub: Messages are delivered to all consumers on queue. (default)
  #              ack/nack does not impact sending
  # roundrobin:  Messages are delivered to one consumer on queue.
  #              If not acked or nacked, put to deadletter
  addBinding: (binding, callback) ->
    throw new Error 'Not Implemented'
  removeBinding: (binding, callback) ->
    throw new Error 'Not Implemented'
  # @callback err, [Binding, Binding, ..]
  listBindings: (callback) ->
    throw new Error 'Not Implemented'

  # Participant registration
  subscribeParticipantChange: (handler) ->
    throw new Error 'Not Implemented'

exports.MessageBroker = MessageBroker
