program = require 'commander'
msgflo_nodejs = require 'msgflo-nodejs'

common = require '../common'

parse = (args) ->
  program
    .option('--broker <uri>', 'Broker address', String, '')
    .option('--queue <name>', 'Queue to dump messages from', String, '')
    .option('--json <JSONDATA>', 'Data to send. Must be valid JSON', String, '')
    .parse(args)

normalize = (options) ->
  options = common.normalizeOptions options
  return options

validate = (options) ->
  throw new Error 'Missing queue to send to (--queue)' if not options.queue
  throw new Error 'Missing message payload (--json)' if not options.json

  try
    data = JSON.parse options.json
  catch e
    e.message = 'Invalid JSON: ' + e.message
    throw e

  return data

sendData = (options, data, callback) ->
  client = msgflo_nodejs.transport.getClient program.broker
  client.connect (err) ->
    return callback err if err

    client.sendTo 'inqueue', options.queue, data, (err) ->
      return callback err if err

      client.disconnect (err) ->
        # ignore error, we sent succesfully anyways
        return callback null

exports.main = ->

  options = parse process.argv
  options = normalize options

  try
    data = validate options
  catch e
    console.log e.message
    process.exit 1

  sendData options, data, (err) ->
    throw err if err

