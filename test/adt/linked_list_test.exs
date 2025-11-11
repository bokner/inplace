defmodule InPlace.LinkedListTest do
  use ExUnit.Case

  alias InPlace.{LinkedList}

  describe "Singly linked list" do
    test "operations" do
      ll = LinkedList.new(10)
      assert LinkedList.size(ll) == 0 && LinkedList.empty?(ll)
      LinkedList.add_first(ll, 1)
      LinkedList.add_last(ll, 2)
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
      assert LinkedList.to_list(ll) == [3, 4, 2]
    end

    test "mapper" do
      map = Map.new([{1, :a}, {2, :b}, {3, :c}])
      ll = LinkedList.new(3, mapper_fun: fn index -> Map.get(map, index) end)
      Enum.each(1..3, fn idx -> LinkedList.add_last(ll, idx) end)
      assert LinkedList.to_list(ll) == [:a, :b, :c]
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
    end
  end

  describe "Doubly linked list" do
    import InPlace.LinkedList
    @terminator 0
    test "operation" do
      dll = new(10, mode: :doubly_linked)
      assert tail(dll) == @terminator
      assert head(dll) == tail(dll)
      add_last(dll, 1)
      assert head(dll) == tail(dll)
      refute tail(dll) == @terminator
      ## Remove single element
      delete(dll, 1)
      assert tail(dll) == @terminator
      ## Add several elements...
      add_first(dll, 1)
      add_first(dll, 2)
      insert(dll, 1, 3)
      assert [2, 3, 1] == to_list(dll)
      ## Traverse back
      assert_traverse(dll)
      ## Remove some element
      delete(dll, Enum.random([1, 2, 3]))
      ## Traverse back after removal
      assert_traverse(dll)
    end

    defp assert_traverse(dll) do
      forward_list = to_list(dll)
      {@terminator, back_traversed_list} = traverse_back(dll)
      assert forward_list == back_traversed_list
    end

    defp traverse_back(dll) do
      Enum.reduce(1..size(dll), {tail(dll), []},
        fn _, {p, acc} -> {prev(dll, p), [data(dll, p) | acc]}
      end)
    end

  end

end
