defmodule InPlace.SparseSetTest do
  use ExUnit.Case

  alias InPlace.{SparseSet, Array}

  test "new/1, delete/2, undelete/1" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    assert SparseSet.size(set) == domain_size
    refute SparseSet.empty?(set)
    assert Enum.all?(1..SparseSet.size(set), fn el -> SparseSet.member?(set, el) end)

    ## Deletion
    random_order = Enum.shuffle(1..domain_size)

    assert Enum.all?(random_order, fn el ->
             size_before = SparseSet.size(set)
             SparseSet.delete(set, el)

             size_before == SparseSet.size(set) + 1 &&
               assert_inverse(set)
           end)

    assert SparseSet.size(set) == 0
    assert SparseSet.empty?(set)
    refute SparseSet.delete(set, Enum.random(1..domain_size))

    ## Undeletion
    Enum.all?(1..domain_size, fn _ ->
      size_before = SparseSet.size(set)
      SparseSet.undelete(set)

      size_before == SparseSet.size(set) - 1 &&
        assert_inverse(set)
    end)

    assert SparseSet.size(set) == domain_size
    refute SparseSet.undelete(set)
  end

  test "get/2, mapper" do
    domain_size = 100
    set = SparseSet.new(domain_size, mapper: fn _set, el -> 2 * el end)
    random_el = Enum.random(1..domain_size)
    assert SparseSet.get(set, random_el) == 2 * random_el
  end

  test "copy" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    elements_to_delete = Enum.take_random(1..domain_size, div(domain_size, 2))
    Enum.each(elements_to_delete, fn el -> SparseSet.delete(set, el) end)
    set_copy = SparseSet.copy(set)
    assert SparseSet.to_list(set) == SparseSet.to_list(set_copy)
  end

  test "iteration (reduce)" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    mapset = MapSet.new(1..domain_size)
    assert mapset == MapSet.new(SparseSet.to_list(set))

    mapset_copy = SparseSet.reduce(set, MapSet.new(), fn el, acc -> MapSet.put(acc, el) end)
    assert mapset == mapset_copy

    ## reduce with {:halt, _}
    partial_set =
      SparseSet.reduce(set, MapSet.new(), fn el, acc ->
        if el == div(domain_size, 2) do
          {:halt, acc}
        else
          MapSet.put(acc, el)
        end
      end)

    assert MapSet.size(partial_set) == div(domain_size, 2)
  end

  test "iteration (each)" do
    size = 10
    arr = Array.new(10, 0)
    assert Array.to_list(arr) == List.duplicate(0, size)
    set = SparseSet.new(size)
    SparseSet.each(set, fn idx -> Array.put(arr, idx, 1) end)
    assert Array.to_list(arr) == List.duplicate(1, size)
  end

  test "ordered `map`" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    ## Delete some elements to shuffle the order
    elements_to_delete = Enum.take_random(1..domain_size, div(domain_size, 2))
    Enum.each(elements_to_delete, fn el -> SparseSet.delete(set, el) end)

    assert set
      |> SparseSet.reduce([], fn el, acc -> [2 * el | acc] end)
      |> Enum.sort(:asc) ==
      SparseSet.iterate_ordered(set, fn el -> 2 * el end)

  end

  test "ordered `reduce`" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    ## Delete some elements to shuffle the order
    elements_to_delete = Enum.take_random(1..domain_size, div(domain_size, 2))
    Enum.each(elements_to_delete, fn el -> SparseSet.delete(set, el) end)

    assert set
      |> SparseSet.to_list()
      |> Enum.sort(:desc) ==
      SparseSet.iterate_ordered(set, [], fn el, acc -> [el | acc] end)
  end

  test "serialize/deserialize" do
     domain_size = 100
    set = SparseSet.new(domain_size)
    elements_to_delete = Enum.take_random(1..domain_size, div(domain_size, 2))
    Enum.each(elements_to_delete, fn el -> SparseSet.delete(set, el) end)
    serialized = SparseSet.serialize(set)
    set2 = SparseSet.deserialize(serialized)
    assert SparseSet.to_list(set) == SparseSet.to_list(set2)
    assert SparseSet.size(set) == SparseSet.size(set2)
  end

  defp assert_inverse(%{dom: dom, idom: idom, max_size: dom_size} = set) do
    assert (SparseSet.size(set) == 0 ||
      Enum.all?(1..dom_size, fn idx ->
        Array.get(
          idom,
          Array.get(dom, idx)
        ) == idx
      end)
    )
  end
end
