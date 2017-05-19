---
title: Usage
score: 10
---
Install MsgFlo and some participant libraries

    npm install msgflo msgflo-nodejs
    npm install noflo-runtime-msgflo noflo-core
    export PATH=./node_modules/.bin:$PATH
    export MSGFLO_BROKER=amqp://localhost # which broker to use. Can also be mqtt://

Setup a Node.js participant using [msgflo-nodejs](https://github.com/msgflo/msgflo-nodejs) (CoffeeScript)

    msgflo-nodejs --name repeater ./node_modules/msgflo-nodejs/examples/Repeat.coffee

Setup a NoFlo participant using [noflo-runtime-msgflo](https://github.com/noflo/noflo-runtime-msgflo)

    noflo-runtime-msgflo --name out --graph core/Output

Define how the participants form a network (in [.FBP DSL](https://github.com/flowbased/fbp#language-for-flow-based-programming))

    # FILE: myservice.fbp
    repeater(Repeat) OUT -> IN out(Output)

Setup the network

    msgflo-setup ./myservice.fbp

Send some data to input

    msgflo-send-message --queue repeater.IN --json '{ "foo": "bar" }'
    # Should now see output from 'out' participant
    # after having traveled through NoFlo and node.js participants
