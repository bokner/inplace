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

  test "subset?" do
    set1 = BitSet.new(-10, 10)
    set2 = BitSet.new(-10, 10)
    assert BitSet.subset?(set1, set2)
    BitSet.put(set1, Enum.random(-10..10))
    refute BitSet.subset?(set1, set2)
    assert BitSet.subset?(set2, set1)
  end

  test "equal?" do
    set1 = BitSet.new(1, 10)
    set2 = BitSet.new(-10, 10)
    assert BitSet.equal?(set1, set2)
    Enum.each(1..10, fn val ->
      BitSet.put(set1, val)
      BitSet.put(set2, val)
    end)
    assert BitSet.equal?(set1, set2)
    s = Enum.random([set1, set2])
    BitSet.delete(s, Enum.random(1..10))
    refute BitSet.equal?(set1, set2)
  end

  test "disjoint?" do
    set1 = BitSet.new(-10, 10)
    set2 = BitSet.new(-10, 10)
    assert BitSet.disjoint?(set1, set2)

    {even_values, odd_values} = Enum.split_with(-10..10, fn x  -> rem(x, 2) == 0 end)
    Enum.each(even_values, fn val -> BitSet.put(set1, val) end)
    Enum.each(odd_values, fn val -> BitSet.put(set2, val) end)
    assert BitSet.disjoint?(set1, set2)
    BitSet.put(set1, Enum.random(odd_values))
    refute BitSet.disjoint?(set1, set2)
  end

  test "intersection" do
    set1 = BitSet.new(-10, 10)
    set2 = BitSet.new(-10, 10)
    intersection = BitSet.intersection(set1, set2)
    assert BitSet.empty?(intersection)
    {even_values, odd_values} = Enum.split_with(-10..10, fn x  -> rem(x, 2) == 0 end)
    Enum.each(even_values, fn val -> BitSet.put(set1, val) end)
    Enum.each(odd_values, fn val -> BitSet.put(set2, val) end)

    intersection = BitSet.intersection(set1, set2)
    assert BitSet.empty?(intersection)

    random_even = Enum.random(even_values)
    random_odd = Enum.random(odd_values)
    BitSet.put(set1, random_odd)
    BitSet.put(set2, random_even)
    intersection = BitSet.intersection(set1, set2)
    assert BitSet.to_list(intersection) == [random_even, random_odd] |> Enum.sort()

  end

  test "union" do
    set1 = BitSet.new(-10, 10)
    set2 = BitSet.new(-10, 10)
    union = BitSet.union(set1, set2)
    assert BitSet.empty?(union)
    {even_values, odd_values} = Enum.split_with(-10..10, fn x  -> rem(x, 2) == 0 end)
    Enum.each(even_values, fn val -> BitSet.put(set1, val) end)
    Enum.each(odd_values, fn val -> BitSet.put(set2, val) end)
    union = BitSet.union(set1, set2)
    assert BitSet.to_list(union) == Enum.to_list(-10..10)
  end

  test "filter" do
    set = BitSet.new(-10, 10)
    Enum.each(-10..10, fn val -> BitSet.put(set, val) end)
    {even_values, odd_values} = Enum.split_with(-10..10, fn x  -> rem(x, 2) == 0 end)
    even_set = BitSet.filter(set, fn x  -> rem(x, 2) == 0 end)
    odd_set = BitSet.filter(set, fn x  -> rem(x, 2) in [-1, 1] end)
    assert BitSet.to_list(even_set) == even_values
    assert BitSet.to_list(odd_set) == odd_values
  end
end
