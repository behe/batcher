defmodule BatcherTest do
  use Pavlov.Case
  import Pavlov.Syntax.Expect

  def command(i) do
    ~w(LPUSH key#{i} value#{i})
  end

  context "without batching" do
    before do
      test = self
      Batcher.start_link([action: fn(backlog) -> send(test, {:backlog, backlog}) end])

      :ok
    end

    it "performs the action directly" do
      Batcher.perform BatcherTest.command(1)
      expect(Batcher.backlog) |> to_eq []
      assert_received {:backlog, backlog}
      expect(backlog) |> to_eq [BatcherTest.command(1)]
    end
  end

  context "with timeout" do
    before do
      test = self
      Batcher.start_link([timeout: 100, action: fn(backlog) -> send(test, {:backlog, backlog}) end])

      :ok
    end

    it "delays action until timeout" do
      Batcher.append BatcherTest.command(1)
      Batcher.append BatcherTest.command(2)
      expect(Batcher.backlog) |> to_eq [BatcherTest.command(1), BatcherTest.command(2)]

      assert_receive {:backlog, backlog}, 200
      expect(backlog) |> to_eq [BatcherTest.command(1), BatcherTest.command(2)]
      expect(Batcher.backlog) |> to_eq []
    end
  end

  context "with limit" do
    before do
      test = self
      Batcher.start_link([limit: 10, action: fn(backlog) -> send(test, {:backlog, backlog}) end])

      :ok
    end

    it "delays action until limit" do
      for i <- 1..9 do
        Batcher.append BatcherTest.command(i)
      end
      expect(Batcher.backlog |> Enum.count) |> to_eq 9

      Batcher.append BatcherTest.command(10)
      expect(Batcher.backlog) |> to_eq []
      assert_received {:backlog, backlog}
      expect(backlog) |> to_eq (1..10 |> Enum.map(fn(i) -> BatcherTest.command(i) end))
    end
  end

  context "GenServer timeout" do
    before :each do
      test = self
      {:ok, pid} = GenServer.start_link(Batcher,
        [timeout: 100,
        action: fn(backlog) -> send(test, {:backlog, backlog}) end])
      {:ok, pid: pid}
    end

    it "applies timeout", context do
      GenServer.cast(context[:pid], {:append, BatcherTest.command(1)})
      GenServer.cast(context[:pid], {:append, BatcherTest.command(2)})

      expect(GenServer.call(context[:pid], :backlog)
      |> Enum.count) |> to_eq 2

      assert_receive {:backlog, backlog}, 200
      expect(backlog) |> to_eq [BatcherTest.command(1), BatcherTest.command(2)]
      expect(GenServer.call(context[:pid], :backlog)) |> to_eq []
    end

    it "handles triggers", context do
      GenServer.cast(context[:pid], {:append, BatcherTest.command(1)})
      GenServer.cast(context[:pid], {:append, BatcherTest.command(2)})
      expect(GenServer.call(context[:pid], :backlog) |> Enum.count) |> to_eq 2

      assert_receive {:backlog, backlog}, 200
      expect(backlog) |> to_eq [BatcherTest.command(1), BatcherTest.command(2)]
      expect(GenServer.call(context[:pid], :backlog)) |> to_eq []

      GenServer.cast(context[:pid], {:append, BatcherTest.command(1)})
      GenServer.cast(context[:pid], {:append, BatcherTest.command(2)})

      expect(GenServer.call(context[:pid], :backlog)
      |> Enum.count) |> to_eq 2

      assert_receive {:backlog, _backlog}, 200
    end
  end

  context "GenServer limit and timeout" do
    before :each do
      test = self
      {:ok, pid} = GenServer.start_link(Batcher,
        [limit: 2,
         timeout: 200,
         action: fn(backlog) -> send(test, {:backlog, backlog}) end])
      {:ok, pid: pid}
    end

    it "handles batching", context do
      GenServer.cast(context[:pid], {:append, BatcherTest.command(1)})
      GenServer.cast(context[:pid], {:append, BatcherTest.command(2)})
      assert_receive {:backlog, _backlog}, 100 # triggered by limit

      GenServer.cast(context[:pid], {:append, BatcherTest.command(3)})
      assert_receive {:backlog, _backlog}, 300 # triggered by timeout
    end
  end

  context "Multiple Batchers" do
    before :each do
      test = self
      {:ok, p_limit} = Batcher.start_link([limit: 2,
        action: fn(backlog) -> send(test, {:limit, backlog}) end], :limit)
      {:ok, p_timeout} = Batcher.start_link([timeout: 100,
        action: fn(backlog) -> send(test, {:timeout, backlog}) end], :timeout)
      {:ok, p_both} = Batcher.start_link([timeout: 10000, limit: 2,
        action: fn(backlog) -> send(test, {:both, backlog}) end], :both)

      {:ok, batchers: %{limit: p_limit, timeout: p_timeout, both: p_both}}
    end

    it "handles limit", context do
      Batcher.append(BatcherTest.command(1), context[:batchers][:limit])

      expect(Batcher.backlog(context[:batchers][:limit])
      |> Enum.count) |> to_eq 1

      Batcher.append(BatcherTest.command(2), context[:batchers][:limit])

      expect(Batcher.backlog(context[:batchers][:limit])) |> to_eq []
      assert_received {:limit, _backlog}
    end

    it "handles timeout", context do
      Batcher.append(BatcherTest.command(1), context[:batchers][:timeout])
      Batcher.append(BatcherTest.command(2), context[:batchers][:timeout])

      expect(Batcher.backlog(context[:batchers][:timeout]))
      |> to_eq [BatcherTest.command(1), BatcherTest.command(2)]

      assert_receive {:timeout, _backlog}, 200
    end

    it "handles both", context do
      Batcher.append(BatcherTest.command(1), context[:batchers][:limit])
      Batcher.append(BatcherTest.command(2), context[:batchers][:limit])

      Batcher.append(BatcherTest.command(3), context[:batchers][:both])
      Batcher.append(BatcherTest.command(4), context[:batchers][:both])

      Batcher.append(BatcherTest.command(5), context[:batchers][:timeout])

      assert_receive {:limit, _backlog}, 100
      assert_receive {:both, _backlog}, 100
      assert_receive {:timeout, _backlog}, 200
    end
  end
end
