defmodule InPlace.SparseSet do
  @moduledoc """
    Sparse set implementation based on
    https://youtu.be/PUJ_XdmSDZw?si=41ySCBvOdoNCV-zR

    The main purpose is to support delete/undo operations
    on the set, so we can use it for backtracking.

    NOTE:
    The code is intentionally kept close to Knuth's style,
    even it may not adhere to a conventional Elixir style.

    TODO: more details
  """

  alias InPlace.Array

  def new(capacity, opts \\ []) do
    ## The elements of the set are initialized with
    ## identity permutation
    opts = Keyword.merge(default_opts(), opts)

    dom = Array.new(capacity)
    idom = Array.new(capacity)
    Enum.each(1..capacity, fn el ->
      Array.put(dom, el, el)
      Array.put(idom, el, el)
    end)
    size = Array.new(1)
    Array.put(size, 1, capacity)
    %{
      dom: dom,
      idom: idom,
      mapper: Keyword.get(opts, :mapper),
      capacity: capacity,
      size: size
    }
  end

  def delete(%{idom: idom} = set, k) when is_integer(k) and k > 0 do
    r = Array.get(idom, k)
    if r <= size(set) do
      delete_impl(set, r, k)
    end
  end

  def undelete(set) do
    inc_size(set)
  end

  def size(%{size: size} = _set) do
    Array.get(size, 1)
  end

  defp inc_size(%{size: size, capacity: capacity} = _set) do
    Array.update(size, 1, fn s ->
      min(capacity, s + 1)
    end)
  end

  defp delete_impl(%{dom: dom, idom: idom, size: size} = _set, r, k) do
    Array.update(size, 1, fn s ->
      if s > 1 do
        l = Array.get(dom, s)
        Array.put(dom, r, l)
        Array.put(idom, l, r)
        Array.put(dom, s, k)
        Array.put(idom, k, s)
      end
      s - 1
    end)
  end

  defp default_opts() do
    [
      mapper: fn array, k -> Array.get(array.data, k) end
    ]
  end

end
