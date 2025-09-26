defmodule InPlace.HeapSortTest do
  use ExUnit.Case

  alias InPlace.HeapSort

  describe "HeapSort" do
    test "sort" do
      values = Enum.take_random(1..100, 50)
      assert Enum.sort(values, :asc) == HeapSort.sort(values, :asc)
      assert Enum.sort(values, :desc) == HeapSort.sort(values, :desc)
    end
  end
end
