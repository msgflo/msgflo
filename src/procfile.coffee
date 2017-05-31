program = require 'commander'
fbp = require 'fbp'
path = require 'path'
fs = require 'fs'
library = require './library'
common = require './common'

readGraph = (filepath, callback) ->
  ext = path.extname filepath
  fs.readFile filepath, { encoding: 'utf-8' }, (err, contents) =>
    return callback err if err
    try
      if ext == '.fbp'
        graph = fbp.parse contents
      else
        graph = JSON.parse contents
      return callback null, graph
    catch e
      return callback e


generateWithLibrary = (lib, graph, options) ->
  lines = []
  for name, proc of graph.processes
    continue if name in options.ignore
    component = proc.component
    iips = common.iipsForRole graph, name
    cmd = lib.componentCommand component, name, iips
    lines.push "#{name}: #{cmd}"

  includes = options.include.join '\n'
  out = lines.join '\n'
  return "#{out}\n#{includes}"

# Generating Heroku/foreman Profile definiton
# from a FBP graph definition
exports.generate = generate = (graph, options, callback) ->
  libOptions =
    configfile: options.library
  libOptions.configfile = path.join(process.cwd(), 'package.json') if not libOptions.configfile
  libOptions.componentdir = options.components

  lib = new library.Library libOptions
  lib.load (err) ->
    return callback err if err
    out = generateWithLibrary lib, graph, options
    return callback null, out


exports.parse = parse = (args) ->
  addInclude = (include, list) ->
    list.push include
    return list

  addIgnore = (ignore, list) ->
    list.push ignore
    return list

  graph = null
  program
    .arguments('<graph.fbp/.json>')
    .option('--library <FILE.json>', 'Use FILE.json as the library definition', String, 'package.json')
    .option('--ignore [NODE]', 'Do not generate output for NODE. Can be specified multiple times.', addIgnore, [])
    .option('--include [DATA]', 'Include DATA as-is in generated file. Can be specified multiple times.', addInclude, [])
    .option('--components <DIR>', 'Lookup components from DIR', String, 'participants')
    .action (gr, env) ->
      graph = gr
    .parse args

  program.graphfile = graph
  return program

exports.main = main = () ->
  options = parse process.argv

  if not options.graphfile
    console.error 'ERROR: No graph file specified'
    program.help()
    process.exit()

  callback = (err, out) ->
    throw err if err
    console.log out

    # TODO: support writing directly to Procfile?
  readGraph options.graphfile, (err, graph) ->
    return callback err if err
    generate graph, options, (err, out) ->
      return callback err, out

