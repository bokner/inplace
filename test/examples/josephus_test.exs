defmodule InPlace.Examples.JosephusTest do
  use ExUnit.Case

  alias InPlace.Examples.Josephus

  test "the case with known answer (N = 41, k = 2)" do
    assert 19 == Josephus.solve(41, 2)
  end
end
