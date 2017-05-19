---
title: Best practices
---
Components should, to the extent possible, be state-free.
Ideally all the data needed to perform a task is provided in the input data.
In object-oriented-programming the primary entities often represent things/nouns,
which encourages bundling together different aspects of, with associated buildup of state.

Instead it is preferrable to let the data that moves through the system be the thing/noun,
and let the components be the actions/verbs which *operate on* this thing.

If there are a collection of actions somehow provided by the same "thing" (like a device or subsystem),
one can use a group to visually indicate that a set of nodes are related to eachother.

### Always send data

Even for cases where one "does not need to", like when a component uses input to perform a side-effect,
like storing to a database, or notifying an external system.

This allows to know that an operation completed, and to trigger new operations afterwards.
One immediate usecase is for automated tests, which can then assert that any side-effects performed
was done, and done correctly.

If there is no processed/derived data, send the original input onwards.

### Use a dedicated port/queue for errors

Allows to easily distinguish success from failures. By convention it is often just called `error`.
This can for instance be used to automatically report failures to a QA system, for automated or manual analysis.
Or to retry operations, in order to automatically recover from intermittent failures.

