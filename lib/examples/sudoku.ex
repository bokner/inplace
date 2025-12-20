defmodule InPlace.Examples.Sudoku do
  @doc """
  The instance is a string of DxD length
  , where D is a dimension of Sudoku puzzle (would be 9 by default).
  The values 1 to 9 represent pre-filled cells.
  """
  @numbers ?1..?9

  @doc """
  Solver
  """
  def solve(instance) do
    instance
    |> init()
    #|> solve()
  end

  def init(instance) when is_binary(instance) do
   l = String.length(instance)
   d = :math.sqrt(l) |> floor()
   if d*d != l, do: throw(:invalid_instance)
   sqrt_d = :math.sqrt(d) |> floor()
   if sqrt_d * sqrt_d != d, do: throw(:invalid_instance)

   #rows = for <<chunk::size(d)-binary <- instance>>, do: chunk
   init_exact_cover(instance, d)
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
    open_cell_option = MapSet.new()

    {_position, options} =
    for <<cell <- instance>>, reduce: {0, []} do
      {cell_number, options_acc} ->
        {cell_number + 1,
        if hidden_cell?(cell) do
          Enum.map(0..d-1, fn value ->
            create_option(cell_number * d + value, d)
          end) ++ options_acc
        else
          [create_option(cell_number * d + cell_value(cell) - 1, d) | options_acc]
        end
      }
    end

    options


    ## Example: putting 4 in (3,5)
    ## Cell (3, 5) has a value in it
    ## Column 3 has a 4 in it.
    ## Row 5 has a 4 in it.
    ## Block (1,2) has a 4 in it.
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
    #int(
    # 3*(dim**2) +
    ## (row//(sqrt(dim)*dim**2))*(dim*sqrt(dim)) +
    ## ((row//(sqrt(dim)*dim)) % sqrt(dim))*dim + (row % dim)
    # )

    d_squared = d * d
    sqrt_d = floor(:math.sqrt(d))
    3 * d_squared +
    div(row, sqrt_d * d_squared) * d * sqrt_d +
    (div(row, sqrt_d * d) |> rem(sqrt_d)) * d + rem(row, d)

  end

  defp block(column, row, d) do
    sqrt_d = floor(:math.sqrt(d))
    ceil(column/sqrt_d) * sqrt_d + ceil(row/sqrt_d) - sqrt_d
  end


  def instance4() do
    "1000231000020200"
  end

  def instance9() do
    "4...39.2..56............6.4......9..5..1..2...9..27.3..37............8.69.8.1...."
  end

  @doc """
  Python ()
  # These functions return the column of the matrix to be populated for a constraint when given
# a specified row of the matrix and the dimension of the sudoku puzzle
def _one_constraint(row: int, dim:int) -> int:
    return row//dim
def _row_constraint(row:int, dim:int) -> int:
    return dim**2 + dim*(row//(dim**2)) + row % dim
def _col_constraint(row:int, dim:int) -> int:
    return 2*(dim**2) + (row % (dim**2))
def _box_constraint(row:int, dim:int) -> int:
    return int(3*(dim**2) + (row//(sqrt(dim)*dim**2))*(dim*sqrt(dim)) + ((row//(sqrt(dim)*dim)) % sqrt(dim))*dim + (row % dim))
constraint_list = [_one_constraint, _row_constraint, _col_constraint, _box_constraint]

# convert list of ints representing the puzzle to a dancing link matrix
def _list_2_matrix(puzzle: list[int], dim: int) -> dlm.DL_Matrix:
    num_rows = dim**3
    num_cols = (dim**2)*len(constraint_list)
    matrix: dlm.DL_Matrix = dlm.DL_Matrix(num_rows, num_cols)
    #iterate through puzzle
    for i, cell in enumerate(puzzle):
        if cell == 0: # if cell is unassigned
            # populate all rows representing cadidate values for this cell
            for j in range(dim):
                row = i*dim+j
                for constraint in constraint_list:
                    matrix.insert_node(row, constraint(row, dim))
        else: # if cell is assigned
            # populate the row representing the assigned value for this cell
            row = i*dim+cell-1
            for constraint in constraint_list:
                    matrix.insert_node(row, constraint(row, dim))
    return matrix

# takes list of ints representing a sudoku puzzle
# returns a list of ints representing the solution if one is found
def solve_puzzle(puzzle: list[int]) -> list[int]:
    dim = int(sqrt(len(puzzle)))
    assert(int(dim+0.5)**2 == len(puzzle)) # only perfect square puzzles are supported
    solution_list = _list_2_matrix(puzzle, dim).alg_x_search()
    if not solution_list: return []
    solved_puzzle = [0] * (dim**2)
    for row in solution_list:
        solved_puzzle[row // dim] = (row % dim) + 1
    return solved_puzzle

  """
end

[
~w{1 s1 s3}, ~w{1 s2 s4}, ~w{1 s3 s5}, ~w{1 s4 s6}, ~w{2 s1 s4}, ~w{2 s2 s5}, ~w{2 s3 s6}, ~w{3 s1 s5}, ~w{3 s2 s6}
]
