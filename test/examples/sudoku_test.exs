defmodule InPlace.Examples.SudokuTest do
  use ExUnit.Case

  alias InPlace.Examples.Sudoku
  import CPSolver.Test.Helpers

  describe "4x4" do
    test "instance with two solutions" do
      Sudoku.solve(Sudoku.instance4(), solution_handler: async_solution_handler(), stop_on: false)

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

    test "'hard' and 'clue17'" do
      assert Enum.all?([hard(), clue17()], fn instance ->
        Sudoku.solve(instance, solution_handler: async_solution_handler())
        solutions = flush()
        length(solutions) == 1 &&
        Enum.all?(solutions, &Sudoku.check_solution/1)
      end)
    end

    defp hard() do
      "8..........36......7..9.2...5...7.......457.....1...3...1....68..85...1..9....4.."
    end

    def clue17() do
      "......8.16..2........7.5......6...2..1....3...8.......2......7..4..8....5...3...."
    end
  end

  defp async_solution_handler() do
    fn solution -> send(self(), solution) end
  end


end
