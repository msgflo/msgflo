fbpspec = require 'fbp-spec'
rt = require './runtime.json'

fbpspec.mocha.run rt, './spec', { starttimeout: null }
