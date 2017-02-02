---
title: Heroku deployment
---
## Generating Heroku Procfile

`msgflo-procfile` can automatically generate a [Procfile](https://devcenter.heroku.com/articles/procfile)
for running as a Heroku service, based on the MsgFlo graph and component information.
This ensures that the production service runs in the same way as when using MsgFlo locally.

    msgflo-procfile graphs/myservice.fbp > Procfile

You can also selectively ignore certain roles in the graph, by using `--ignore role`.
Or you can include additional process stanzas by using `--include="guv: node ./node_modules/.bin/guv"`.

A real-life example can be found [in imgflo-server](https://github.com/imgflo/imgflo-server/blob/master/Makefile#L67).

