
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
debug = require('debug')('msgflo:library')
EventEmitter = require('events').EventEmitter

common = require './common'

defaultHandlers =
  ".yml":     "msgflo-register --role #ROLE:#FILENAME"
  ".js":      "msgflo-nodejs --name #ROLE #FILENAME"
  ".coffee":  "msgflo-nodejs --name #ROLE #FILENAME"
  ".py":  "msgflo-python #FILENAME #ROLE"
  ".json":    "noflo-runtime-msgflo --name #ROLE --graph #COMPONENT --iips #IIPS"
  ".fbp":     "noflo-runtime-msgflo --name #ROLE --graph #COMPONENT --iips #IIPS"

languageExtensions =
  'python': 'py'
  'coffeescript': 'coffee'
  'javascript': 'js'
  'c++': 'cpp'
  'rust': 'rs'
  'yaml': 'yml'
extensionToLanguage = {}
for lang, ext of languageExtensions
  extensionToLanguage[".#{ext}"] = lang

replaceMarker = (str, marker, value) ->
  marker = '#'+marker.toUpperCase()
  str.replace(new RegExp(marker,  'g'), value)

exports.replaceVariables = replaceVariables = (str, variables) ->
  for marker, value of variables
    str = replaceMarker str, marker, value
  return str

baseComponentCommand = (config, component, cmd, filename) ->
  variables = common.clone config.variables
  componentName = component.split('/')[1]
  componentName = component if not componentName
  variables['FILENAME'] = filename if filename
  variables['COMPONENTNAME'] = componentName
  variables['COMPONENT'] = component
  return replaceVariables cmd, variables

componentCommandForFile = (config, filename) ->
  ext = path.extname filename
  component = path.basename filename, ext
  cmd = config.handlers[ext]
  return baseComponentCommand config, component, cmd, filename

componentsFromConfig = (config) ->
  components = {}
  for component, cmd of config.components
    components[component] =
      language: null # XXX: Could try to guess from cmd/template??
      command: baseComponentCommand config, component, cmd
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
        ext = path.extname filename
        lang = extensionToLanguage[ext]
        component = path.basename(filename, ext)
        if config.namespace
          component = "#{config.namespace}/#{component}"
        debug 'loading component from file', filename, component
        filepath = path.join directory, filename
        components[component] =
          language: lang
          command: componentCommandForFile config, filepath

      return callback null, components

normalizeConfig = (config) ->
  config = {} if not config
  namespace = config.name or null
  repository = config.repository
  if config.repository?.url
    # package.json convention
    repository = config.repository.url
  config = config.msgflo if config.msgflo # Migth be under a .msgflo key, for instance in package.json

  config.repository = repository unless typeof config.repository is 'string'
  config.namespace = namespace if not config.namespace?
  config.components = {} if not config.components
  config.variables = {} if not config.variables
  config.handlers = {} if not config.handlers

  for k, v of defaultHandlers
    config.handlers[k] = defaultHandlers[k] if not config.handlers[k]

  return config

# Remove instance-specific data like role and extra from library data
cleanComponentDefinition = (discovered) ->
  return discovered unless discovered?.definition
  # Start by cloning the definition
  component = common.clone discovered
  return component unless component?.definition
  delete component.definition.extra
  delete component.definition.id
  delete component.definition.role
  for port in component.definition.inports
    delete port.queue
  for port in component.definition.outports
    delete port.queue
  return component

class Library extends EventEmitter
  constructor: (options) ->
    options.config = JSON.parse(fs.readFileSync options.configfile, 'utf-8') if options.configfile
    if not options.componentdir
      console.log 'WARNING:', 'Default components directory for MsgFlo will change to "components" in next release'
      options.componentdir = 'participants'
    options.config = normalizeConfig options.config
    @options = options

    @components = {} # "name" -> { command: "", language: ''|null }.  lazy-loaded using load()

  getComponent: (name) ->
    # Direct match
    return @components[name] if @components[name]
    withoutNamespace = path.basename name
    return @components[withoutNamespace] if @components[withoutNamespace]
    if name.indexOf '/' == -1 and @options.config.namespace
      withNamespace = @options.config.namespace + '/' + name
      return @components[withNamespace] if @components[withNamespace]
    return null

  _updateComponents: (components) ->
    names = []
    for name, comp of components
      if not comp
        # removed
        @components[name] = null
        names.push name if names.indexOf(name) is -1
        continue
      discovered = cleanComponentDefinition comp
      existing = @getComponent name
      unless existing
        # added
        @components[name] = discovered
        names.push name if names.indexOf(name) is -1
        continue
      unless JSON.stringify(existing.definition) is JSON.stringify(discovered.definition)
        # updated
        for k, v of discovered
          @components[name][k] = v
        names.push name if names.indexOf(name) is -1
        continue

    # Send components-changed only if something changed
    if names.length
      @emit 'components-changed', names, @components

  load: (callback) ->
    componentsFromDirectory @options.componentdir, @options.config, (err, components) =>
      return callback err if err
      @_updateComponents components
      @_updateComponents componentsFromConfig(@options.config)
      return callback null

  # call when MsgFlo discovery message has come in
  _updateDefinition: (name, def) ->
    return if not def # Ignore participants being removed
    changes = {}
    changes[name] =
      definition: def
    @_updateComponents changes

  getSource: (name, callback) ->
    debug 'requesting component source', name
    component = @getComponent name
    return callback new Error "Component not found for #{name}" unless component

    basename = name
    library = null
    if name.indexOf('/') isnt -1
      # FBP protocol component:getsource unfortunately bakes in library in this case
      [library, basename] = name.split '/'
    else if @options.config?.namespace?
      library = @options.config?.namespace

    unless component.language
      # Component that doesn't come from handlers, send discovery info since source isn't available
      debug 'component without source', name, component.command
      source =
        name: basename
        library: library
        code: yaml.safeDump component.definition or {}
        language: 'discovery'
      return callback null, source

    lang = component.language
    ext = languageExtensions[lang]
    filename = path.join @options.componentdir, "#{basename}.#{ext}"
    fs.readFile filename, 'utf-8', (err, code) ->
      debug 'component source file', filename, lang, err
      return callback new Error "Could not find component source for #{name}: #{err.message}" if err
      source =
        name: basename
        library: library
        code: code
        language: component.language
      return callback null, source

  addComponent: (name, language, code, callback) ->
    debug 'adding component', name, language
    ext = languageExtensions[language]
    ext = ext or language  # default to input lang for open-ended extensibility
    filename = path.join @options.componentdir, "#{path.basename(name)}.#{ext}"

    if name.indexOf('/') == -1 and @options.config?.namespace
      name = "#{@options.config.namespace}/#{name}"

    fs.writeFile filename, code, (err) =>
      return callback err if err
      changes = {}
      changes[name] =
        language: language
        command: componentCommandForFile @options.config, filename
      @_updateComponents changes
      return callback null

  componentCommand: (component, role, iips={}) ->
    cmd = @getComponent(component)?.command
    throw new Error "No component #{component} defined for role #{role}" if not cmd

    vars =
      'ROLE': role
      'IIPS': "'#{JSON.stringify(iips)}'"
    cmd = replaceVariables cmd, vars
    return cmd

exports.Library = Library
