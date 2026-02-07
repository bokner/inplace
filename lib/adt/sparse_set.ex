defmodule InPlace.SparseSet do
  @moduledoc """
    Sparse set implementation based on
    https://youtu.be/PUJ_XdmSDZw?si=41ySCBvOdoNCV-zR

    The main purpose is to support delete/undo operations
    on the set, so we can use it for backtracking.

    NOTE:
    The code is intentionally kept close to the material in above video,
    even if it may not adhere to a conventional Elixir style.

    The set is a permutation on 1..domain_size.
    Note: it's different from Knuth's implementation, where the set values are 0-based.

    Options:
    :mapper - function of arity 2. Allows to associate elements of the set with values.
  """

  alias InPlace.Array

  def new(domain_size, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    dom = Array.new(domain_size)
    idom = Array.new(domain_size)
    Enum.each(1..domain_size, fn el ->
      Array.put(dom, el, el)
      Array.put(idom, el, el)
    end)
    size = Array.new(1)
    Array.put(size, 1, domain_size)
    %{
      dom: dom,
      idom: idom,
      mapper: Keyword.get(opts, :mapper),
      dom_size: domain_size,
      size: size
    }
  end

  def delete(set, el) when is_integer(el) and el > 0 do
    case member_impl(set, el) do
      nil -> false
      r -> delete_impl(set, r, el)
    end
  end

  def undelete(set) do
    inc_size(set)
  end

  def size(%{size: size} = _set) do
    Array.get(size, 1)
  end

  def empty?(set) do
    size(set) == 0
  end

  def member?(set, el) do
    member_impl(set, el) && true
  end

  def get(%{mapper: mapper_fun} = set, el) do
    mapper_fun.(set, el)
  end

  defp member_impl(%{idom: idom} = set, el) do
    r = Array.get(idom, el)
    if r <= size(set) do
      r
    end
  end

  defp inc_size(%{size: size, dom_size: dom_size} = _set) do
    Array.update(size, 1, fn s ->
      if s < dom_size do
        s + 1
      end
    end)
  end

  defp delete_impl(%{dom: dom, idom: idom, size: size} = _set, r, el) do
    Array.update(size, 1, fn s ->
      if s > 1 do
        l = Array.get(dom, s)
        Array.put(dom, r, l)
        Array.put(idom, l, r)
        Array.put(dom, s, el)
        Array.put(idom, el, s)
      end
      s - 1
    end)
  end

  defp default_opts() do
    [
      mapper: fn _set, el -> el end
    ]
  end

  def reduce(set, acc, reducer) when is_function(reducer, 2) do
    iterate(set, acc, reducer)
  end

  def each(set, action) when is_function(action, 1) do
    reduce(set, nil, fn el, _acc -> action.(el) end)
    :ok
  end

  def iterate(set, acc, reducer) when is_function(reducer, 2) do
    iterate_impl(set, acc, size(set), reducer)
  end

  defp iterate_impl(_set, acc, 0, _reducer) do
    acc
  end

  defp iterate_impl(%{dom: dom} = set, acc, position, reducer) do
    el = Array.get(dom, position)
    case reducer.(el, acc) do
      {:halt, acc2} -> acc2
      {:cont, acc2} -> iterate_impl(set, acc2, position - 1, reducer)
      acc2 -> iterate_impl(set, acc2, position - 1, reducer)
    end
  end

  def to_list(set) do
    iterate(set, [], fn el, acc -> [el | acc] end)
  end


end
