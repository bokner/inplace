ExUnit.start()

defmodule CPSolver.Test.Helpers do
  def flush() do
    flush([])
  end

  defp flush(acc) do
    receive do
      msg -> flush([msg | acc])
    after
      0 -> acc
    end
  end
end
