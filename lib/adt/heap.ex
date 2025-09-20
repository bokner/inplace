defmodule InPlace.Heap do
  @moduledoc """
  Binary heap.
  NOTE:
  - The heap keys are limited to integers.
  - The capacity of the heap has to be specified at the time of creation.
  """
  alias InPlace.Array
  import Bitwise

  @null (1 <<< 64) - 1

  @doc """
  Initialize. All values are initially null.
  The element at capacity+1 is used to track the size.
  `opts` - TBD
  """
  def new(capacity, opts \\ []) do
    Array.new(capacity + 1)
    |> then(fn ref ->
      Enum.each(1..capacity, fn idx -> Array.put(ref, idx, @null) end)
      %{capacity: capacity, array: ref, opts: Keyword.merge(default_opts(), opts)}
    end)
  end

  defp default_opts() do
    [comparator: &Kernel.</2]
  end

  def get_min(heap) do
    at(heap, 1)
  end

  def extract_min(heap) do

  end

  def insert(heap, key) when is_integer(key) do

  end

  def decrease_key(heap, key, delta) when is_integer(key) and is_integer(delta) do

  end

  defp at(%{array: array} = _heap, position) when is_integer(position) do
    case Array.get(array, position) do
      @null -> nil
      val -> val
    end
  end

  defp get_children(heap, parent_position) do
    {at(heap, 2 * parent_position), at(heap, 2 * parent_position + 1)}
  end

  defp get_parent(heap, child_position) do
    at(heap, floor(child_position/2))
  end

end
