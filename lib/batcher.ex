defmodule Batcher do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(opts) do
    state = Enum.into(opts, %{backlog: [], timeout: 1000, limit: 1000})
    # IO.inspect state

    :erlang.send_after(state.timeout, __MODULE__, :trigger)

    {:ok, state}
  end

  def append(command) do
    GenServer.cast(__MODULE__, {:append, command})
  end

  def backlog do
    GenServer.call(__MODULE__, :backlog)
  end

  def handle_cast({:append, command}, %{limit: limit, backlog: backlog, action: action} = state) do
    backlog = [ command | backlog ]
    if Enum.count(backlog) == limit do
      # IO.puts "trigger limit #{limit}"
      action.(backlog)
      backlog = []
    end
    {:noreply, %{state | backlog: backlog}}
  end

  def handle_call(:backlog, _, %{backlog: backlog} = state) do
    {:reply, Enum.reverse(backlog), state}
  end

  def handle_info(:trigger, %{timeout: timeout, action: action, backlog: backlog} = state) do
    # IO.puts "trigger timeout #{timeout}"
    action.(backlog)
    :erlang.send_after(timeout, __MODULE__, :trigger)
    {:noreply, %{state | backlog: []}}
  end
end
