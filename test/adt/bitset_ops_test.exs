  defmodule InPlace.BitSetOpsTest do
  use ExUnit.Case

  alias InPlace.BitSet

  ## Tests here mirror the MapSet tests from Elixit test suite
  ## for:
  ## - union/2
  ## - intersection/2
  ## - difference/2
  ## - symmetric_difference/2
  ## - disjoint?/2
  ## - subset?/2
  ##
  test "union/2" do
    result = BitSet.union(BitSet.new([1, 3, 4]), BitSet.empty_set())
    assert BitSet.equal?(result, BitSet.new([1, 3, 4]))

    result = BitSet.union(BitSet.new(5..15), BitSet.new(10..25))
    assert BitSet.equal?(result, BitSet.new(5..25))

    result = BitSet.union(BitSet.new(1..120), BitSet.new(1..100))
    assert BitSet.equal?(result, BitSet.new(1..120))
  end

  test "intersection/2" do
    result = BitSet.intersection(BitSet.empty_set(), BitSet.new(1..21))
    assert BitSet.equal?(result, BitSet.empty_set())

    result = BitSet.intersection(BitSet.new(1..21), BitSet.new(4..24))
    assert BitSet.equal?(result, BitSet.new(4..21))

    result = BitSet.intersection(BitSet.new(2..100), BitSet.new(1..120))
    assert BitSet.equal?(result, BitSet.new(2..100))
  end

  test "difference/2" do
    result = BitSet.difference(BitSet.new(2..20), BitSet.empty_set())
    assert BitSet.equal?(result, BitSet.new(2..20))

    result = BitSet.difference(BitSet.new(2..20), BitSet.new(1..21))
    assert BitSet.equal?(result, BitSet.empty_set())

    result = BitSet.difference(BitSet.new(1..101), BitSet.new(2..100))
    assert BitSet.equal?(result, BitSet.new([1, 101]))
  end

  test "symmetric_difference/2" do
    result = BitSet.symmetric_difference(BitSet.new(1..5), BitSet.new(3..8))
    assert BitSet.equal?(result, BitSet.new([1, 2, 6, 7, 8]))

    result = BitSet.symmetric_difference(BitSet.empty_set(), BitSet.empty_set())
    assert BitSet.equal?(result, BitSet.empty_set())

    result = BitSet.symmetric_difference(BitSet.new(1..5), BitSet.new(1..5))
    assert BitSet.equal?(result, BitSet.empty_set())

    result = BitSet.symmetric_difference(BitSet.new([1, 2, 3]), BitSet.empty_set())
    assert BitSet.equal?(result, BitSet.new([1, 2, 3]))

    result = BitSet.symmetric_difference(BitSet.empty_set(), BitSet.new([1, 2, 3]))
    assert BitSet.equal?(result, BitSet.new([1, 2, 3]))
  end

  test "disjoint?/2" do
    assert BitSet.disjoint?(BitSet.empty_set(), BitSet.empty_set())
    assert BitSet.disjoint?(BitSet.new(1..6), BitSet.new(8..20))
    refute BitSet.disjoint?(BitSet.new(1..6), BitSet.new(5..15))
    refute BitSet.disjoint?(BitSet.new(1..120), BitSet.new(1..6))
  end

  test "subset?/2" do
    assert BitSet.subset?(BitSet.empty_set(), BitSet.empty_set())
    assert BitSet.subset?(BitSet.new(1..6), BitSet.new(1..10))
    assert BitSet.subset?(BitSet.new(1..6), BitSet.new(1..120))
    refute BitSet.subset?(BitSet.new(1..120), BitSet.new(1..6))
  end

end
