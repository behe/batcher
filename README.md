# Batcher

Batcher can be used to collect things to be handled in batches after a given
period of time or number of operations.

It was created to collect multiple writes to a Redis server and do batch writes
using the pipelined operation for an application which gets a massive amount of
writes. This reduces the number of connections needed by writing each operation
immediately by collecting them over a period of time and writing them all using
fewer Redis connections.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add batcher to your list of dependencies in `mix.exs`:

        def deps do
          [{:batcher, "~> 0.0.1", github: "behe/batcher"}]
        end

  2. Configure and start batcher:

        worker(Batcher, [[timeout: 1000, limit: 100, action: &SomeModule.some_action/1], []])

  The configured action will receive the batched list of things sent to it until the
  timeout or limit has triggered the action.

  To add items to the batcher call `Batcher.append(myitem)`

