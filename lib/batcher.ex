defmodule Batcher do
  use GenServer
  require Logger

  def start_link(args \\ [], _) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(opts) do
    state = Enum.into(opts, %{backlog: [], timeout: 1000, limit: 1000})

    :erlang.send_after(state.timeout, __MODULE__, :trigger)

    {:ok, state}
  end

  def append(command) do
    GenServer.cast(__MODULE__, {:append, command})
  end

  def perform(command) do
    GenServer.call(__MODULE__, {:perform, command})
  end

  def backlog do
    GenServer.call(__MODULE__, :backlog)
  end

  def handle_call({:perform, command}, _, %{action: action} = state) do
    {:reply, apply_action(action, [command], "perform"), state}
  end

  def handle_call(:backlog, _, %{backlog: backlog} = state) do
    {:reply, Enum.reverse(backlog), state}
  end

  def handle_cast({:append, command}, %{limit: limit, backlog: backlog, action: action} = state) do
    backlog = [ command | backlog ]
    if Enum.count(backlog) == limit do
      backlog = apply_action(action, backlog, "limit")
    end
    {:noreply, %{state | backlog: backlog}}
  end

  def handle_info(:trigger, %{timeout: timeout, action: action, backlog: backlog} = state) do
    apply_action(action, backlog, "timeout")

    :erlang.send_after(timeout, __MODULE__, :trigger)
    {:noreply, %{state | backlog: []}}
  end

  defp apply_action(action, backlog, reason \\ "") do
    case backlog |> Enum.count do
      0 ->
        backlog
      _ ->
        Logger.debug "#{reason}: flushing #{Enum.count(backlog)} commands"
        action.(Enum.reverse(backlog))
        []
    end
  end
end
