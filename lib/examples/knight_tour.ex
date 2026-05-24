defmodule InPlace.Examples.KnightTour do
  alias InPlace.{Stack, BitSet, SparseSet}

  def solve(dimension) when is_integer(dimension) do
    initial_state = %{moves: _move_stack} = init_state(dimension)
    solve_impl(initial_state)
  end

  defp solve_impl(%{moves: move_stack, scheduled: scheduled} = state) do
    if Stack.empty?(move_stack) do
      :no_solution
    else
      last_move = move(move_stack)

      if solved?(last_move, state) do
        {:solved, to_solution(last_move, state)}
      else
          process_choices(last_move, state)
          solve_impl(state)
      end
    end
  end

  defp init_state(dimension) do
    num_fields = dimension * dimension
    moves_stack = Stack.new(num_fields * num_fields)
    scheduled = BitSet.new(0, num_fields - 1)
    path = SparseSet.new(num_fields)
    %{moves: moves_stack,
      scheduled: scheduled,
      neighbours: build_neighbours(dimension),
      dimension: dimension
    }
    |> tap(fn initial_state ->
      initial_position = 0 #Enum.random(0..num_fields-1)
      add_to_path(path, initial_position)
      schedule_move(initial_position, initial_state)
    end)
  end

  ## Precompute neighbours (possible moves for every position)
  def build_neighbours(dimension) do
    move_offsets = [
          {-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
          {2, -1}, {2, 1}, {1, -2}, {1, 2}
        ]
    Enum.reduce(1..dimension * dimension, Map.new(), fn pos, acc ->
      Enum.reduce(move_offsets, acc,
        fn {row_offset, column_offset}, acc2 ->
          {pos_row, pos_col} =
            case rem(pos, dimension) do
              0 -> {div(pos, dimension), dimension}
              r -> {div(pos, dimension) + 1, r}
            end
          move_row = pos_row + row_offset
          move_column = pos_col + column_offset
          if move_row < 1 || move_row > dimension || move_column < 1 || move_column > dimension do
            acc2
          else
            move_pos = (move_row - 1) * dimension + move_column - 1
            Map.update(acc2, pos - 1, MapSet.new([move_pos]),
            fn moves -> MapSet.put(moves, move_pos) end)
          end
      end)
    end)
  end

  defp add_to_scheduled(scheduled, value) do
    BitSet.put(scheduled, value)
  end

  defp add_to_path(path, value) do
    SparseSet.delete(path, value)
  end

  defp backtrack(path, value) do
    undeleted = SparseSet.undelete(path)
  end

  defp move(moves_stack) do
    Stack.pop(moves_stack)
  end

  defp schedule_move(move,  %{scheduled: scheduled, moves: moves_stack} = _state) do
    add_to_scheduled(scheduled, move)
    Stack.push(moves_stack, move)
  end

  defp solved?(last_move, %{scheduled: scheduled, dimension: dim} = _state) do
    IO.inspect(last_move, label: :move)
    (BitSet.size(scheduled) == dim * dim - 1) &&
    !BitSet.member?(scheduled, last_move)
  end

  defp to_solution(last_move, _state) do
    last_move
  end

  defp process_choices(last_move, %{moves: moves, path: path, scheduled: scheduled, neighbours: neighbours} = state) do
    next_move_positions = Map.get(neighbours, last_move)
    ## Push the neighboring positions that have not been already scheduled to stack
    ## If there is no choice, remove last move from scheduled
    has_neighbours? = Enum.reduce(next_move_positions, false, fn pos, has_neighbours_acc? ->
      if !scheduled?(scheduled, pos) do
        schedule_move(pos, state)
        true
      else
        has_neighbours_acc?
      end
    end)

    if has_neighbours? do
      add_to_path(path, last_move)
    else
      IO.inspect(Stack.to_list(moves), label: :backtrack)
    end
  end

  defp scheduled?(scheduled, position) do
    BitSet.member?(scheduled, position)
  end
end
