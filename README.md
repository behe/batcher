# Batcher

Batcher can be used to collect things to be handled in batches after a given
period of time or number of operations.

It was created to collect multiple writes to a Redis server and do batch writes
using the pipelined operation for an application which gets a massive amount of
writes. This reduces the number of connections needed by writing each operation
immediately by collecting them over a period of time and writing them all using
a single Redis connection.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add batcher to your list of dependencies in `mix.exs`:

        def deps do
          [{:batcher, "~> 0.0.1"}]
        end

  2. Ensure batcher is started before your application:

        def application do
          [applications: [:batcher]]
        end
