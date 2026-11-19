defmodule InPlace.Utils.BitUtilsTest do
  use ExUnit.Case
  alias InPlace.BitUtils

  test "set_bit, unset_bit, bit_set?, bit_count, lsb, msb" do
    sample_size = Enum.random(1..64)
    random_positions = Enum.take_random(0..63, sample_size)
    ## Set bits
    res = Enum.reduce(random_positions, 0, fn p, acc -> BitUtils.set_bit(acc, p) end)

    assert BitUtils.bit_count(res) == sample_size

    assert Enum.all?(0..63, fn p ->
             bit_set? = BitUtils.bit_set?(res, p)

             if p in random_positions do
               bit_set?
             else
               !bit_set?
             end
           end)

    ## lsb/msb
    assert BitUtils.lsb(res) == Enum.min(random_positions)
    assert BitUtils.msb(res) == Enum.max(random_positions)

    ## Unset positions
    res = Enum.reduce(random_positions, 0, fn p, acc -> BitUtils.unset_bit(acc, p) end)

    assert BitUtils.bit_count(res) == 0

    assert Enum.all?(0..63, fn p ->
             !BitUtils.bit_set?(res, p)
           end)

    assert is_nil(BitUtils.lsb(res))
    assert is_nil(BitUtils.msb(res))
  end

  test "unset_left, unset_right" do
    random_n = Enum.random(1..10_000)
    assert BitUtils.unset_left(random_n, 0) == random_n
    assert BitUtils.unset_right(random_n, 0) in [0, 1]

    random_set = Enum.take_random(1..10_000, 100)

    Enum.each(random_set, fn n ->
      random_position = Enum.random(0..63)
      n = BitUtils.set_bit(n, random_position)

      assert BitUtils.unset_left(n, random_position) |> BitUtils.to_list() |> hd() ==
               random_position

      assert BitUtils.unset_right(n, random_position) |> BitUtils.to_list() |> List.last() ==
               random_position
    end)
  end
end
