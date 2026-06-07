defmodule InPlace.Utils.BitUtilsTest do
  use ExUnit.Case
  alias InPlace.BitUtils

  test "set_bit, unset_bit, bit_set?, bit_count, lsb, msb" do
    sample_size = Enum.random(1..64)
    random_positions = Enum.take_random(0..63, sample_size)
    ## Set bits
    res = Enum.reduce(random_positions, 0,
      fn p, acc -> BitUtils.set_bit(acc, p)
    end)

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
    res = Enum.reduce(random_positions, 0,
      fn p, acc -> BitUtils.unset_bit(acc, p)
    end)

    assert BitUtils.bit_count(res) == 0

    assert Enum.all?(0..63, fn p ->
      !BitUtils.bit_set?(res, p)
    end)

    assert is_nil(BitUtils.lsb(res))
    assert is_nil(BitUtils.msb(res))

  end
end
