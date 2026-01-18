defmodule InPlace.BitSet do
  @moduledoc """
  Bitset is functionally close to MapSet.
  The main difference is taht one has to decide on lower and upper bounds
  for set values upfront.
  """
  alias InPlace.Array

  def new(lower_bound, upper_bound) when is_integer(lower_bound) and is_integer(upper_bound)
    and lower_bound <= upper_bound do
    :bit_vector.new(upper_bound - lower_bound + 1)
    %{
      bit_vector: :bit_vector.new(upper_bound - lower_bound + 1),
      offset: -lower_bound,
      size: Array.new(1, 0)
    }
  end

  def put(%{bit_vector: bit_vector, size: size, offset: offset} = set, element) when is_integer(element) do
    position = value_to_offset(offset, element)
    if member_impl(set, position) do
      :ok
    else
      :bit_vector.set(bit_vector, position)
      Array.update(size, 1, fn current_size -> current_size + 1 end)
    end
  end

  def delete(%{offset: offset, bit_vector: bit_vector, size: size} = set, element) when is_integer(element) do
    position = value_to_offset(offset, element)
    if !member_impl(set, position) do
      :ok
    else
      :bit_vector.clear(bit_vector, element)
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
