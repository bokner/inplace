defmodule BitGraph.Queue do
  alias BitGraph.Array

  ## Circular queue
  ## The internal structure:
  ## `size` is located at `arr[capacity + 1]` and has the current queue size;
  ## `front_pointer` is located at `arr[capacity + 2]` and has a 0-based pointer to the current `front` element
  ## , that is: arr[arr[capacity + 2] + 1] = front
  ##
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    ref = Array.new(capacity + 2)
    {capacity, ref}
  end

  def size({capacity, ref} = _queue) do
    Array.get(ref, size_address(capacity))
  end

  defp size_address(capacity) do
    capacity + 1
  end

  def empty?(queue) do
    size(queue) == 0
  end

  def front({_capacity, ref} = queue) do
    if !empty?(queue) do
      get0(ref, front_pointer(queue))
    end
  end

  def front_pointer({capacity, ref} = _queue) do
    Array.get(ref, front_address(capacity))
  end

  defp front_address(capacity) do
    capacity + 2
  end

  def rear({_capacity, ref} = queue) do
    if !empty?(queue) do
      pointer = rear_pointer(queue)
      get0(ref, pointer)
    end
  end

  def rear_pointer({capacity, _ref} = queue) do
    rem(front_pointer(queue) + size(queue) - 1, capacity)
  end

  def enqueue({capacity, ref} = queue, element) do
    current_size = size(queue)
    if current_size == capacity, do: throw(:queue_over_capacity)
    put0(ref, rem(front_pointer(queue) + current_size, capacity), element)
    Array.put(ref, size_address(capacity), current_size + 1)
  end

  def dequeue({capacity, ref} = queue) do
      case size(queue) do
        0 -> nil
        current_size ->
          pointer = front_pointer(queue)
          Array.put(ref, size_address(capacity), current_size - 1)
          Array.put(ref, front_address(capacity), rem(pointer + 1, capacity))
          get0(ref, pointer)
        end
  end

  def from_list(list) do
    new(length(list))
    |> tap(fn queue -> Enum.each(list, fn el -> enqueue(queue, el) end) end)
  end

  defp get0(arr, idx) do
    Array.get(arr, idx + 1)
  end

  defp put0(arr, idx, value) do
    Array.put(arr, idx + 1, value)
  end
end
