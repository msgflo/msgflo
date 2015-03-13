
chai = require 'chai' unless chai
path = require 'path'
http = require 'http'

Runtime = require('../src/runtime').Runtime

describe 'Runtime', ->
  runtime = null

  beforeEach (done) ->
    options =
      broker: 'direct://broker111'
      port: 3333
      ide: 'http://localhost'
      host: 'localhost'
    runtime = new Runtime options
    runtime.start (err, url) ->
      chai.expect(err).to.be.a 'null'
      done()
  afterEach (done) ->
    runtime.stop () ->
      runtime = null
      done()

  describe 'starting runtime', ->
    it 'should provide HTTP webpage', (done) ->
      @timeout 20000
      http.get 'http://localhost:3333/', (res) ->
        body = ""
        chai.expect(res.statusCode).to.equal 200
        res.on 'data', (chunk) ->
          body += chunk.toString()
        res.on 'end', () ->
          chai.expect(body).to.contain 'flowhub_url'
          done()
          

