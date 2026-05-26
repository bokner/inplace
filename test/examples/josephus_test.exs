defmodule InPlace.Examples.JosephusTest do
  use ExUnit.Case

  alias InPlace.Examples.Josephus

  test "the cases with known answers (N = 41, k = 2, 3)" do
    ## Original story
    assert 19 == hd(Josephus.solve(41, 2))
    ## Wikipedia example
    assert 31 == hd(Josephus.solve(41, 3))
  end
end
