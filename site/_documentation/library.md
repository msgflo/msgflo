---
title: Component library
score: 8
---

A component is a piece of code which can instantiate a MsgFlo participant.
By default such component code is placed in `./participants/` directory of a project.

    cp ./node_modules/msgflo-nodejs/examples/Repeat.coffee ./participants/

Declaring a command template in `package.json` tells MsgFlo how to instantiate them.
This can be done per component, or by specifying a handler for a given file extension,
which makes each matching file in the component directory (here: `Repeat`) automatically available as a component.

```json
  "msgflo": {
    "handlers": {
      ".coffee": "msgflo-nodejs --name #ROLE #FILENAME"
    },
    "components": {
      "Output": "noflo-runtime-msgflo --name out --graph core/Output --broker amqp://localhost"
     }
   }
```
The component command template supports substituting several variables, including:

* `#FILENAME`: Full path to the file with the component code
* `#ROLE`: Name of the role to instantiate as
* `#COMPONENT`: Full name of component, as named in graph (project/Component).
* `#COMPONENTNAME`: Name of component without project/ (Component)

Now the example service above can be started with a single command:
By enabling `--participants` MsgFlo will start the individual participants.

    msgflo-setup ./myservice.fbp --broker amqp://localhost --participants --forward=stdout

Using `--forward stdout` enables seeing the output from the `Output` participant, which is in a child process.

Send message again, and it should be repeated on stdout.

    msgflo-send-message --queue repeater.IN --json '{ "foo": "bar-with-componentlib" }'


Having component handlers facilitates live-programming from Flowhub IDE:
Adding a new component with Python code will get a .py file extension,
and the handler for `py` will be used to instantiate a new process.

### Defaults

By default MsgFlo reads its component library configuration from the `package.json` (used by NPM).
You can specify an alternative JSON file using `--library msgflo.json`.
The configuration object can either exist at the top-level, or under a `msgflo` key.

There are [default handlers](https://github.com/msgflo/msgflo/blob/master/src/library.coffee#L9) specified
for common supported environments. These do not need to be specified manually.

*  `.py` (msgflo-python)
* `.coffee`, `.js` (msgflo-nodejs)
* `.json` and `.fbp` (noflo-runtime-msgflo)


