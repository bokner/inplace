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
      (size_before == SparseSet.size(set) + 1)
      && assert_inverse(set)
    end)

    assert SparseSet.size(set) == 0
    assert SparseSet.empty?(set)
    refute SparseSet.delete(set, Enum.random(1..domain_size))

    ## Undeletion
    Enum.all?(1..domain_size, fn _ ->
      size_before = SparseSet.size(set)
      SparseSet.undelete(set)
      (size_before == SparseSet.size(set) - 1)
      && assert_inverse(set)
    end)
    assert SparseSet.size(set) == domain_size
  end

  test "get/2, mapper" do
    domain_size = 100
    set = SparseSet.new(domain_size, mapper: fn _set, el -> 2 * el end)
    random_el = Enum.random(1..domain_size)
    assert SparseSet.get(set, random_el) == 2 * random_el
  end

  test "iteration (reduce)" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    mapset = MapSet.new(1..domain_size)
    assert mapset == MapSet.new(SparseSet.to_list(set))

    mapset_copy = SparseSet.reduce(set, MapSet.new, fn el, acc -> MapSet.put(acc, el) end)
    assert mapset == mapset_copy

    ## reduce with {:halt, _}
    partial_set = SparseSet.reduce(set, MapSet.new(), fn el, acc ->
      if el == div(domain_size, 2) do
        {:halt, acc}
      else
        MapSet.put(acc, el)
      end
    end)

    assert MapSet.size(partial_set) == div(domain_size, 2)

  end

  defp assert_inverse(%{dom: dom, idom: idom, dom_size: dom_size} = set) do
    SparseSet.size(set) == 0 ||
    Enum.all?(1..dom_size, fn idx ->
      Array.get(idom,
        Array.get(dom, idx)
      ) == idx
    end)
  end

end
