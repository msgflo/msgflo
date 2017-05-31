chai = require 'chai'
exec = require('child_process').exec
path = require 'path'

msgflo_procfile = (fixture, options, callback) ->
  script = path.join __dirname, '../bin', 'msgflo-procfile'
  graph = path.join __dirname, 'fixtures', fixture
  cmd = "#{script} #{graph} #{options}"
  exec cmd, callback

describe 'msgflo-procfile', ->

  describe "correct imgflo-server.fbp", ->
    it 'outputs a Procfile to stdout', (done) ->
      @timeout 4000
      expected = """
      imgflo_worker: node worker.js --name imgflo_worker
      web: node index.js
      
      """
      lib = path.join __dirname, 'fixtures', 'library-imgflo.json'
      options = "--components participants --library #{lib} --ignore=imgflo_jobs --ignore=imgflo_api --ignore drop --include 'web: node index.js'"
      msgflo_procfile 'imgflo-server.fbp', options, (err, stdout) ->
        chai.expect(err).to.not.exist
        chai.expect(stdout).to.equal expected
        done()

  describe ".fbp with IIPs", ->
    it 'outputs a Procfile to stdout', (done) ->
      @timeout 4000
      expected = """
      fast: node ./node_modules/.bin/noflo-runtime-msgflo --name fast --graph api/Worker --cache true --iips '{\"port\":\"8082\"}' --prefetch 1
      slow: node ./node_modules/.bin/noflo-runtime-msgflo --name slow --graph api/Worker --cache true --iips '{\"port\":\"8081\"}' --prefetch 1
      web: node index.js
      
      """
      lib = path.join __dirname, 'fixtures', 'library-noflo.json'
      options = "--library #{lib} --ignore web --include 'web: node index.js'"
      msgflo_procfile 'iips.fbp', options, (err, stdout) ->
        chai.expect(err).to.not.exist
        chai.expect(stdout).to.equal expected
        done()

  describe "missing component in library", ->
    it 'should error with helpful message', (done) ->
      @timeout 4000
      options = "--components participants --ignore=imgflo_jobs --ignore=imgflo_api --ignore drop --include 'web: node index.js'"
      msgflo_procfile 'imgflo-server.fbp', options, (err, stdout, stderr) ->
        chai.expect(err).to.exist
        chai.expect(stderr).to.contain 'No component'
        chai.expect(stderr).to.contain 'imgflo-server/ProcessImage'
        chai.expect(stderr).to.contain 'imgflo_worker'
        done()

  describe "non-prefixed component with handlers", ->
    it 'outputs a Procfile to stdout', (done) ->
      @timeout 10*1000
      lib = path.join __dirname, 'fixtures', 'library-handlers.json'
      componentdir = path.join __dirname, 'fixtures'
      options = "--library=#{lib} --components=#{componentdir} --include 'web: node index.js'"
      msgflo_procfile 'handlers.fbp', options, (err, stdout, stderr) ->
        chai.expect(err).to.not.exist
        chai.expect(stdout).to.contain 'msgflo-nodejs'
        chai.expect(stdout).to.contain 'ProduceFoo'
        chai.expect(stdout).to.contain 'foo'
        done()

