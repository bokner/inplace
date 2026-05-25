defmodule InPlace.Examples.KnightTour do
  alias InPlace.{Stack, BitSet, LinkedList}

  def solve(dimension) when is_integer(dimension) do
    dimension
    |> init_state()
    |> solve_impl()
  end

  defp solve_impl(state) do
    case Stack.pop(state.moves) do
      nil ->
        :no_solution
    last_move ->
      add_to_visited(state.visited, last_move)
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
    visited = BitSet.new(0, num_fields - 1)
    path = LinkedList.new(num_fields)
    %{moves: moves_stack,
      visited: visited,
      path: path,
      neighbours: build_neighbours(dimension),
      dimension: dimension
    }
    |> tap(fn initial_state ->
      initial_position = 0 #Enum.random(0..num_fields-1)

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


  defp add_to_visited(visited, value) do
    IO.inspect(value, label: :add_to_visited)
    BitSet.put(visited, value)
  end

  defp remove_from_visited(visited, value) do
    IO.inspect(value, label: :remove_from_visited)
    BitSet.delete(visited, value)
  end


  defp visited?(visited, value) do
    BitSet.member?(visited, value)
  end

  defp pop_move(%{moves: moves_stack, path: _path, visited: visited} = state) do
    case Stack.pop(moves_stack) do
      nil -> nil
      move ->
        if visited?(visited, move) do
          remove_from_visited(visited, move)
          pop_move(state)
        else
          add_to_visited(visited, move)
          move
        end
    end
  end

  defp schedule_move(move,  %{moves: moves_stack} = _state) do
    Stack.push(moves_stack, move)
  end

  defp solved?(last_move, %{dimension: dim, visited: visited} = _state) do
    IO.inspect(%{last_move: last_move, visited: BitSet.size(visited)}, label: :move)
    BitSet.size(visited) == dim * dim - 1
  end

  defp to_solution(last_move, _state) do
    last_move
  end

  defp process_choices(last_move, %{moves: moves, visited: visited, neighbours: neighbours} = state) do
    next_move_positions = Map.get(neighbours, last_move)
    ## Push the neighboring positions that have not been already scheduled to stack
    ## If there is no choice, remove last move from scheduled
    has_neighbours? = Enum.reduce(next_move_positions, false, fn pos, has_neighbours_acc? ->
      cond do
        visited?(visited, pos) ->
          has_neighbours_acc? || false

        true ->
          schedule_move(pos, state)
          true
        # true ->
        #   true
        end
    end)

    if has_neighbours? do
      #add_to_visited(visited, last_move)
    else
      IO.inspect(%{move: last_move, visited: BitSet.to_list(visited), stack: Stack.to_list(moves)}, label: :backtrack)
      remove_from_visited(visited, last_move)
      case pop_move(state) do
        nil -> nil
        move ->
          process_choices(move, state)
        end
    end
  end


end
