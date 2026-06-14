defmodule InPlace.UnionFindTest do
  use ExUnit.Case

  alias InPlace.{UnionFind, Array}

  test "operations" do
    uf_size = 10
    uf = UnionFind.new(uf_size)
    assert Enum.map(1..uf.size, fn el ->
      UnionFind.set_size(uf, el) == 1
      && UnionFind.find(uf, el) == el
    end)

    UnionFind.union(uf, 1, 2)
    UnionFind.union(uf, 1, 3)
    UnionFind.union(uf, 2, 4)
    set_of_4 = [1, 2, 3, 4]

    assert Enum.all?(set_of_4, fn el -> UnionFind.set_size(uf, el) == 4 end)
    ## Unite elements that are already in a subset does not change anything
    UnionFind.union(uf, 1, 4)
    assert Enum.all?(set_of_4, fn el -> UnionFind.set_size(uf, el) == 4 end)

    assert Enum.all?(Enum.to_list(1..uf_size) -- set_of_4, fn el ->
      UnionFind.set_size(uf, el) == 1
    end)

    num_sets = Array.to_list(uf.parent) |> Enum.frequencies()
    ## One subset has 4 members, others have a single element each
    assert map_size(num_sets) == uf_size - 4 + 1
  end

end
