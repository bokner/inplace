defmodule InPlace.BitSetTest do
  use ExUnit.Case

  alias InPlace.{BitSet, Array}

  test "basic operations" do
    lb = -100
    ub = 100
    bitset = BitSet.new(lb, ub)
    assert BitSet.size(bitset) == 0
    assert catch_throw(BitSet.put(bitset, ub + 1)) == :value_out_of_bounds
    assert catch_throw(BitSet.put(bitset, lb - 1)) == :value_out_of_bounds

    rand_val = Enum.random(-100..100)
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
    assert BitSet.min(bitset) == Array.negative_inf() && BitSet.max(bitset) == Array.inf()

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
