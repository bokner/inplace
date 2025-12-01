defmodule InPlace.Examples.Josephus do
  @moduledoc """
  https://en.wikipedia.org/wiki/Josephus_problem
  """
  alias InPlace.LinkedList

  @doc """
    Form the circle from N soldiers.
    Going clockwise, eliminate every k-th soldier
    until the only one soldier is left.
  """
  def solve(num_soldiers, every_k) do
    circle = LinkedList.new(num_soldiers, circular: true, mode: :doubly_linked, undo: true)
    Enum.each(1..num_soldiers, fn n -> LinkedList.add_last(circle, n) end)

    _number_of_moves = LinkedList.iterate(circle,
      initial_value: 1,
      stop_on: fn _ -> LinkedList.size(circle) == 1 end,
      action: fn p, acc ->
        if rem(acc, every_k) == 0 do
          LinkedList.delete_pointer(circle, p)
        end
        acc + 1
      end
    )
    ## the survivor
    LinkedList.data(circle, LinkedList.head(circle))
  end
end
