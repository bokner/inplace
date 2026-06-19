defmodule InPlace.UnionFindTest do
  use ExUnit.Case

  alias InPlace.UnionFind

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
    the_rest = Enum.to_list(1..uf_size) -- set_of_4


    assert Enum.all?(set_of_4, fn el -> UnionFind.set_size(uf, el) == 4 end)
    ## Unite elements that are already in a subset does not change anything
    UnionFind.union(uf, 1, 4)
    assert Enum.all?(set_of_4, fn el -> UnionFind.set_size(uf, el) == 4 end)

    assert Enum.all?(the_rest, fn el ->
      UnionFind.set_size(uf, el) == 1
    end)

    ## One subset has 4 members, others have a single element each
    assert count_sets(uf) == uf_size - 4 + 1

    ## Unify everything outside of 'set of 4'
    Enum.each(tl(the_rest), fn el ->
      UnionFind.union(uf, el, hd(the_rest))
    end)

    ## Should have two sets (set of 4 and the rest)
    assert 2 = count_sets(uf)

    ## Unify into a single set
    UnionFind.union(uf, Enum.random(set_of_4), Enum.random(the_rest))

    assert 1 = count_sets(uf)

    assert Enum.all?(1..uf_size, fn el -> UnionFind.set_size(uf, el) == uf_size end)

  end

  test "sanity" do
    uf_size = 10
    uf = UnionFind.new(uf_size)
    refute UnionFind.find(uf, uf_size + 1) || UnionFind.find(uf, 0)

    assert {:error, :some_of_args_invalid, _} = UnionFind.union(uf, 1, 11)
  end

  defp count_sets(uf) do
    Enum.reduce(1..uf.size, MapSet.new(), fn el, acc ->
      MapSet.put(acc, UnionFind.find(uf, el))
    end)
    |> MapSet.size()
  end
end
