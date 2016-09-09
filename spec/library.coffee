
msgflo = require '../'

path = require 'path'
chai = require 'chai' unless chai

describe 'Library', ->

  beforeEach (done) ->
    done()
  afterEach (done) ->
    done()

  describe 'component config with variables', ->
    it 'variables are expanded', (done) ->
      expectedCommands =
        "api/ConvertDocument": "noflo-runtime-msgflo --name #ROLE --graph api/ConvertDocument --prefetch=1 --deadletter=in"
        "api/SendMessageToUser": "noflo-runtime-msgflo --name #ROLE --graph api/SendMessageToUser --prefetch=10"
        "api/PropagateItem": "noflo-runtime-msgflo --name #ROLE --graph api/PropagateItem --prefetch=1 --deadletter propagate,unpropagate"
        "api/Router": "noflo-runtime-msgflo --name #ROLE --graph api/Router --prefetch=1 --deadletter in"
      options =
        configfile: path.join __dirname, 'fixtures', 'library-nontrivial.json'
      lib = new msgflo.library.Library options
      lib.load (err) ->
        return done err if err
        commands = {}
        for k,v of lib.components
          commands[k] = v.command
        chai.expect(commands).to.eql expectedCommands
        done()

  describe 'components on disk with default handlers', ->
    it 'both config and disk components exists', (done) ->
      options =
        configfile: path.join __dirname, 'fixtures', 'library-nontrivial.json'
        componentdir: path.join __dirname, 'fixtures'
      lib = new msgflo.library.Library options
      lib.load (err) ->
        return done err if err
        chai.expect(lib.components).to.include.keys ['api/ConvertDocument', 'api/Router']
        chai.expect(lib.components).to.include.keys ['participants']
        done()

  describe 'when instantiating component', ->
    it '#ROLE in command is replaced', (done) ->
      options =
        config:
          components:
            'project/Foo': "msgflo-nodejs --name #ROLE --file api/#COMPONENTNAME.js --option 1"
      lib = new msgflo.library.Library options
      lib.load (err) ->
        return done err if err
        cmd = lib.componentCommand 'project/Foo', 'myrole'
        chai.expect(cmd).to.equal "msgflo-nodejs --name myrole --file api/Foo.js --option 1"
        done()

    it '#IIPS in command is replaced', (done) ->
      options =
        config:
          components:
            'project/Foo': "msgflo-nodejs --name #ROLE --file api/#COMPONENTNAME.js --option 1 --iips #IIPS"
      lib = new msgflo.library.Library options
      lib.load (err) ->
        return done err if err
        cmd = lib.componentCommand 'project/Foo', 'myrole', { 'portA': 'valueA', 'portB': 3.14 }
        chai.expect(cmd).to.equal "msgflo-nodejs --name myrole --file api/Foo.js --option 1 --iips '{\"portA\":\"valueA\",\"portB\":3.14}'"
        done()
