defmodule InPlace.HeapSortTest do
  use ExUnit.Case

  alias InPlace.HeapSort

  describe "HeapSort" do
    test "sort with binary heap (integer values)" do
      data = 1..1_000
      values = Enum.shuffle(data)
      assert Enum.sort(values, :asc) == HeapSort.sort(values, :asc)
      assert Enum.sort(values, :desc) == HeapSort.sort(values, :desc)
    end
  end
end
