defmodule BatcherTest do
  use Pavlov.Case
  import Pavlov.Syntax.Expect

  def command(i) do
    ~w(LPUSH key#{i} value#{i})
  end

  context "without batching" do
    before do
      test = self
      Batcher.start_link([action: fn(backlog) -> send(test, {:backlog, backlog}) end], [])

      :ok
    end

    it "performs the action directly" do
      Batcher.perform BatcherTest.command(1)
      assert_received {:backlog, backlog}
      expect(Batcher.backlog) |> to_eq []
    end
  end

  context "with timeout" do
    before do
      test = self
      Batcher.start_link([timeout: 100, action: fn(backlog) -> send(test, {:backlog, backlog}) end], [])

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
      Batcher.start_link([limit: 10, action: fn(backlog) -> send(test, {:backlog, backlog}) end], [])

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
end
