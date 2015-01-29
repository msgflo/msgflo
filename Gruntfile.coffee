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

  # Grunt plugins used for building

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'

  # Our local tasks
  @registerTask 'build', 'Build the chosen target platform', (target = 'all') =>
    # nothing

  @registerTask 'test', 'Build and run automated tests', (target = 'all') =>
    @task.run 'coffeelint'
    @task.run 'build'
    @task.run 'mochaTest'

  @registerTask 'default', ['test']
