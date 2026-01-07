defmodule InPlace.LinkedListTest do
  use ExUnit.Case

  alias InPlace.{LinkedList}

  describe "Linked list" do
    test "operations" do
      ll = LinkedList.new(10)
      assert LinkedList.size(ll) == 0 && LinkedList.empty?(ll)
      LinkedList.add_first(ll, 1)
      LinkedList.append(ll, 2)
      LinkedList.add_first(ll, 3)
      assert LinkedList.size(ll) == 3 && !LinkedList.empty?(ll)

      assert Enum.all?(
               Enum.zip(1..3, [3, 1, 2]),
               fn {idx, value} ->
                 LinkedList.get(ll, idx) == value
               end
             )

      assert LinkedList.to_list(ll) == [3, 1, 2]
      LinkedList.delete(ll, 2)
      assert LinkedList.to_list(ll) == [3, 2]

      LinkedList.insert(ll, 1, 4)
      assert LinkedList.to_list(ll) == [4, 3, 2]
    end

    test "mapper" do
      map = Map.new([{1, :a}, {2, :b}, {3, :c}])
      ll = LinkedList.new(3, mapper_fun: fn index -> Map.get(map, index) end)
      Enum.each(1..3, fn idx -> LinkedList.append(ll, idx) end)
      assert LinkedList.to_list(ll) == [:a, :b, :c]
    end

    test "reducer" do
      ll = LinkedList.new(5)
      Enum.each(1..5, fn value -> LinkedList.add_first(ll, value) end)
      ## Sum up by reduction
      reducer_fun = fn p, acc -> LinkedList.data(ll, p) + acc end
      ## Compare with summing up the list
      assert LinkedList.reduce(ll, 0, reducer_fun) == LinkedList.to_list(ll) |> Enum.sum()
    end

    test "iterator (side effects)" do
      ll = LinkedList.new(10, circular: true, mode: :doubly_linked, deletion: :hide)
      Enum.each(1..10, fn value -> LinkedList.append(ll, value) end)
      assert LinkedList.size(ll) == 10

      LinkedList.iterate(ll, fn p ->
        refute LinkedList.pointer_deleted?(ll, p)
      end)

      LinkedList.iterate(ll, fn p ->
        LinkedList.delete_pointer(ll, p)
        assert LinkedList.pointer_deleted?(ll, p)
      end)

      assert LinkedList.empty?(ll)
      assert Enum.empty?(LinkedList.to_list(ll))
    end

    test "iterator (reduction)" do
      ll = LinkedList.new(10, circular: true, mode: :doubly_linked)
      Enum.each(1..10, fn value -> LinkedList.append(ll, value) end)
      ## Start from head
      from_head_list =
        LinkedList.iterate(
          ll,
          fn p, acc -> [LinkedList.data(ll, p) | acc] end,
          initial_value: []
        )

      assert from_head_list == Enum.to_list(10..1//-1)
      ## Start from tail
      from_tail_list =
        LinkedList.iterate(
          ll,
          fn p, acc -> [LinkedList.data(ll, p) | acc] end,
          start: LinkedList.tail(ll),
          initial_value: []
        )

      assert from_tail_list == Enum.to_list(9..1//-1) ++ [10]

      ## Backward, from tail
      backward_from_tail =
        LinkedList.iterate(
          ll,
          fn p, acc -> [LinkedList.data(ll, p) | acc] end,
          forward: false,
          initial_value: [],
          start: LinkedList.tail(ll)
        )

      assert backward_from_tail == Enum.to_list(1..10)
    end

    test "recycling of indices" do
      ll = LinkedList.new(3)

      Enum.each(1..10, fn _ ->
        ## Add and delete elements several times
        LinkedList.add_first(ll, 1)
        LinkedList.add_first(ll, 2)
        LinkedList.add_first(ll, 3)

        LinkedList.delete(ll, 3)
        LinkedList.delete(ll, 2)
        LinkedList.delete(ll, 1)
      end)

      assert LinkedList.empty?(ll)
      assert Enum.empty?(LinkedList.to_list(ll))
    end
  end

  describe "Misc" do
    import InPlace.LinkedList
    @terminator 0

    test "Mixed (addition, deletion, traversal with modification)" do
      dll = new(10)
      assert tail(dll) == @terminator
      assert head(dll) == tail(dll)
      append(dll, 1)
      assert head(dll) == tail(dll)
      refute tail(dll) == @terminator
      ## Remove single element
      delete(dll, 1)
      assert tail(dll) == @terminator
      ## Add several elements...
      add_first(dll, 1)
      add_first(dll, 2)
      insert(dll, 1, 3)
      assert [3, 2, 1] == to_list(dll)
      ## Traverse back
      assert_traverse(dll)
      ## Remove some element
      delete(dll, Enum.random([1, 2, 3]))
      ## Traverse back after removal
      assert_traverse(dll)
    end

    test "delete pointers" do
      dllc = LinkedList.new(10, deletion: :hide)
      Enum.each(1..4, fn value -> LinkedList.append(dllc, value) end)
      assert [1, 2, 3, 4] == LinkedList.to_list(dllc)
      head = LinkedList.head(dllc)
      LinkedList.delete_pointer(dllc, head)
      assert LinkedList.pointer_deleted?(dllc, head)
      assert [2, 3, 4] == LinkedList.to_list(dllc)
      tail = LinkedList.tail(dllc)
      LinkedList.delete_pointer(dllc, tail)
      assert LinkedList.pointer_deleted?(dllc, tail)
      assert LinkedList.prev(dllc, tail) == LinkedList.tail(dllc)
      assert [2, 3] == LinkedList.to_list(dllc)
      tail = LinkedList.tail(dllc)
      LinkedList.delete_pointer(dllc, tail)
      assert LinkedList.pointer_deleted?(dllc, tail)
      assert [2] == LinkedList.to_list(dllc)
      tail = LinkedList.tail(dllc)
      LinkedList.delete_pointer(dllc, tail)
      assert LinkedList.pointer_deleted?(dllc, tail)
      assert LinkedList.empty?(dllc)
    end

    test "restore pointers by 'rewindind'" do
      dllc = LinkedList.new(10, deletion: :rewind)
      n = 4
      ## Fill the list...
      Enum.each(1..n, fn value -> LinkedList.append(dllc, value) end)
      values = LinkedList.to_list(dllc)

      initially_available_pointers = LinkedList.available(dllc)
      ## ...randomly remove all elements
      Enum.shuffle(1..n)
      |> Enum.each(fn idx -> LinkedList.delete_pointer(dllc, idx) end)

      ## Officially no elements in the list
      assert Enum.empty?(LinkedList.to_list(dllc))
      assert LinkedList.size(dllc) == 0
      ## ..restore removed elements
      Enum.each(1..n, fn _idx -> LinkedList.rewind(dllc) end)
      ## Values restored
      assert values == LinkedList.to_list(dllc)

      assert LinkedList.size(dllc) == n
      ## Pointers reclaimed
      assert initially_available_pointers == LinkedList.available(dllc)
    end

    defp assert_traverse(dll) do
      forward_list = to_list(dll)
      {head, back_traversed_list} = traverse_back(dll)
      assert head == prev(dll, head(dll))
      assert forward_list == back_traversed_list
    end

    defp traverse_back(dll) do
      Enum.reduce(1..size(dll), {tail(dll), []}, fn _, {p, acc} ->
        {prev(dll, p), [data(dll, p) | acc]}
      end)
    end
  end
end
