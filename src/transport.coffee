
transports =
  amqp: require './amqp'
  direct: require './direct'

supportsScheme = (scheme) ->
  return scheme in Object.keys transports

exports.getClient = (address) ->
  scheme = address.split('://')[0]
  throw new Error 'Unsupported scheme: ' + scheme if not supportsScheme scheme
  return new transports[scheme].Client address

exports.getBroker = (address) ->
  scheme = address.split('://')[0]
  throw new Error 'Unsupported scheme: ' + scheme if not supportsScheme scheme
  return new transports[scheme].MessageBroker address
