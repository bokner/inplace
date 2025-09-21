defmodule InPlace.Heap do
  @moduledoc """
  Binary heap.
  NOTE:
  - The heap keys are limited to integers.
  - The capacity of the heap has to be specified at the time of creation.
  """
  alias InPlace.Array

  @doc """
  Initialize. All values are initially null.
  The element at capacity+1 is used to track the size.
  `opts` - TBD
  """
  def new(capacity, opts \\ []) do
    Array.new(capacity + 1)
    |> then(fn ref ->
      Array.put(ref, capacity + 1 , 0)
      %{capacity: capacity, array: ref, opts: Keyword.merge(default_opts(), opts)}
    end)

  end

  defp default_opts() do
    [comparator: &Kernel.<=/2]
  end

  def size(%{capacity: capacity, array: array} = _heap) do
    Array.get(array, size_address(capacity))
  end

  def inc_size(%{capacity: capacity, array: array} = _heap, delta \\ 1) do
    Array.update(array, size_address(capacity), fn size -> size + delta end)
  end

  def get_min(heap) do
    at(heap, 1)
  end

  def extract_min(heap) do

  end

  def insert(%{array: array} = heap, key) when is_integer(key) do
    if size(heap) == 0 do
      Array.put(array, 1, key)
    else
      
    end
    inc_size(heap, 1)
  end

  def decrease_key(heap, key, delta) when is_integer(key) and is_integer(delta) do

  end

  def size_address(capacity) do
    capacity + 1
  end

  defp at(%{array: array} = _heap, position) when is_integer(position) do
    Array.get(array, position)
  end

  defp get_children(heap, parent_position) do
    {at(heap, 2 * parent_position), at(heap, 2 * parent_position + 1)}
  end

  defp get_parent(heap, child_position) do
    at(heap, floor(child_position/2))
  end

end
