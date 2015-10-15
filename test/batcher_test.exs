defmodule BatcherTest do
  use Pavlov.Case
  import Pavlov.Syntax.Expect

  def command(i) do
    ~w(LPUSH key#{i} value#{i})
  end

  context "with timeout" do
    before do
      Batcher.start_link([timeout: 100, action: fn(_) -> end], [])

      :ok
    end

    it "delays action until timeout" do
      Batcher.append BatcherTest.command(1)
      Batcher.append BatcherTest.command(2)
      expect(Batcher.backlog) |> to_eq [BatcherTest.command(1), BatcherTest.command(2)]

      :timer.sleep 99
      expect(Batcher.backlog) |> to_eq []
    end
  end

  context "with limit" do

    before do
      Batcher.start_link([limit: 10, action: fn(_) -> end], [])

      :ok
    end

    it "delays action until limit" do
      for i <- 1..9 do
        Batcher.append BatcherTest.command(i)
      end
      expect(Batcher.backlog |> Enum.count) |> to_eq 9

      Batcher.append BatcherTest.command(10)
      expect(Batcher.backlog) |> to_eq []
    end
  end
end
