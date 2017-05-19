chai = require 'chai'
exec = require('child_process').exec
path = require 'path'
msgfloNodejs = require 'msgflo-nodejs'

msgflo_register = (broker, args, callback) ->
  script = path.join __dirname, '../bin', 'msgflo-register'
  cmd = "MSGFLO_BROKER=#{broker} #{script} #{args}"
  console.log 'running', cmd
  exec cmd, callback

describe 'msgflo-register', ->
  brokerAddress = 'mqtt://localhost'
  broker = msgfloNodejs.transport.getBroker brokerAddress
  before (done) ->
    broker.connect done
  after (done) ->
    broker.disconnect done

  describe "with a single role", ->
    it 'sends discovery messages on starting', (done) ->
      @timeout 4000

      role = 'switch1'

      broker.subscribeParticipantChange (msg) ->
        broker.ackMessage msg
        d = msg.data
        chai.expect(d).to.have.keys ['protocol', 'command', 'payload']
        chai.expect(d.protocol).to.equal 'discovery'
        chai.expect(d.command).to.equal 'participant'
        p = d.payload
        chai.expect(p).to.include.keys ['id', 'role', 'component', 'inports', 'outports']
        chai.expect(p).to.include.keys ['label', 'icon'] # optional
        chai.expect(p.id).to.be.a 'string'
        chai.expect(p.id).to.have.length.above 5
        chai.expect(p.role).to.equal role
        chai.expect(p.component).to.equal 'my/ToggleSwitch'
        chai.expect(p.outports).to.have.length 1
        port = p.outports[0]
        chai.expect(port).to.include.keys ['id', 'queue', 'type']
        chai.expect(port.queue).to.contain role
        chai.expect(port.queue).to.contain '/myswitch'
        return done null

      ymlFile = path.join __dirname, 'fixtures', 'toggleswitch.yaml'
      options = "--forever=false --role #{role}:#{ymlFile}"
      msgflo_register brokerAddress, options, (err, stdout, stderr) ->
        console.log 'e', err, stdout, stderr
        chai.expect(err).to.not.exist
        chai.expect(stdout).to.contain 'Sent discovery message for'
