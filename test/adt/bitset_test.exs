defmodule InPlace.BitSetTest do
  use ExUnit.Case

  alias InPlace.BitSet

  test "basic operations" do
    lb = -100
    ub = 100
    bitset = BitSet.new(lb, ub)
    assert BitSet.size(bitset) == 0
    assert catch_throw(BitSet.put(bitset, ub + 1)) == :value_out_of_bounds
    assert catch_throw(BitSet.put(bitset, lb - 1)) == :value_out_of_bounds

    rand_val = Enum.random(lb..ub)
    BitSet.put(bitset, rand_val)
    assert BitSet.size(bitset) == 1
    assert BitSet.member?(bitset, rand_val)
    BitSet.delete(bitset, rand_val)
    assert BitSet.size(bitset) == 0
    refute BitSet.member?(bitset, rand_val)
  end

  test "min and max" do
    lb = -100
    ub = 100
    bitset = BitSet.new(lb, ub)
    refute BitSet.min(bitset) || BitSet.max(bitset)
    [val1, val2, val3] = Enum.take_random(lb..ub, 3) |> Enum.sort()
    BitSet.put(bitset, val1)
    assert BitSet.min(bitset) == val1  && BitSet.max(bitset) == val1
    BitSet.put(bitset, val2)
    assert BitSet.min(bitset) == val1  && BitSet.max(bitset) == val2
    BitSet.delete(bitset, val1)
    BitSet.put(bitset, val3)
    assert BitSet.min(bitset) == val2  && BitSet.max(bitset) == val3
    BitSet.delete(bitset, val2)
    BitSet.delete(bitset, val3)
    refute BitSet.min(bitset) || BitSet.max(bitset)
  end

  test "traversal" do
    lb = -100
    ub = 100
    bitset = BitSet.new(lb, ub)
    rand_values = Enum.take_random(lb..ub, Enum.random(1..(ub - lb)))
    Enum.each(rand_values, fn val -> BitSet.put(bitset, val) end)
    sorted_rand_values = Enum.sort(rand_values)
    assert Enum.all?(0..length(rand_values) - 2,
      fn idx -> BitSet.next(bitset, Enum.at(sorted_rand_values, idx)) == Enum.at(sorted_rand_values, idx + 1) end)
  end

  test "iteration" do
    lb = -100
    ub = 100
    bitset = BitSet.new(lb, ub)
    iterator_fun = fn value, acc -> [value | acc] end
    assert Enum.empty?(BitSet.iterate(bitset, [], iterator_fun))
    rand_values = Enum.take_random(lb..ub, Enum.random(1..ub - lb))
    Enum.each(rand_values, fn val -> BitSet.put(bitset, val) end)
    assert Enum.sort(rand_values, :desc) == BitSet.iterate(bitset, [], iterator_fun)
  end
end
