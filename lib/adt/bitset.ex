defmodule InPlace.BitSet do
  @moduledoc """
  BitSet is close in functionality to MapSet with integer values a s members.
  The main difference is that BitSet has lower and upper bounds
  for set values that have to be defined at the time of creation (see new/2).
  """
  alias InPlace.Array
  import Bitwise
  import InPlace.BitUtils

  def new(lower_bound, upper_bound)
      when is_integer(lower_bound) and is_integer(upper_bound) and
             lower_bound <= upper_bound do
    {:bit_vector, atomics} = bit_vector = :bit_vector.new(upper_bound - lower_bound + 1)

    %{
      lower_bound: lower_bound,
      upper_bound: upper_bound,
      bit_vector: bit_vector,
      offset: -lower_bound,
      last_index: :atomics.info(atomics).size,
      size: Array.new(1, 0),
      minmax:
        Array.new(2)
        |> tap(fn arr ->
          Array.put(arr, 1, Array.inf())
          Array.put(arr, 2, Array.negative_inf())
        end)
    }
  end

  def put(
        %{
          bit_vector: bit_vector,
          size: size,
          offset: offset,
          lower_bound: lower_bound,
          upper_bound: upper_bound
        } = set,
        element
      )
      when is_integer(element) do
    if element < lower_bound or element > upper_bound do
      throw(:value_out_of_bounds)
    end

    position = value_to_offset(offset, element)

    if member_impl(set, position) do
      :ok
    else
      :bit_vector.set(bit_vector, position)
      ## TODO: look into element value
      update_max(set, element)
      update_min(set, element)
      ## end of TODO

      Array.update(size, 1, fn current_size -> current_size + 1 end)
    end
  end

  def delete(%{offset: offset, bit_vector: bit_vector, size: size} = set, element)
      when is_integer(element) do
    position = value_to_offset(offset, element)

    if !member_impl(set, position) do
      :ok
    else
      :bit_vector.clear(bit_vector, position)
      maybe_tighten_min(set, element)
      maybe_tighten_max(set, element)
      Array.update(size, 1, fn current_size -> current_size - 1 end)
    end
  end

  def member?(%{offset: offset} = set, element) when is_integer(element) do
    offset_value = value_to_offset(offset, element)
    member_impl(set, offset_value)
  end

  defp member_impl(%{bit_vector: bit_vector} = _set, offset_value) do
    :bit_vector.get(bit_vector, offset_value) == 1
  end

  defp offset_to_value(offset, value) do
    value - offset
  end

  defp value_to_offset(offset, value) do
    value + offset
  end

  def iterate(set, acc, reducer) when is_function(reducer, 2) do
    iterate_impl(set, acc, first_position(set), reducer)
  end

  defp iterate_impl(_set, acc, nil, _reducer) do
    acc
  end

  defp iterate_impl(set, acc, position, reducer) do
    case reducer.(value_at_position(set, position), acc) do
      {:halt, acc2} -> acc2
      {:cont, acc2} -> iterate_impl(set, acc2, next_position(set, position), reducer)
      acc2 -> iterate_impl(set, acc2, next_position(set, position), reducer)
    end
  end

  def value_at_position(set, {block_idx, block_offset, _}) do
    value_at_position(set, block_idx, block_offset)
  end

  def value_at_position(set, {block_idx, block_offset}) do
    value_at_position(set, block_idx, block_offset)
  end

  def value_at_position(%{offset: offset} = _set, block_idx, block_offset) do
    offset_to_value(
      offset,
      (block_idx - 1) * 64 + block_offset
    )
  end

  defp first_position(set) do
    if size(set) > 0 do
      next_position(set, 1, -1)
    end
  end

  @doc """
  Find next position for {block_idx, block_offset}
  """
  def next_position(set, {block_idx, block_offset} = _value_position) do
    next_position(set, {block_idx, block_offset, nil})
  end

  def next_position(set, {block_idx, block_offset, block_value} = _value_position) do
    next_position(set, block_idx, block_offset, block_value)
  end

  def next_position(set, block_idx, block_offset) do
    next_position(set, block_idx, block_offset, nil)
  end

  def next_position(%{last_index: last_idx} = _set, block_idx, _block_offset, _block_value)
      when block_idx > last_idx do
    nil
  end

  ## The beginning of a new block
  def next_position(%{bit_vector: {:bit_vector, atomics}} = set, block_idx, -1, _block_value) do
    case Array.get(atomics, block_idx) do
      0 ->
        next_position(set, block_idx + 1, -1)

      block_value ->
        case lsb(block_value) do
          nil ->
            next_position(set, block_idx + 1, -1)

          lsb ->
            {block_idx, lsb, block_value}
        end
    end
  end

  def next_position(
        %{bit_vector: {:bit_vector, atomics}} = set,
        block_idx,
        block_offset,
        block_value
      ) do
    case block_value || Array.get(atomics, block_idx) do
      0 ->
        ## nothing in this block, try next one.
        next_position(set, block_idx + 1, -1)

      block_value ->
        ## Reset all leftmost bits up to block_offset
        ## Take LSB - this will give an offset of next bit set to 1
        shift = block_offset + 1
        block_tail = block_value >>> shift

        case block_tail |> lsb() do
          nil ->
            next_position(set, block_idx + 1, -1)

          new_block_offset ->
            {block_idx, new_block_offset + shift, block_value}
        end
    end
  end

  ## Find the index of atomics where the `n` value resides
  defp block_index(value) do
    div(value, 64) + 1
  end

  ## Given the value, find block index (that is a position in bit vector)
  ## and an offset of the value relative to the beginning of the block
  def value_address(value) do
    {block_index(value), rem(value, 64)}
  end

  def to_list(set) do
    iterate(set, [], fn val, acc -> [val | acc] end) |> Enum.reverse()
  end

  def size(%{size: size} = _set) do
    Array.get(size, 1)
  end

  def empty?(set) do
    size(set) == 0
  end

  def subset?(set1, set2) do
    size1 = size(set1)
    size2 = size(set2)

    if size1 > size2 do
      false
    else
      iterate(set1, true, fn val, _acc ->
        (member?(set2, val) && {:cont, true}) || {:halt, false}
      end)
    end
  end

  def equal?(set1, set2) do
    size(set1) == size(set2) && subset?(set1, set2)
  end

  def disjoint?(set1, set2) do
    size1 = size(set1)
    size2 = size(set2)

    if size1 == 0 || size2 == 0 do
      true
    else
      {smaller, bigger} = (size1 < size2 && {set1, set2}) || {set2, set1}

      iterate(smaller, true, fn value, _ ->
        (member?(bigger, value) && {:halt, false}) || {:cont, true}
      end)
    end
  end

  def intersection(set1, set2) do
    lb = min(set1.lower_bound, set2.lower_bound)
    ub = max(set1.upper_bound, set2.upper_bound)
    {smaller, bigger} = (size(set1) < size(set2) && {set1, set2}) || {set2, set1}

    new(lb, ub)
    |> tap(fn intersection_set ->
      iterate(smaller, nil, fn val, _ ->
        member?(bigger, val) && put(intersection_set, val)
      end)
    end)
  end

  def union(set1, set2) do
    lb = min(set1.lower_bound, set2.lower_bound)
    ub = max(set1.upper_bound, set2.upper_bound)

    new(lb, ub)
    |> tap(fn union_set ->
      iterate(set1, nil, fn val, _ -> put(union_set, val) end)
      iterate(set2, nil, fn val, _ -> put(union_set, val) end)
    end)
  end

  def min(set) do
    if size(set) > 0 do
      min_impl(set)
    end
  end

  defp min_impl(%{minmax: minmax} = _set) do
    Array.get(minmax, 1)
  end

  def update_min(%{minmax: minmax} = set, value) do
    if min_impl(set) > value do
      Array.put(minmax, 1, value)
    end

    :ok
  end

  def maybe_tighten_min(%{minmax: minmax} = set, removed_value) do
    if min_impl(set) == removed_value do
      Array.put(minmax, 1, find_min(set, removed_value) || Array.inf())
    end
  end

  def find_min(
        %{offset: value_offset, bit_vector: {:bit_vector, atomics}, last_index: last_idx} = set,
        starting_value
      ) do
    {min_block_idx, _min_block_offset} = value_address(starting_value + value_offset)

    _new_min_value =
      Enum.reduce_while(min_block_idx..last_idx, nil, fn block_idx, acc ->
        case Array.get(atomics, block_idx) do
          0 ->
            {:cont, acc}

          block_value ->
            {:halt, value_at_position(set, block_idx, lsb(block_value))}
        end
      end)
  end

  def max(set) do
    if size(set) > 0 do
      max_impl(set)
    end
  end

  defp max_impl(%{minmax: minmax} = _set) do
    Array.get(minmax, 2)
  end

  def update_max(%{minmax: minmax} = set, value) do
    if max_impl(set) < value do
      Array.put(minmax, 2, value)
    end

    :ok
  end

  def maybe_tighten_max(%{minmax: minmax} = set, removed_value) do
    if max_impl(set) == removed_value do
      Array.put(minmax, 2, find_max(set, removed_value) || Array.negative_inf())
      :todo
    end

    :ok
  end

  def find_max(%{offset: value_offset, bit_vector: {:bit_vector, atomics}} = set, starting_value) do
    {max_block_idx, _max_block_offset} = value_address(starting_value + value_offset)

    _new_max_value =
      Enum.reduce_while(1..max_block_idx, nil, fn block_idx, acc ->
        case Array.get(atomics, block_idx) do
          0 ->
            {:cont, acc}

          block_value ->
            {:halt, value_at_position(set, block_idx, msb(block_value))}
        end
      end)
  end

  def next(%{offset: value_offset} = set, element) do
    current_position = value_address(element + value_offset)

    case next_position(set, current_position) do
      nil ->
        nil

      {block_id, block_offset, _block_value} = _next_pos ->
        value_at_position(set, block_id, block_offset)
    end
  end

  def reduce(set, acc, reducer) when is_function(reducer, 2) do
    iterate(set, acc, reducer)
  end

  def filter(set, filter_fun) when is_function(filter_fun, 1) do
    new(set.lower_bound, set.upper_bound)
    |> tap(fn f_set ->
      iterate(set, nil, fn val, _ ->
        filter_fun.(val) && put(f_set, val)
      end)
    end)
  end
end
