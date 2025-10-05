defmodule InPlace.PriorityQueueTest do
  use ExUnit.Case

  alias InPlace.PriorityQueue, as: Q

  describe "Priority Queue" do
    test "operations" do
      ## Create
      q = Q.new(100)
      assert Q.empty?(q)
      assert Q.size(q) == 0
      refute Q.get_min(q)
      refute Q.extract_min(q)

      ## Insert
      keys =       [10, -2,  -2, 10]
      priorities = [2.5, 2.7, 0, 0.5]

      # Shuffle and insert into the Q
      Enum.zip(keys, priorities)
      |> Enum.shuffle()
      |> Enum.each(fn {key, priority} ->
        Q.insert(q, key, priority)
      end)

      ## We have
      ## - a key (109) with a 2nd smallest priority
      ## - 2 values for the same key (-2)
      ## We expect:
      ## - the size of priority queue to be 2 after we insert all priority records (to be implemented)
      ## - the extraction will be in expected order
      ## - the extraction will only produce priorities one per key

      ## TODO: not implemented yet
      ## assert Q.size(q) == 2

      sorted = Enum.reduce_while(1..Q.size(q), [], fn _, acc ->
        p = Q.extract_min(q)
        p && {:cont, [p | acc]} || {:halt, acc}
      end)

      assert length(sorted) == 2
      assert Enum.sort_by(sorted, fn {_key, priority} -> priority end, :desc) == sorted
    end

    test "sorting, heapsort-style" do
      priorities =
        Enum.zip(
        [2, 2,    2, 3, -1, 17,    45,  19,   2,  4,   9,  -12],
        [2, 74.2, 0, 1,  8, 22.5, -3.7, -0.5, 4,  3.9, 5.1, 120])
        |> Enum.shuffle()
        #|> IO.inspect(label: :data)

        q = Q.new(length(priorities))
      Enum.each(priorities, fn {key, priority} -> Q.insert(q, key, priority) end)

      desc_sorted = Enum.reduce_while(1..length(priorities), [],
        fn _, acc -> p = Q.extract_min(q)
          p && {:cont, [p | acc]} || {:halt, acc} end
      )

      ## For duplicates in original priorities list,
      ## we'll leave the ones with lesser priority
      deduped = Enum.reduce(priorities, Map.new(), fn {key, priority}, acc ->
        Map.update(acc, key, priority, fn existing -> min(existing, priority) end)
      end)
      assert Enum.sort_by(deduped, fn {_key, priority} -> priority end, :desc)
            == desc_sorted
    end
  end
end
