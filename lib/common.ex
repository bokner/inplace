defmodule InPlace.Common do
  import Bitwise

  @doc """
    Represents null (empty) value
    to be used by ADT implementations
  """
  def null() do
    (1 <<< 64) - 1
  end
end
