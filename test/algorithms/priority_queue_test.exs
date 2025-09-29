defmodule InPlace.PriorityQueueTest do
  use ExUnit.Case

  alias InPlace.PriorityQueue

  describe "Priority Queue" do
    test "operations" do
      ## Create
      q = PriorityQueue.new(100)
      assert PriorityQueue.empty?(q)
      assert PriorityQueue.size(q) == 0
      refute PriorityQueue.get_min(q)
      refute PriorityQueue.extract_min(q)

      ## Insert
      PriorityQueue.insert(q, :a, 2.5)
      assert PriorityQueue.size(q) == 1
      refute PriorityQueue.empty?(q)
      assert {:a, 2.5} == PriorityQueue.get_min(q)
      PriorityQueue.insert(q, "b", 2.7)
      assert {:a, 2.5} == PriorityQueue.get_min(q)
      PriorityQueue.insert(q, "b", 0)
      assert {"b", 0} == PriorityQueue.get_min(q)

      ## Extract min
      assert {"b", 0} == PriorityQueue.extract_min(q)
      assert {:a, 2.5} = PriorityQueue.extract_min(q)
      assert {"b", 2.7} == PriorityQueue.extract_min(q)
      assert PriorityQueue.empty?(q)
      ## The "backup" mapping
    end

    test "sorting, heapsort-style" do
      priorities =
        Enum.zip(
        ["abc", "def", :a, :c, {:d, 1}, {:f, 2.5}, 2,   4, 0.25, -12.99],
        [ 2,     74.2, 1,   8,  22.5,   -3.7,     -0.5, 3.9, 5.1, 120])

        |> Enum.shuffle()
        q = PriorityQueue.new(length(priorities))
      Enum.each(priorities, fn {key, priority} -> PriorityQueue.insert(q, key, priority) end)

      desc_sorted = Enum.reduce(1..length(priorities), [],
        fn _, acc -> [PriorityQueue.extract_min(q) | acc] end
      )
      assert Enum.sort_by(priorities, fn {_key, priority} -> priority end, :desc) == desc_sorted
    end
  end
end
