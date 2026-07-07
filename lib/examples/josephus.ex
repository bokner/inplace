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
    circle = LinkedList.new(num_soldiers, deletion: :rewind)
    Enum.each(1..num_soldiers, fn n -> LinkedList.append(circle, n) end)

      LinkedList.iterate(
        circle,
        fn p, count_acc ->
          if rem(count_acc, every_k) == 0 do
            LinkedList.delete_pointer(circle, p)
          end

          count_acc + 1
        end,
        initial_value: 1,
        stop_on: fn _ -> LinkedList.size(circle) == 1 end
      )

    ## the survivor and kill sequence
    survivor = LinkedList.data(circle, LinkedList.head(circle))
    %{
      kill_sequence: Enum.reduce(1..num_soldiers - 1, [],
        fn _, acc ->
          {:restored, killed} = LinkedList.rewind(circle)
          [killed | acc]
        end),
      survivor: survivor
    }
  end
end
