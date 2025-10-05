defmodule InPlace.HeapTest do
  use ExUnit.Case

  alias InPlace.{Heap, Array}

  describe "Binary heap" do
    test "creation" do
      ## Create heap
      heap = Heap.new(100)
      assert Heap.empty?(heap)
      assert Heap.size(heap) == 0
      refute Heap.get_min(heap)
      assert Heap.valid?(heap)
    end

    test "insert" do
      heap = Heap.new(100)
      values = Enum.take_random(1..1000, 50)
      Enum.each(values, fn val -> Heap.insert(heap, val) end)
      assert Heap.get_min(heap) == Enum.min(values)
      assert Heap.size(heap) == 50
    end

    test "extract_min" do
      heap = Heap.new(100)
      refute Heap.extract_min(heap)
      values = Enum.take_random(1..1000, 50)
      Enum.each(values, fn val -> Heap.insert(heap, val) end)
      assert Heap.extract_min(heap) == Enum.min(values)
      assert Heap.size(heap) == 49
    end

    test "heapify" do
      heap_size = 100_000
      heap = Heap.new(heap_size)
      ## We will now construct an invalid heap
      ## Set heap size
      Array.put(heap.array, heap_size + 1, heap_size)
      ## Fill out the array with random values
      values = Enum.shuffle(1..heap_size)
      Enum.each(Enum.with_index(values, 1), fn {val, idx} -> Array.put(heap.array, idx, val) end)
      refute Heap.valid?(heap)
      ## Heapify will force the heap property
      Heap.heapify(heap)
      assert Heap.valid?(heap)
    end
  end
end
