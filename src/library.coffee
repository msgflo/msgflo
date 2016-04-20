
fs = require 'fs'

replaceMarker = (str, marker, value) ->
  marker = '#'+marker.toUpperCase()
  str.replace(marker, value)

replaceVariables = (str, variables) ->
  for marker, value of variables
    str = replaceMarker str, marker, value
  return str

componentsFromConfig = (config) ->
  variables = config.variables or {}
  config.components = {} if not config.components

  components = {}
  for component, cmd of config.components
    componentName = component.split('/')[1]
    componentName = component if not componentName
    variables['COMPONENTNAME'] = componentName
    variables['COMPONENT'] = component

    components[component] = replaceVariables cmd, variables
  return components

class Library
  constructor: (options) ->
    options.config = JSON.parse(fs.readFileSync options.configfile, 'utf-8') if options.configfile
    options.config = {} if not options.config
    options.config = options.config.msgflo if options.config.msgflo
    @options = options

    @components = componentsFromConfig options.config

  componentCommand: (component, role, iips={}) ->
    cmd = @components[component]
    throw new Error "No component #{component} defined for role #{role}" if not cmd

    vars =
      'ROLE': role
      'IIPS': "'#{JSON.stringify(iips)}'"
    cmd = replaceVariables cmd, vars
    return cmd

exports.Library = Library
