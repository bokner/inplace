defmodule BitGraph.QueueTest do
  use ExUnit.Case

  alias BitGraph.Queue

  describe "Circular queue" do
    test "operations" do
      ## Create queue
      queue = Queue.new(100)
      assert Queue.empty?(queue)
      assert Queue.size(queue) == 0
      refute Queue.front(queue)

      range = -50..49
      range_size = Range.size(range)
      ## Enqueue
      Enum.each(Enum.with_index(range, 1),
        fn {num, idx} ->
          Queue.enqueue(queue, num)
          assert Queue.rear(queue) == num
          refute Queue.empty?(queue)
          assert Queue.front(queue) == -50
          assert idx == Queue.size(queue)
      end)

      ## Capacity overflow (we are now at capacity, 100 elements in the queue)
      assert catch_throw({:error, :stackoverflow} = Queue.enqueue(queue, Enum.random(1..1000)))
      assert Queue.size(queue) == range_size

      ## Dequeue
      Enum.each(1..range_size, fn i ->
        front = Queue.front(queue)
        el = Queue.dequeue(queue)
        assert front == el
        assert el in range
        assert Queue.size(queue) == range_size - i
      end)

      assert Queue.empty?(queue)
      ## We can keep using the queue
      Queue.enqueue(queue, 1001)
      assert Queue.size(queue) == 1
      assert Queue.front(queue) == 1001
      assert 1001 == Queue.dequeue(queue)
      assert Queue.empty?(queue)
    end
  end
end
