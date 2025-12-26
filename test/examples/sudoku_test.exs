defmodule InPlace.Examples.SudokuTest do
  use ExUnit.Case

  alias InPlace.Examples.Sudoku
  import CPSolver.Test.Helpers

  describe "4x4" do
    test "instance with two solutions" do
      Sudoku.solve(Sudoku.instance4(), solution_handler: async_solution_handler())

      solutions = flush()
      assert length(solutions) == 2
      assert Enum.all?(solutions, &Sudoku.check_solution/1)
    end

  end

  describe "9x9" do
    test "easy" do
      Sudoku.solve(Sudoku.instance29a_knuth(), solution_handler: async_solution_handler())
      solutions = flush()
      assert length(solutions) == 1
      assert Enum.all?(solutions, &Sudoku.check_solution/1)
    end
  end

  defp async_solution_handler() do
    fn solution -> send(self(), solution) end
  end

end
