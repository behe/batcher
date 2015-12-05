defmodule Batcher do
  use GenServer
  require Logger

  def start_link(args \\ [], name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(opts) do
    state = Enum.into(opts, %{backlog: [], timeout: 1000, limit: 1000, timer: nil})
    timer = :erlang.send_after(state.timeout, self, :trigger)
    {:ok, %{state | timer: timer}}
  end

  @doc "Appends an item to the `batcher` (pid or atom)"
  def append(command, batcher \\ __MODULE__) do
    GenServer.cast(batcher, {:append, command})
  end

  @doc "Applies the action immediately to the `command` by the `batcher`"
  def perform(command, batcher \\ __MODULE__) do
    GenServer.call(batcher, {:perform, command})
  end

  @doc "Retrieves the items in the backlog of the `batcher`"
  def backlog(batcher \\ __MODULE__) do
    GenServer.call(batcher, :backlog)
  end

  def handle_call({:perform, command}, _, %{action: action} = state) do
    {:reply, apply_action(action, [command], "perform"), state}
  end

  def handle_call(:backlog, _, %{backlog: backlog} = state) do
    {:reply, Enum.reverse(backlog), state}
  end

  def handle_cast({:append, command}, %{limit: limit, backlog: backlog, action: action, timer: timer, timeout: timeout} = state) do
    backlog = [ command | backlog ]
    {:noreply, %{state | backlog: limit_backlog(backlog, limit, action, timer, timeout)}}
  end

  def handle_info(:trigger, %{timeout: timeout, action: action, backlog: backlog} = state) do
    apply_action(action, backlog, "timeout")

    timer = :erlang.send_after(timeout, self, :trigger)
    {:noreply, %{state | backlog: [], timer: timer}}
  end

  defp limit_backlog(backlog, limit, action, timer, timeout) do
    case backlog |> Enum.count do
      ^limit ->
        :erlang.cancel_timer(timer)
        :erlang.send_after(timeout, self, :trigger)
        apply_action(action, backlog, "limit")
      _ ->
        backlog
    end
  end

  defp apply_action(action, backlog, reason) do
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
