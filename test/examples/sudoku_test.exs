defmodule InPlace.Examples.SudokuTest do
  use ExUnit.Case

  alias InPlace.Examples.Sudoku
  import CPSolver.Test.Helpers

  describe "4x4" do
    test "instance with two solutions" do
      Sudoku.solve(instance4(), solution_handler: async_solution_handler(), stop_on: false)

      solutions = flush()
      assert length(solutions) == 2
      assert Enum.all?(solutions, &Sudoku.check_solution/1)
    end
  end

  describe "9x9" do
    test "Knuth's example" do
      Sudoku.solve(instance29a_knuth(), solution_handler: async_solution_handler())
      solutions = flush()
      assert length(solutions) == 1
      assert Enum.all?(solutions, &Sudoku.check_solution/1)
    end

    test "easy" do
      Sudoku.solve(instance9(), solution_handler: async_solution_handler())
      solutions = flush()
      assert length(solutions) == 1
      assert Enum.all?(solutions, &Sudoku.check_solution/1)
    end

    test "'hard' and 'clue17'" do
      assert Enum.each([hard(), clue17()], fn instance ->
               Sudoku.solve(instance, solution_handler: async_solution_handler())
               solutions = flush()

               assert length(solutions) == 1 &&
                 Sudoku.check_solution(hd(solutions))
             end)
    end

    defp hard() do
      "8..........36......7..9.2...5...7.......457.....1...3...1....68..85...1..9....4.."
    end

    def clue17() do
      "......8.16..2........7.5......6...2..1....3...8.......2......7..4..8....5...3...."
    end

    def instance4() do
      "1000231000020200"
    end

    def instance9() do
      "4...39.2..56............6.4......9..5..1..2...9..27.3..37............8.69.8.1...."
    end

    def instance29a_knuth() do
      "..3.1....415....9.2.65..3..5...8...9.7.9...32.38..4.6....26.4.3...3....832...795."
    end

  end

  defp async_solution_handler() do
    fn solution -> send(self(), solution) end
  end
end
