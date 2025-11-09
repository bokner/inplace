defmodule InPlace.LinkedListTest do
  use ExUnit.Case

  alias InPlace.{LinkedList}

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
