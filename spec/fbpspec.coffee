fbpspec = require 'fbp-spec'
rt = require './runtime.json'

describe 'fbp-specs', ->
  fbpspec.mocha.run rt, './spec', { starttimeout: null }
