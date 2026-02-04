defmodule InPlace.SparseSetTest do
  use ExUnit.Case

  alias InPlace.SparseSet

  test "new/1, delete/2, undelete/1" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    assert SparseSet.size(set) == domain_size
    assert Enum.all?(1..SparseSet.size(set), fn el -> SparseSet.member?(set, el) end)
    ## Deletion
    random_order = Enum.shuffle(1..domain_size)
    assert Enum.all?(random_order, fn el ->
      size_before = SparseSet.size(set)
      SparseSet.delete(set, el)
      size_before == SparseSet.size(set) + 1
    end)
    assert SparseSet.size(set) == 0
    refute SparseSet.delete(set, Enum.random(1..domain_size))
    ## Undeletion
    Enum.all?(1..domain_size, fn _ ->
      size_before = SparseSet.size(set)
      SparseSet.undelete(set)
      size_before == SparseSet.size(set) - 1
    end)
    assert SparseSet.size(set) == domain_size
  end

  test "iteration" do
    domain_size = 100
    set = SparseSet.new(domain_size)
    mapset = MapSet.new(1..domain_size)
    assert mapset == MapSet.new(SparseSet.to_list(set))
    mapset_copy = SparseSet.iterate(set, MapSet.new, fn el, acc -> MapSet.put(acc, el) end)
    assert mapset == mapset_copy

    ## iterate with {:halt, _}
    partial_set = SparseSet.iterate(set, MapSet.new(), fn el, acc ->
      if el == div(domain_size, 2) do
        {:halt, acc}
      else
        MapSet.put(acc, el)
      end
    end)

    assert MapSet.size(partial_set) == div(domain_size, 2)

  end

end
