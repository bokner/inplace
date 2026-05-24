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
      max_size: domain_size,
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
    if undelete(set, 1) do
      Array.get(set.dom, size(set))
    end
  end

  def undelete(set, num) do
    inc_size(set, num)
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

  def copy(set) do
    Map.take(set, [:max_size, :mapper])
    |> Map.put(:size, Array.copy(set.size))
    |> Map.put(:dom, Array.copy(set.dom))
    |> Map.put(:idom, Array.copy(set.idom))
  end

  def serialize(set) do
    Map.take(set, [:max_size, :mapper])
    |> Map.put(:size_as_list, Array.to_list(set.size))
    |> Map.put(:dom_as_list, Array.to_list(set.dom))
    |> Map.put(:idom_as_list, Array.to_list(set.idom))
  end

  def deserialize(serialized_set) do
    Map.take(serialized_set, [:max_size, :mapper])
    |> Map.put(:size, Array.from_list(serialized_set.size_as_list))
    |> Map.put(:dom, Array.from_list(serialized_set.dom_as_list))
    |> Map.put(:idom, Array.from_list(serialized_set.idom_as_list))
  end

  defp member_impl(%{idom: idom} = set, el) do
    r = Array.get(idom, el)

    if r <= size(set) do
      r
    end
  end

  defp inc_size(%{size: size, max_size: max_size} = _set, increase)
       when is_integer(increase) and increase > 0 do
    Array.update(size, 1, fn s ->
      s = s + increase

      if s <= max_size do
        s
      end
    end)
  end

  defp inc_size(set, _) do
    size(set)
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

  def reduce(set, initial, reducer) when is_function(reducer, 2) do
    iterate(set, initial, reducer)
  end

  def each(set, action) when is_function(action, 1) do
    reduce(set, nil, fn el, _acc -> action.(el) end)
    :ok
  end

  def iterate(set, initial, reducer) when is_function(reducer, 2) do
    iterate_impl(set, initial, size(set), reducer)
  end

  defp iterate_impl(_set, initial, 0, _reducer) do
    initial
  end

  defp iterate_impl(%{dom: dom} = set, acc, position, reducer) do
    el = Array.get(dom, position)

    case reducer.(el, acc) do
      {:halt, acc2} -> acc2
      {:cont, acc2} -> iterate_impl(set, acc2, position - 1, reducer)
      acc2 -> iterate_impl(set, acc2, position - 1, reducer)
    end
  end

  @doc """
  Iterate over set positions in increasing order (as opposed to iterating over set values).
  This is equivalent to:
  `iterate(set, initial, redicer)`
  , but the above will process set elements in arbitrary order.
  The intent is to not having to sort the result of the iteration.
  This may or may not be more effective than the plain iteration.

  """
  def iterate_ordered(set, mapper) when is_function(mapper, 1) do
    iterate_ordered(set, [], fn pos, acc -> [mapper.(pos) | acc ] end) |> Enum.reverse()
  end

  def iterate_ordered(set, initial, reducer) when is_function(reducer, 2) do
    case size(set) do
      0 ->
        initial

      set_size ->
        Enum.reduce_while(1..set.max_size, {set_size, initial}, fn pos,
                                                                   {count_remainder, result_acc} =
                                                                     acc ->
          if member?(set, pos) do
            case apply_reduction(pos, result_acc, reducer) do
              {:cont, result_acc} ->
                ## Check if we've seen all set members
                count_remainder = count_remainder - 1

                if count_remainder == 0 do
                  {:halt, {0, result_acc}}
                else
                  {:cont, {count_remainder, result_acc}}
                end

              {:halt, result_acc} ->
                {:halt, {count_remainder, result_acc}}
            end
          else
            ## Position is not a member of the set
            {:cont, acc}
          end
        end)
        |> elem(1)
    end
  end

  def to_list(set) do
    iterate(set, [], fn el, acc -> [el | acc] end)
  end

  defp apply_reduction(el, acc, reducer) do
    case reducer.(el, acc) do
      {:halt, acc2} -> {:halt, acc2}
      {:cont, acc2} -> {:cont, acc2}
      acc2 -> {:cont, acc2}
    end
  end
end
