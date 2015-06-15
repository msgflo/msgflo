
msgflo = require '../'

path = require 'path'
chai = require 'chai' unless chai

describe 'Library', ->

  beforeEach (done) ->
    done()
  afterEach (done) ->
    done()

  describe 'component config with variables', ->
    it 'variables are expanded', () ->
      expectedCommands =
        "api/ConvertDocument": "noflo-runtime-msgflo --name #ROLE --graph api/ConvertDocument --prefetch=1 --deadletter=in"
        "api/SendMessageToUser": "noflo-runtime-msgflo --name #ROLE --graph api/SendMessageToUser --prefetch=10"
        "api/PropagateItem": "noflo-runtime-msgflo --name #ROLE --graph api/PropagateItem --prefetch=1 --deadletter propagate,unpropagate"
        "api/Router": "noflo-runtime-msgflo --name #ROLE --graph api/Router --prefetch=1 --deadletter in"
      options =
        configfile: path.join __dirname, 'fixtures', 'library-nontrivial.json'
      lib = new msgflo.library.Library options
      chai.expect(lib.components).to.eql expectedCommands

  describe 'when instantiating component', ->
    it '#ROLE in command is replaced', () ->
      options =
        config:
          components:
            'project/Foo': "msgflo-nodejs --name #ROLE --file api/#COMPONENTNAME.js --option 1"
      lib = new msgflo.library.Library options
      cmd = lib.componentCommand 'project/Foo', 'myrole'
      chai.expect(cmd).to.equal "msgflo-nodejs --name myrole --file api/Foo.js --option 1"






