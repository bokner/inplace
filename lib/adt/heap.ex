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
    inc_size(heap, 1)
    sift_up(heap, new_size)
  end

  def decrease_key(heap, key, delta) when is_integer(key) and is_integer(delta) do

  end

  def size_address(capacity) do
    capacity + 1
  end

  def at(%{array: array} = heap, position, heap_size \\ nil) when is_integer(position) do
    size = heap_size || size(heap)
    if position <= size, do: Array.get(array, position)
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

  defp valid_position?(heap, position, heap_size \\ nil) do
    size = heap_size || size(heap)
    size >= position
  end

  def sift_up(heap, position, key \\ nil)
  def sift_up(_heap, 1, _) do
    :ok
  end

  def sift_up(%{comparator: compare_fun} = heap, position, key) do
    parent = parent_position(position)
    p_key = at(heap, parent)
    c_key = key || at(heap, position)
    if compare_fun.(p_key, c_key) do
      :ok
    else
      swap_elements(heap, {parent, p_key}, {position, c_key})
      sift_up(heap, parent, c_key)
    end
  end

  defp swap_elements(%{array: array} = _heap, {position1, key1}, {position2, key2}) do
    Array.put(array, position1, key2)
    Array.put(array, position2, key1)
  end

  defp sift_down(heap, position, key \\ nil) do
    sift_down(heap, position, key, size(heap))
  end

  defp sift_down(_heap, position, _key, size) when position == size do
    :ok
  end

  defp sift_down(%{comparator: compare_fun} = heap, position, key, size) do
    left_p = left_child_position(position)
    right_p = right_child_position(position)
    if left_p do
      parent_key = key || at(heap, position)
      ## Swap with smallest of child keys, if it's bigger than parent key
      left_key = at(heap, left_p)
      right_key = at(heap, right_p)
      if compare_fun.(left_key, right_key) do
          ## maybe swap left key and parent key
          if compare_fun.(left_key, parent_key) do
            swap_elements(heap, {position, parent_key}, {left_p, left_key})
            sift_down(heap, left_p, parent_key)
          end
        else
          ## maybe swap right key and parent key
          if compare_fun.(right_key, parent_key) do
            swap_elements(heap, {position, parent_key}, {right_p, right_key})
            sift_down(heap, right_p, parent_key)
          end
      end
    else
      ## Left child is absent -  this is not a complete tree
      throw(:not_complete_tree)
    end

  end

end
