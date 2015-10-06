
Insights = require 'node-insights'
  

getJobStats = (options, callback) ->

  insights = new Insights options
  app = options.app
  return callback new Error 'Missing app name' if not app

  q = "SELECT average(duration), stddev(duration), percentile(duration, 90) FROM MsgfloJobCompleted FACET role SINCE 1 week ago WHERE outport != 'error' AND appName = '#{options.app}'"
  insights.query q, (err, body) ->
    return callback err if err

    results = {}
    for facet in body.facets
      out = results[facet.name] = {}

      for res in facet.results
        out['average'] = res['average']/1000 if res['average']?
        out['stddev'] = res['standardDeviation']/1000 if res['standardDeviation']?
        out['percentile'] = res['percentile']/1000 if res['percentile']?
    return callback null, results

parse = (args) ->
  program = require 'commander'
  program
    .option('--query-key <hostname>', 'Query Key to access New Relic Insights API', String, '')
    .option('--account-id <port>', 'Account ID used to access New Relic Insights API', String, '')
    .option('--app <app>', 'App name in New Relic', String, '')
    .parse(args)

normalize = (options) ->
  options.accountId = process.env.NEW_RELIC_ACCOUNT_ID if not options.accountId
  options.queryKey = process.env.NEW_RELIC_QUERY_KEY if not options.queryKey
  return options

exports.main = main = () ->
  options = parse process.argv
  options = normalize options

  getJobStats options, (err, results) ->
    throw err if err
    console.log JSON.stringify(results, null, 2)


main() if not module.parent

 
# you can construct NRQL from objects using a similar pattern to Rails ActiveRecord, etc.
###
var q = { select : 'count(*)', from: 'PageView',
          where  : { userAgentOS: ['Windows', 'Mac'] },
          since  : '1 day ago', facet: 'countryCode'};
 
 
// nrql == "SELECT count(*) FROM PageView WHERE userAgentOs IN ('Windows', 'Mac') SINCE 1 day ago FACET countryCode"
var nrql = insights.nrql(q);
 
// will generate nrql from q and run normally
insights.query(q, function(err, responseBody) {
    // ...
})
###
