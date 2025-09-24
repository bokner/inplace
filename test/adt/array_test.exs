defmodule InPlace.ArrayTest do
  use ExUnit.Case

  alias InPlace.Array

  test "operations" do
    array = Array.new(10)
    refute Enum.any?(1..10, fn idx -> Array.get(array, idx) end)
    Array.put(array, 1, 100)
    assert Array.get(array, 1) == 100
    Array.update(array, 1, fn existing -> 2 * existing end)
    assert Array.get(array, 1) == 200
    Array.put(array, 2, 101)
    Array.swap(array, 1, 2)
    assert Array.get(array, 1) == 101 && Array.get(array, 2) == 200
  end
end
