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
    {:bit_vector, atomics} = bit_vector = :bit_vector.new(upper_bound - lower_bound + 64)

    %{
      lower_bound: lower_bound,
      upper_bound: upper_bound,
      offset: compute_offset(lower_bound), ## to have lower bound value in the first block
      bit_vector: bit_vector,
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
      increase_size(set, 1)
    end
  end

  def delete(%{offset: offset, bit_vector: bit_vector} = set, element)
      when is_integer(element) do
    position = value_to_offset(offset, element)

    if !member_impl(set, position) do
      :ok
    else
      :bit_vector.clear(bit_vector, position)
      maybe_tighten_min(set, element)
      maybe_tighten_max(set, element)
      decrease_size(set, 1)
    end
  end

  def member?(%{lower_bound: lb, offset: offset, upper_bound: ub} = set, element)
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

  def compute_offset(lower_bound) do
    ## align to the address of the block next to the lower bound value
    positive = (div(lower_bound, 64)) * 64

    if lower_bound < 0 do
      -64 + positive
    else
      positive
    end
  end

  defp offset_to_value(offset, value) do
    value + offset
  end

  def value_to_offset(offset, value) do
    value - offset
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

  ## Find next position for {block_idx, block_offset}
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
    value_address(value - set.offset)
  end

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

  def empty_set() do
    new(0, 0)
  end

  def intersection(set1, set2) do
    intersection_v2(set1, set2)
  end

  def intersection_v1(set1, set2) do
    if empty?(set1) || empty?(set2) do
      empty_set()
    else
      min1 = min(set1)
      min2 = min(set2)
      {lb, set_with_lb, set2} =
        min1 >= min2 && {min1, set1, set2}
        || {min2, set2, set1}
      ub = min(max(set1), max(set2))

      if lb > ub do
        empty_set()
      else
        new(lb, ub)
        |> tap(fn intersection_set ->

        iterate(set_with_lb, nil, fn val, _ ->
            val > ub && {:halt, false}
            || member?(set2, val) && put(intersection_set, val)
          end)
        end)
      end
    end
  end

  def intersection_v2(set1, set2) do
  if empty?(set1) || empty?(set2) do
      empty_set()
    else
      min1 = min(set1)
      min2 = min(set2)
      {leading_set_min, leading_set, set2} =
        min1 >= min2 && {min1, set1, set2}
        || {min2, set2, set1}
      intersection_ub = min(max(set1), max(set2))

      if leading_set_min > intersection_ub do
        empty_set()
      else
        new(leading_set_min, intersection_ub)
        |> tap(fn intersection_set ->
          build_intersection(intersection_set, leading_set, set2, leading_set_min, intersection_ub)
        end)
      end
    end
  end

  defp build_intersection(%{bit_vector: {:bit_vector, bit_vector}} = intersection_set, leading_set, trailing_set, leading_set_min, intersection_ub) do
    ## We will iterate over blocks of leading set.
    ## For every block, we will find corresponding (64-bit) value in the trailing set.
    {first_block, _} = value_address(leading_set, leading_set_min)
    {last_block, _} = value_address(leading_set, intersection_ub)
    block_shift = div(leading_set.offset - trailing_set.offset, 64)
    ## We intersect by blocks: block[leading_set, i] with block[trailing_set, i + block_shift]
    Enum.reduce(first_block..last_block, {1, 0, false}, fn block_idx, {block_count, set_size_count, min_value_set?} ->
      block_content = get_block(leading_set, block_idx)
      matching_value = get_block(trailing_set, block_idx + block_shift)
      block_intersection = band(block_content, matching_value)
      {
        block_count + 1,
        set_size_count + update_block(intersection_set, block_count, block_intersection, min_value_set?),
        min_value_set? || block_intersection > 0
      }
    end)
    |> then(fn {block_count, intersection_size, min_value_set?} ->
      if min_value_set? do
        block_count = block_count - 1
        increase_size(intersection_set, intersection_size)

        update_max(intersection_set, :atomics.get(bit_vector, block_count)
        |> msb
        |> Kernel.||(0)
        |> Kernel.+(intersection_set.offset + (block_count - 1) * 64))
      end
    end)
  end

  def get_matching_value(%{bit_vector: {:bit_vector, values}} = _set, block_idx, 0, _bit_shift) do
    Array.get(values, block_idx)
  end

  def update_block(%{bit_vector: {:bit_vector, bit_vector}} = intersection_set, block_idx, content, min_value_set?) do
    Array.put(bit_vector, block_idx, content)

    if content == 0 do
      0
    else
      ## Set the minimum if not yet set
      if !min_value_set? do
        update_min(intersection_set,
        content
        |> lsb
        |> Kernel.+(intersection_set.offset + (block_idx - 1) * 64))
      end
      bit_count(content)
    end

  end

  def union(set1, set2) do
    union_v2(set1, set2)
  end

  def union_v1(set1, set2) do
    lb = min(set1.lower_bound, set2.lower_bound)
    ub = max(set1.upper_bound, set2.upper_bound)

    new(lb, ub)
    |> tap(fn union_set ->
      iterate(set1, nil, fn val, _ -> put(union_set, val) end)
      iterate(set2, nil, fn val, _ -> put(union_set, val) end)
    end)
  end

  def union_v2(set1, set2) do
    if empty?(set1) && empty?(set2) do
      empty_set()
    else
      min1 = min(set1)
      min2 = min(set2)
      ## leading set is the one with lesser of two minimums
      {leading_set_min, leading_set, set2} =
        min1 < min2 && {min1, set1, set2}
        || {min2, set2, set1}
      union_ub = max(max(set1), max(set2))

      new(leading_set_min, union_ub)
      |> tap(fn union_set ->
        build_union(union_set, leading_set, set2, leading_set_min, union_ub)
      end)
    end
  end

  defp build_union(%{bit_vector: {:bit_vector, bit_vector}} = union_set, leading_set, trailing_set, leading_set_min, union_max) do
    ## Get first and last block indices relative to leading set
    {first_block_union, _} = value_address(leading_set, leading_set_min)
    {last_block_union, _} = value_address(leading_set, union_max)
    {last_block_leading_set, _} = value_address(leading_set, max(leading_set))
    {last_block_trailing_set, _} = value_address(trailing_set, max(trailing_set))

    block_shift = div(leading_set.offset - trailing_set.offset, 64)
    ## We union by blocks: block[leading_set, i] with block[trailing_set, i + block_shift]
    Enum.reduce(first_block_union..last_block_union, {1, 0, false}, fn block_idx, {block_count, set_size_count, min_value_set?} ->
      block_content = (block_idx <= last_block_leading_set && get_block(leading_set, block_idx) || 0)
      matching_value = case block_idx + block_shift do
        shifted_block_idx when shifted_block_idx > 0 and shifted_block_idx <= last_block_trailing_set ->
          get_block(trailing_set, shifted_block_idx)
          _ -> 0
        end
      block_union = bor(block_content, matching_value)

      {
        block_count + 1,
        set_size_count + update_block(union_set, block_count, block_union, min_value_set?),
        min_value_set? || block_union > 0
      }
    end)
      |> then(fn {block_count, union_size, min_value_set?} ->
      if min_value_set? do
        block_count = block_count - 1
        increase_size(union_set, union_size)

        update_max(union_set, :atomics.get(bit_vector, block_count)
        |> msb
        |> Kernel.||(0)
        |> Kernel.+(union_set.offset + (block_count - 1) * 64))
      end
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

  defp increase_size(%{size: size} = _set, delta) do
    Array.update(size, 1, fn current_size -> current_size + delta end)
  end

  defp decrease_size(set, delta) do
    increase_size(set, -delta)
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
