defmodule InPlace.Examples.Josephus do
  @moduledoc """
  https://en.wikipedia.org/wiki/Josephus_problem
  """
  alias InPlace.LinkedList

  @doc """
    Form the circle from N soldiers.
    Going clockwise, eliminate every k-th soldier
    until only one soldier is left.
  """
  def solve(num_soldiers, every_k) do
    circle = LinkedList.new(num_soldiers)
    Enum.each(1..num_soldiers, fn n -> LinkedList.append(circle, n) end)

    {_move_count, kill_sequence} =
      LinkedList.iterate(
        circle,
        fn p, {count_acc, sequence_acc} ->
          sequence_acc = if rem(count_acc, every_k) == 0 do
            LinkedList.delete_pointer(circle, p)
            [p | sequence_acc]
          else
            sequence_acc
          end

          {count_acc + 1, sequence_acc}
        end,
        initial_value: {1, []},
        stop_on: fn _ -> LinkedList.empty?(circle) end
      )

      kill_sequence
  end
end
