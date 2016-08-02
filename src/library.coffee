
fs = require 'fs'
path = require 'path'
debug = require('debug')('msgflo:library')

common = require './common'

replaceMarker = (str, marker, value) ->
  marker = '#'+marker.toUpperCase()
  str.replace(new RegExp(marker,  'g'), value)

exports.replaceVariables = replaceVariables = (str, variables) ->
  for marker, value of variables
    str = replaceMarker str, marker, value
  return str

baseComponentCommand = (config, component, cmd) ->
  variables = common.clone config.variables
  componentName = component.split('/')[1]
  componentName = component if not componentName
  variables['COMPONENTNAME'] = componentName
  variables['COMPONENT'] = component
  return replaceVariables cmd, variables

componentCommandForFile = (config, filename) ->
  ext = path.extname filename
  component = path.basename filename, ext
  cmd = config.handlers[ext]
  return baseComponentCommand config, component, cmd

componentsFromConfig = (config) ->
  components = {}
  for component, cmd of config.components
    components[component] = baseComponentCommand config, component, cmd
  return components

componentsFromDirectory = (directory, config, callback) ->
  components = {}
  extensions = Object.keys config.handlers
  fs.exists directory, (exists) ->
    return callback null, {} if not exists

    fs.readdir directory, (err, filenames) ->
      return callback err if err
      supported = filenames.filter (f) -> path.extname(f) in extensions
      unsupported = filenames.filter (f) -> not (path.extname(f) in extensions)
      debug 'unsupported component files', unsupported if unsupported.length
      for filename in supported
        component = path.basename(filename, path.extname(filename))
        debug 'loading component from file', filename, component
        components[component] = componentCommandForFile config, filename

      return callback null, components

# TODO: also add msgflo-python
defaultHandlers =
  ".yml":     "msgflo-register-foreign --role #ROLE participants/#COMPONENT.yml"
  ".js":      "msgflo-nodejs --name #ROLE participants/#COMPONENT.js"
  ".coffee":  "msgflo-nodejs --name #ROLE participants/#COMPONENT.coffee"
  ".json":    "noflo-runtime-msgflo --name #ROLE --graph #COMPONENT --iips #IIPS"
  ".fbp":     "noflo-runtime-msgflo --name #ROLE --graph #COMPONENT --iips #IIPS"

languageExtensions =
  'python': 'py'
  'coffeescript': 'coffee'
  'javascript': 'js'
  'yaml': 'yml'

normalizeConfig = (config) ->
  config = {} if not config
  config = config.msgflo if config.msgflo # Migth be under a .msgflo key, for instance in package.json

  config.components = {} if not config.components
  config.variables = {} if not config.variables
  config.handlers = {} if not config.handlers

  for k, v of defaultHandlers
    config.handlers[k] = defaultHandlers[k] if not config.handlers[k]

  return config

class Library
  constructor: (options) ->
    options.config = JSON.parse(fs.readFileSync options.configfile, 'utf-8') if options.configfile
    options.componentdir = 'participants' if not options.componentdir
    options.config = normalizeConfig options.config
    @options = options

    @components = {} # lazy-loaded using load()

  load: (callback) ->
    componentsFromDirectory @options.componentdir, @options.config, (err, components) =>
      return callback err if err
      for k,v of components
        @components[k] = v
      for k,v of componentsFromConfig @options.config
        @components[k] = v
      return callback null

  addComponent: (name, language, code, callback) ->
    debug 'adding component', name, language
    ext = languageExtensions[language]
    ext = ext or language  # default to input lang for open-ended extensibility
    name = path.basename name # TODO: support multiple libraries?
    filename = path.join @options.componentdir, "#{name}.#{ext}"

    fs.writeFile filename, code, (err) =>
      return callback err if err
      @components[name] = componentCommandForFile @options.config, filename
      return callback null

  componentCommand: (component, role, iips={}) ->
    cmd = @components[component]
    throw new Error "No component #{component} defined for role #{role}" if not cmd

    vars =
      'ROLE': role
      'IIPS': "'#{JSON.stringify(iips)}'"
    cmd = replaceVariables cmd, vars
    return cmd

exports.Library = Library
