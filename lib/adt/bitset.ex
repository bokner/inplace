defmodule InPlace.BitSet do
  @moduledoc """
  Bitset is functionally close to MapSet.
  The main difference is taht one has to decide on lower and upper bounds
  for set values upfront.
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
      size: Array.new(1, 0)
    }
  end

  def put(%{bit_vector: bit_vector, size: size, offset: offset, lower_bound: lower_bound, upper_bound: upper_bound} = set, element)
      when is_integer(element) do
    if element < lower_bound or element > upper_bound do
      throw(:value_out_of_bounds)
    end

    position = value_to_offset(offset, element)

    if member_impl(set, position) do
      :ok
    else
      :bit_vector.set(bit_vector, position)
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

  def iterate_impl(_set, acc, nil, _reducer) do
    acc
  end

  def iterate_impl(%{offset: offset} = set, acc, {block_idx, block_offset} = position, reducer) do
    value_at_position = (block_idx - 1) * 64 + block_offset - offset
    case reducer.(value_at_position, acc) do
      {:halt, acc2} -> acc2
      {:cont, acc2} -> iterate_impl(set, acc2, next_position(set, position), reducer)
      acc2 -> iterate_impl(set, acc2, next_position(set, position), reducer)
    end
  end

  def first_position(set) do
    if size(set) > 0 do
      next_position(set, 1, -1)
    end
  end

  @doc """
  Find next position for {block_idx, block_offset}
  """
  def next_position(set, {block_idx, block_offset} = _value_position) do
    next_position(set, block_idx, block_offset)
  end

  def next_position(%{bit_vector: {:bit_vector, atomics}, last_index: last_idx} = set, block_idx, block_offset) do
    case Array.get(atomics, block_idx) do
      0 ->
        ## nothing in this block, try next one.
        block_idx < last_idx && next_position(set, block_idx + 1, -1)
      block_value ->
        ## Reset all leftmost bits up to block_offset
        ## Take LSB - this will give an offset of next bit set to 1
        shift = block_offset + 1
        new_block_offset = (block_value >>> shift) |> lsb()
        {block_idx, new_block_offset + shift}
      end
  end

  ## Find the index of atomics where the `n` value resides
  defp block_index(value) do
    div(value, 64) + 1
  end

  ## Given the value, find block index (that is a position in bit vector)
  ## and an offset of the value relative to the beginning of the blokc
  def value_address(value) do
    {block_index(value), rem(value, 64)}
  end

  def to_list(set) do
  end

  def size(%{size: size} = set) do
    Array.get(size, 1)
  end

  def disjoint?(set1, set2) do
  end

  def intersection(set1, set2) do
  end

  def union(set1, set2) do
  end

  def subset?(set1, set2) do
  end

  def equal?(set1, set2) do
  end

  def first(set) do
  end

  def last(set) do
  end

  def next(set, element) do
  end

  def previous(set, element) do
  end

  def reduce(set, acc, reducer) when is_function(reducer, 2) do
  end

  def filter(set, filter_fun) when is_function(filter_fun, 1) do
  end
end
