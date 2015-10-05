
msgflo = require 'msgflo-nodejs'

# Emulate a physical toggle switch
# Sends a boolean. Switches between on and off every second
class Switch
  constructor: (address) ->
    @client = msgflo.transport.getClient address
    @timer = null
    @status = true
    @topic = '/myswitch/baar/1/status'

  start: (callback) ->
    sendStatus = () =>
      @status = not @status # toggle
      @client.sendTo 'outqueue', @topic, @status, () ->

    @client.connect (err) =>
      return callback err if err

      @client.createQueue 'outqueue', @topic, (err) =>
        return callback err if err
        @timer = setInterval sendStatus, 1000
        return callback null

  stop: (callback) ->
    clearInterval @timer if @timer
    @client.removeQueue 'outqueue', @topic, (err) =>
      return @client.disconnect callback

# Emulate a physical lightbubl
# Takes a boolean on/off signal
class LightBulb
  constructor: (address) ->
    @client = msgflo.transport.getClient address
    @intopic = '/mylightbulb/ffo/1/set-on'
    @outtopic = '/mylightbulb/ffo/1/is-on'

  start: (callback) ->
    onInput = (message) =>
      state = if message then 'ON' else 'OFF'
      console.log "turning lightbulb #{state}" 
      @client.sendTo 'outqueue', @outtopic, message, () ->

    @client.connect (err) =>
      return callback err if err

      @client.createQueue 'outqueue', @outtopic, (err) =>
        return callback err if err
        @client.createQueue 'inqueue', @intopic, (err) =>
          return callback err if err

          @client.subscribeToQueue @intopic, onInput, callback

  stop: (callback) ->
    clearInterval @timer if @timer
    @client.removeQueue 'outqueue', @topic, (err) =>
      return @client.disconnect callback

exports.LightBulb = LightBulb
exports.ToggleSwitch = Switch

exports.sendDeclarations = (address, callback) ->
  # TODO: use the foreign participants declaration tool
  lightbulb =
    component: 'my/LightBulb'
    icon: 'file-word-o'
    role: 'mybulb'
    label: 'A lightbubl that can be on or off'
    inports: [
      id: 'enable'
      type: 'boolean'
      description: ''
      queue: '/mylightbulb/ffo/1/set-on'
    ]
    outports: [
      id: 'confirm'
      type: 'boolean'
      description: 'ff'
      queue: '/mylightbulb/ffo/1/is-on'
    ]
  toggleswitch =
    component: 'my/ToggleSwitch'
    role: 'myswitch'
    icon: 'file-word-o'
    label: 'A toggle switch which can turn things on or off'
    inports: []
    outports: [
      id: 'state'
      type: 'boolean'
      description: 'ff'
      queue: '/myswitch/baar/1/status'
    ]

  client = msgflo.transport.getClient address
  client.connect (err) ->
    return callback err if err
    client.registerParticipant lightbulb, (err) ->
      return callback err if err
      client.registerParticipant toggleswitch, (err) ->
        return callback err if err
        client.disconnect callback

