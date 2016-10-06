
Insights = require 'node-insights'
async = require 'async'

getJobStats = (options, app, callback) ->

  insights = new Insights options
  return callback new Error 'Missing app name' if not app

  limit = 100 # maximum number of role supported
  q = "SELECT average(duration), stddev(duration), percentile(duration, 90) FROM MsgfloJobCompleted FACET role SINCE #{options.since} ago WHERE outport != 'error' AND appName = '#{app}' LIMIT #{limit}"
  insights.query q, (err, body) ->
    return callback err if err
    return callback new Error "newrelic: No facets was returned in query" if not body.facets?.length

    results = {}
    for facet in body.facets
      out = results[facet.name] = {}

      for res in facet.results
        out['average'] = res['average']/1000 if res['average']?
        out['stddev'] = res['standardDeviation']/1000 if res['standardDeviation']?
        out['percentile'] = res['percentile']/1000 if res['percentile']?
    return callback null, results

getJobStatsApps = (options, apps, callback) ->
  getStats = (app, cb) ->
    return getJobStats options, app, cb

  async.map apps, getStats, (err, resultList) ->
    return callback err if err
    res = {}
    for obj in resultList
      for k, v of obj
        res[k] = v
    return callback null, res

parse = (args) ->
  addApp = (app, list) ->
    list.push app
    return list

  program = require 'commander'
  program
    .option('--query-key <hostname>', 'Query Key to access New Relic Insights API', String, '')
    .option('--account-id <port>', 'Account ID used to access New Relic Insights API', String, '')
    .option('--app <app>', 'App name in New Relic. Can be specified multiple times', addApp, [])
    .option('--since <datetime>', 'Timeperiod to extract metrics for', String, '1 week')
    .parse(args)

normalize = (options) ->
  options.accountId = process.env.NEW_RELIC_ACCOUNT_ID if not options.accountId
  options.queryKey = process.env.NEW_RELIC_QUERY_KEY if not options.queryKey
  options.app = [ options.app ] if typeof options.app == 'string'
  return options

exports.main = main = () ->
  options = parse process.argv
  options = normalize options

  getJobStatsApps options, options.app, (err, results) ->
    throw err if err
    console.log JSON.stringify(results, null, 2)


main() if not module.parent

