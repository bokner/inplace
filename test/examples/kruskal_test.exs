defmodule InPlace.Examples.KruskalTest do
  use ExUnit.Case

  test "Example 1" do
    edges = [
        {:A, :B, 5},
        {:A, :D, 4},
        {:A, :E, 1},
        {:B, :C, 4},
        {:B, :D, 2},
        {:C, :H, 4},
        {:C, :I, 1},
        {:C, :J, 2},
        {:D, :E, 2},
        {:D, :F, 5},
        {:D, :G, 11},
        {:D, :H, 2},
        {:E, :F, 1},
        {:F, :G, 7},
        {:G, :H, 1},
        {:G, :I, 4},
        {:H, :I, 6},
        {:I, :J, 0}
      ]


      {edges, weight} = InPlace.Examples.MST.kruskal(edges)

      ## Edges form the tree
      assert length(edges) == 10 - 1

      assert 14 = weight
      assert MapSet.new(edges) == MapSet.new(
        [A: :E, B: :C, B: :D, C: :I, D: :E, D: :H, E: :F, G: :H, I: :J]
      )

    end
  end
