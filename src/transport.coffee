
transports =
  amqp: require './amqp'
  mqtt: require './mqtt'
  direct: require './direct'

supportsScheme = (scheme) ->
  return scheme in Object.keys transports

exports.getClient = (address, options) ->
  scheme = address.split('://')[0]
  throw new Error 'Unsupported scheme: ' + scheme if not supportsScheme scheme
  return new transports[scheme].Client address, options

exports.getBroker = (address, options) ->
  scheme = address.split('://')[0]
  throw new Error 'Unsupported scheme: ' + scheme if not supportsScheme scheme
  return new transports[scheme].MessageBroker address, options
