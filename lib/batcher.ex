defmodule Batcher do
  use GenServer
  require Logger

  def start_link(args \\ [], _) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(opts) do
    # IO.inspect opts
    state = Enum.into(opts, %{backlog: [], timeout: 1000, limit: 1000})
    # IO.inspect state

    :erlang.send_after(state.timeout, __MODULE__, :trigger)

    {:ok, state}
  end

#  def init(args), do: IO.inspect args; "Batcher needs to be started with an action: `Batcher.start_link(action: action)`"

  def append(command) do
    GenServer.cast(__MODULE__, {:append, command})
  end

  def backlog do
    GenServer.call(__MODULE__, :backlog)
  end

  def handle_cast({:append, command}, %{limit: limit, backlog: backlog, action: action} = state) do
    backlog = [ command | backlog ]
    if Enum.count(backlog) == limit do
      Logger.debug "flushing #{Enum.count(backlog)} commands after limit #{limit}"
      action.(Enum.reverse(backlog))
      backlog = []
    end
    {:noreply, %{state | backlog: backlog}}
  end

  def handle_call(:backlog, _, %{backlog: backlog} = state) do
    {:reply, Enum.reverse(backlog), state}
  end

  def handle_info(:trigger, %{timeout: timeout, action: action, backlog: backlog} = state) do
    if backlog |> Enum.count > 0 do
      Logger.debug "flushing #{Enum.count(backlog)} commands after timeout #{timeout}"
      action.(Enum.reverse(backlog))
    end

    :erlang.send_after(timeout, __MODULE__, :trigger)
    {:noreply, %{state | backlog: []}}
  end
end
