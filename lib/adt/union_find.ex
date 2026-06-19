defmodule InPlace.UnionFind do
  @moduledoc """
  Union-find (a.k.a. DSU)

  https://en.wikipedia.org/wiki/Disjoint-set_data_structure

  The (fixed-length) set is represented by the set of integer indices.
  """
  alias InPlace.Array

  def new(size) when is_integer(size) and size > 0 do
    parent = Array.new(size)
    Enum.each(1..size, fn idx -> Array.put(parent, idx, idx) end)

    set_size = Array.new(size, 1)

    %{
      parent: parent,
      set_size: set_size,
      size: size
    }
  end

  def find(%{parent: parent, size: size} = uf, v) when is_integer(v) and v <= size and v > 0 do
    case Array.get(parent, v) do
      p when p == v ->
        p

      p ->
        find(uf, p)
        |> tap(fn leader -> Array.put(parent, v, leader) end)
    end
  end

  def find(_uf, _v) do
    nil
  end

  def union(%{parent: parent, set_size: set_size, size: size} = uf, a, b)
      when is_integer(a) and is_integer(b) and a <= size and a > 0 and b <= size and b > 0 do
    a = find(uf, a)
    b = find(uf, b)

    if a != b do
      size_a = Array.get(set_size, a)
      size_b = Array.get(set_size, b)

      {a, b, size_a, size_b} =
        if size_a < size_b do
          {b, a, size_b, size_a}
        else
          {a, b, size_a, size_b}
        end

      Array.put(parent, b, a)
      Array.put(set_size, a, size_a + size_b)
    end
  end

  def union(_uf, a, b) do
    {:error, :some_of_args_invalid, {a, b}}
  end

  def set_size(%{parent: parent, set_size: set_size}, el) do
    p = Array.get(parent, el)
    Array.get(set_size, p)
  end
end
