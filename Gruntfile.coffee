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

    # Coding standards
    coffeelint:
      components:
        files:
          src: ['spec/*.coffee', 'src/*.coffee', 'src/runtimes/*.coffee']
        options:
          max_line_length:
            value: 80
            level: 'warn'

    # Protocol tests
    shell:
      msgflo:
        command: 'node bin/msgflo'
        options:
          async: true
      fbp_test:
        command: 'fbp-test --colors'


  # Grunt plugins used for building

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'
  @loadNpmTasks 'grunt-contrib-watch'
  @loadNpmTasks 'grunt-shell-spawn'

  # Our local tasks
  @registerTask 'fbp-test', [
    'shell:msgflo'
    'shell:fbp_test'
    'shell:msgflo:kill'
  ]

  @registerTask 'build', 'Build the chosen target platform', (target = 'all') =>
    # nothing

  @registerTask 'test', 'Build and run automated tests', (target = 'all') =>
    @task.run 'coffeelint'
    @task.run 'build'
    @task.run 'mochaTest'
#    @task.run 'fbp-test'

  @registerTask 'default', ['test']
