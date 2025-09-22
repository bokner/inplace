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
    opts = Keyword.merge(default_opts(), opts)
    Array.new(capacity + 1)
    |> then(fn ref ->
      Array.put(ref, capacity + 1 , 0)
      %{capacity: capacity, array: ref, opts: opts,
        comparator: Keyword.get(opts, :comparator)
      }
    end)

  end

  defp default_opts() do
    [comparator: &Kernel.<=/2]
  end

  def size(%{capacity: capacity, array: array} = _heap) do
    Array.get(array, size_address(capacity))
  end

  def empty?(heap) do
    size(heap) == 0
  end

  def inc_size(%{capacity: capacity, array: array} = _heap, delta \\ 1) do
    Array.update(array, size_address(capacity), fn size -> size + delta end)
  end

  def get_min(heap) do
    at(heap, 1)
  end

  def extract_min(%{array: array} = heap) do
    case size(heap) do
      0 -> nil
      current_size ->
        Array.swap(array, 1, current_size)
        inc_size(heap, -1)
        sift_down(heap, 1)
    end
  end

  def insert(%{capacity: capacity, array: array} = heap, key) when is_integer(key) do
    current_size = size(heap)
    if capacity == current_size, do: throw(:heap_over_capacity)
    new_size = current_size + 1
    Array.put(array, new_size, key)
    sift_up(heap, new_size)
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

  defp get_left_child(heap, parent_position) do
    at(heap, left_child_position(parent_position))
  end

  defp get_right_child(heap, parent_position) do
    at(heap, right_child_position(parent_position))
  end

  defp left_child_position(parent_position) do
    2 * parent_position
  end

  defp right_child_position(parent_position) do
    2 * parent_position + 1
  end

  defp get_parent(heap, child_position) when is_integer(child_position) do
    at(heap, parent_position(child_position))
  end

  defp parent_position(child_position) when is_integer(child_position) do
    div(child_position, 2)
  end

  defp sift_up(%{comparator: compare_fun, array: array} = heap, 1) do
    :ok
  end

  defp sift_up(%{comparator: compare_fun, array: array} = heap, position, key \\ nil) do
    parent = parent_position(position)
    p_key = at(heap, parent)
    c_key = key || at(heap, position)
    if compare_fun.(p_key, c_key) do
      :ok
    else
      Array.put(array, parent, c_key)
      Array.put(array, position, p_key)
      sift_up(heap, parent)
    end
  end

  defp sift_down(%{comparator: compare_fun, array: array} = heap, position, key \\ nil) do
    :TODO
  end

end
