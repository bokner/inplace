defmodule InPlace.BitSet do
  @moduledoc """
  BitSet is close in functionality to MapSet with integer values as members.
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
        Array.new(2, 0)
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
      update_min(set, element)
      update_max(set, element)
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

  def member?(%{offset: offset, lower_bound: lb, upper_bound: ub} = set, element)
      when is_integer(element) do
    element >= lb && element <= ub &&
      (
        offset_value = value_to_offset(offset, element)
        member_impl(set, offset_value)
      )
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
      next_position(set, 1, :lsb)
    end
  end

  defp last_block(set) do
    case max(set) do
      nil ->
        0

      max_value ->
        value_address(set, max_value)
        |> elem(0)
    end
  end

  defp get_block(%{bit_vector: {:bit_vector, atomics}} = _set, block_idx) do
    ## Note: we do not use Array.get/2 here because of possible mix-up
    ## between 0s and how Array differentiates between 0s and `nil`s
    :atomics.get(atomics, block_idx)
  end

  @doc """
  Find next position for {block_idx, block_offset}
  """
  defp next_position(set, {block_idx, block_offset} = _value_position) do
    next_position(set, {block_idx, block_offset, nil})
  end

  defp next_position(set, {block_idx, block_offset, block_value} = _value_position) do
    next_position(set, block_idx, block_offset, block_value)
  end

  defp next_position(set, block_idx, block_offset) do
    next_position(set, block_idx, block_offset, nil)
  end

  defp next_position(set, block_idx, block_offset, block_value) do
    if block_idx <= last_block(set) do
      next_position_impl(set, block_idx, block_offset, block_value)
    end
  end

  ## The beginning of a new block
  defp next_position_impl(set, block_idx, :lsb, _block_value) do
    case get_block(set, block_idx) do
      0 ->
        next_position(set, block_idx + 1, :lsb)

      block_value ->
        case lsb(block_value) do
          nil ->
            next_position(set, block_idx + 1, :lsb)

          lsb ->
            {block_idx, lsb, block_value}
        end
    end
  end

  defp next_position_impl(
         set,
         block_idx,
         block_offset,
         block_value
       ) do
    case block_value || get_block(set, block_idx) do
      0 ->
        ## nothing in this block, try next one.
        next_position(set, block_idx + 1, :lsb)

      block_value ->
        ## Reset all leftmost bits up to block_offset
        ## Take LSB - this will give an offset of next bit set to 1
        shift = block_offset + 1
        block_tail = block_value >>> shift

        case block_tail |> lsb() do
          nil ->
            next_position(set, block_idx + 1, :lsb)

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
  def value_address(set, value) do
    value_with_offset = value + set.offset
    {block_index(value_with_offset), rem(value_with_offset, 64)}
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
    lb = max(min(set1), min(set2)) || 0
    ub = min(max(set1), max(set2)) || 0

    if lb > ub do
      new(0, 0)
    else
      new(lb, ub)
      |> tap(fn intersection_set ->
        start_position =
          case (member?(set1, lb) && lb) || next(set1, lb) do
            nil ->
              nil

            start_position ->
              value_address(set1, start_position)
          end

        iterate_impl(set1, nil, start_position, fn val, _ ->
          if val > ub do
            {:halt, false}
          else
            member?(set2, val) && put(intersection_set, val)
          end
        end)
      end)
    end
  end

  def intersection2(set1, set2) do
    min_value = max(set1.lower_bound, set2.lower_bound)
    max_value = min(set1.upper_bound, set2.upper_bound)

    new(min_value, max_value)
    |> tap(fn intersection_set ->
      if min_value > max_value do
        ## Empty intersection
        :ok
      else
        {lb_block, _} = value_address(set1, min_value)
        {ub_block, _} = value_address(set1, max_value)
        ## The relative position of set
        position_shift = set1.lower_bound - set2.lower_bound
        Enum.each(lb_block..ub_block, fn block_idx ->
          case get_block(set1, block_idx) do
            0 -> :ok
            block_content ->
              matching_content = get_matching_block(set2, block_idx)
              update_block(intersection_set, block_idx, band(block_content, matching_content))
          end
        end)
      end
    end)
  end


  def get_matching_block(set, block_idx) do
    ## Given block id, calculate the value of the block
    ## shifted to the right by the lower bound (or to the left by the offset)

    ## Find the value represented by the position at the block start
    value_at_block_start = (block_idx - 1) * 64
    {block_position, _block_offset} =  value_address(set, value_at_block_start)
    #TODO
    #block_position
  end

  def update_block(set, block_idx, content) do
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

  def difference(set1, set2) do
    filter(set1, fn val -> !member?(set2, val) end)
  end

  def symmetric_difference(set1, set2) do
    lb = min(set1.lower_bound, set2.lower_bound)
    ub = max(set1.upper_bound, set2.upper_bound)

    new(lb, ub)
    |> tap(fn sym_diff_set ->
      iterate(set1, nil, fn val, _ -> put(sym_diff_set, val) end)

      iterate(set2, nil, fn val, _ ->
        (member?(sym_diff_set, val) && delete(sym_diff_set, val)) || put(sym_diff_set, val)
      end)
    end)
  end

  defp matching_block(set1, set2, block_idx) do
    ## Find block in set2 that has the same value addresses as
    ## block with `block_idx` index in set1
    shift = set1.lower_bound - set2.lower_bound
    block_shift = div(shift, 64)
    matching_block = block_idx + block_shift

    cond do
      matching_block < 0 ->
        nil

      set2.last_index < matching_block ->
        nil

      true ->
        matching_block
    end
  end

  def min(set) do
    if size(set) > 0 do
      min_impl(set)
    end
  end

  defp min_impl(%{minmax: minmax} = _set) do
    Array.get(minmax, 1)
  end

  defp update_min(%{minmax: minmax} = set, value) do
    if min_impl(set) > value do
      Array.put(minmax, 1, value)
    end

    :ok
  end

  defp maybe_tighten_min(%{minmax: minmax} = set, removed_value) do
    if min_impl(set) == removed_value do
      Array.put(minmax, 1, find_min(set, removed_value) || Array.inf())
    end
  end

  defp find_min(
         %{last_index: last_idx} = set,
         starting_value
       ) do
    {min_block_idx, _min_block_offset} = value_address(set, starting_value)

    _new_min_value =
      Enum.reduce_while(min_block_idx..last_idx, nil, fn block_idx, acc ->
        case get_block(set, block_idx) do
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

  defp update_max(%{minmax: minmax} = set, value) do
    if max_impl(set) < value do
      Array.put(minmax, 2, value)
    end

    :ok
  end

  defp maybe_tighten_max(%{minmax: minmax} = set, removed_value) do
    if max_impl(set) == removed_value do
      Array.put(minmax, 2, find_max(set, removed_value) || Array.negative_inf())
    end

    :ok
  end

  defp find_max(set, starting_value) do
    {max_block_idx, _max_block_offset} = value_address(set, starting_value)

    _new_max_value =
      Enum.reduce_while(1..max_block_idx, nil, fn block_idx, acc ->
        case get_block(set, block_idx) do
          0 ->
            {:cont, acc}

          block_value ->
            {:halt, value_at_position(set, block_idx, msb(block_value))}
        end
      end)
  end

  def next(set, element) do
    current_position = value_address(set, element)

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
