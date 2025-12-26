defmodule InPlace.Examples.Sudoku do
  @moduledoc """
  Sudoku puzzle.
  The instance of puzzle is a string of DxD length
  , where D is a dimension of Sudoku puzzle (would be 9 by default).
  The values 1 to 9 represent pre-filled cells (clues, givens etc...);
  any other values represent hidden cells.
  """
  alias InPlace.ExactCover
  require Logger
  @numbers ?1..?9

  @doc """
  Solver
  """
  def solve(instance, opts \\ []) do
    ## Build the options for the exact cover, and some supplemental data
    %{options: options, dimension: d, instance: instance_array} = init(instance)
    opts = Keyword.merge(default_opts(), opts)
    ## Plug in solution handler
    top_solution_handler = Keyword.get(opts, :solution_handler)
    checker = Keyword.get(opts, :checker)
    opts = Keyword.put(opts, :solution_handler, fn solution ->
      solution
      |> solution_to_sudoku(instance_array, options, d)
      |> tap(fn solution -> checker && check_solution(solution) end)
      |> top_solution_handler.()
    end)
    ## Solve with exact cover
    ExactCover.solve(options, opts)
  end

  defp default_opts() do
    [
      solution_handler: fn solution -> Logger.info(inspect(solution)) end,
      checker: fn correct? -> !correct? && Logger.error("invalid solution") end
    ]
  end

  def init(instance) when is_binary(instance) do
   l = String.length(instance)
   d = :math.sqrt(l) |> floor()
   if d*d != l, do: throw(:invalid_instance)
   sqrt_d = :math.sqrt(d) |> floor()
   if sqrt_d * sqrt_d != d, do: throw(:invalid_instance)

    %{
      options: init_exact_cover(instance, d), dimension: d,
      instance: instance_to_array(instance)
    }
  end

  def init_exact_cover(instance, d) when is_binary(instance) do
    ## Turn the instance to a list of options
    ## columns (items in "exact-cover" terms):
    ## - one for each cell (d^2);
    ## - d^2 for columns: each of the d columns must have each possible value 1-d.
    ## - d^2 for rows: each of the d rows must have each possible value 1-d.
    ## - d^2 for blocks: Each of the d sqrt(d)×sqrt(d) blocks must have each possible value 1-d.
    ##??  - initial state: Since there is an initial state for the board, one option will describe the initial state and this item ensures that it is always part of any solution found.

    ## Rows (options in "exact-cover" terms)
    ## There will be (d*d - num_open_cells) * d rows (options)
    ## for hidden cells, plus one that matches open cells
    ##

    {_position, options, covered_set} =
    for <<cell <- instance>>, reduce: {0, [], MapSet.new()} do
      {cell_number, options_acc, covered_acc} ->

        if hidden_cell?(cell) do
          {cell_number + 1,
          Enum.map(0..d-1, fn value ->
            create_option(cell_number * d + value, d)
          end) ++ options_acc, covered_acc}
        else
          {cell_number + 1,
            options_acc,
            MapSet.union(covered_acc,
              MapSet.new(create_option(cell_number * d + cell_value(cell) - 1, d))
            )
          }
        end
    end

    Enum.filter(options, fn opt -> MapSet.disjoint?(MapSet.new(opt), covered_set) end)
  end

  defp hidden_cell?(ascii_code) do
    ascii_code not in @numbers
  end

  defp create_option(row, d) do
    [
      cell_item(row, d),
      row_item(row, d),
      column_item(row, d),
      block_item(row, d)
    ]
  end

  defp cell_value(ascii_code) do
    ascii_code - 48
  end

  def cell_item(row, d) do
    div(row, d)
  end

  def row_item(row, d) do
    d_squared = d * d
    d_squared + d * div(row, d_squared) + rem(row, d)
  end

  def column_item(row, d) do
    d_squared = d * d
    2 * d_squared + rem(row, d_squared)
  end

  def block_item(row, d) do
    d_squared = d * d
    sqrt_d = floor(:math.sqrt(d))
    3 * d_squared +
    div(row, sqrt_d * d_squared) * d * sqrt_d +
    (div(row, sqrt_d * d) |> rem(sqrt_d)) * d + rem(row, d)
  end

  defp instance_to_array(instance) when is_binary(instance) do
    for <<cell <- instance>> do
      hidden_cell?(cell) && 0 || cell_value(cell)
    end
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

  @doc """
    `solution` is a "cover" (list of indices into options
    built off the Sudoku instance).
    Note: the options only represent "hidden" cells.
  """
  def solution_to_sudoku(solution, instance, options, d) do
    grid_size = d * d
    solution
    |> Enum.map(fn opt_idx ->
      [_, r, c, _] = Enum.at(options, opt_idx)
       {val, row, col} =
        {
          rem(r - grid_size, d) + 1,
          div(r - grid_size, d), div(c - 2 * grid_size, d)}
      {row * d + col, val}
        end)
    |> then(fn solved_values ->
      Enum.reduce(solved_values, instance, fn {pos, value}, acc ->
        List.replace_at(acc, pos, value)
      end)
    end)
  end

  @spec check_solution([integer()]) :: boolean()
  @doc """
    `solution` is a list of integers
    representing the 'flattened' solved puzzle
  """
  def check_solution(solution) when is_list(solution) do
    dim = :math.sqrt(length(solution)) |> floor()
    grid = Enum.chunk_every(solution, dim)
    transposed = Enum.zip_with(grid, &Function.identity/1)
    squares = group_by_subsquares(grid)

    checker_fun = fn line -> Enum.sort(line) == Enum.to_list(1..dim) end

    Enum.all?([grid, transposed, squares], fn arrangement ->
      Enum.all?(arrangement, checker_fun)
    end)
  end

  defp group_by_subsquares(cells) do
    square = :math.sqrt(length(cells)) |> floor

    for i <- 0..(square - 1), j <- 0..(square - 1) do
      for k <- (i * square)..(i * square + square - 1),
          l <- (j * square)..(j * square + square - 1) do
        Enum.at(cells, k) |> Enum.at(l)
      end
    end
  end

end
