module.exports = ->
  # Project configuration
  @initConfig
    pkg: @file.readJSON 'package.json'

    # BDD tests on Node.js
    mochaTest:
      nodejs:
        src: ['spec/*.coffee']
        options:
          reporter: 'spec'
          grep: process.env.TESTS

    # Coding standards
    coffeelint:
      components:
        files:
          src: ['spec/*.coffee', 'src/*.coffee', 'src/runtimes/*.coffee', 'src/utils/*.coffee']
        options:
          max_line_length:
            value: 100
            level: 'warn'

    # Protocol tests
    shell:
      msgflo:
        command: 'node bin/msgflo'
        options:
          async: true
      fbp_test:
        command: 'fbp-test --colors'

    # Building the website
    jekyll:
      options:
        src: 'site/'
        dest: 'dist/'
        bundleExec: true
      dist:
        options:
          dest: 'dist/'
      serve:
        options:
          dest: 'dist/'
          serve: true
          watch: true
          host: process.env.HOSTNAME or 'localhost'
          port: process.env.PORT or 4000

  # Grunt plugins used for building
  @loadNpmTasks 'grunt-jekyll'

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'
  @loadNpmTasks 'grunt-shell-spawn'

  # Our local tasks
  @registerTask 'fbp-test', [
    'shell:msgflo'
    'shell:fbp_test'
    'shell:msgflo:kill'
  ]

  @registerTask 'test', 'Build and run automated tests', (target = 'all') =>
    @task.run 'coffeelint'
    @task.run 'mochaTest'
    @task.run 'jekyll:dist'
#    @task.run 'fbp-test'

  @registerTask 'default', ['test']
