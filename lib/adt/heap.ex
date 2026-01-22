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
  The element at capacity+1 is used to track the heap size.
  Options:
  - `comparator` - function of arity 2, returns true if 1st argument strictly 'lesser' than 2nd.
  `lesser` is understood as the ordering function. Arguments could be of any type.
   Default: &Kernel.</2
  - `getter` - function of arity 1; takes an integer (key) as argument and returns value of type integer()
   Default:
  """
  def new(capacity, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    ref = Array.new(capacity + 1, 0)

      %{
        capacity: capacity,
        array: ref,
        index_positions: Array.new(capacity, 0),
        position_indices: Array.new(capacity, Array.null()),
        comparator: Keyword.get(opts, :comparator),
        getter: Keyword.get(opts, :getter)
      }
  end

  def default_opts() do
    [
      comparator: &Kernel.<=/2,
      getter: fn key -> key end
    ]
  end

  def size(%{capacity: capacity, array: array} = _heap) do
    Array.get(array, size_address(capacity))
  end

  def empty?(heap) do
    size(heap) == 0
  end

  def valid?(%{comparator: compare_fun} = heap) do
    case size(heap) do
      0 ->
        true

      heap_size ->
        Enum.reduce_while(1..parent_position(heap_size), true, fn idx, _acc ->
          p_key = get_key(heap, idx)
          l_key = get_left_child_key(heap, idx)

          if compare_fun.(p_key, l_key) do
            ## heap property for left child is satisfied
            r_key = get_right_child_key(heap, idx)

            if !r_key do
              ## end of the tree
              {:halt, true}
            else
              if compare_fun.(p_key, r_key) do
                ## heap property for right child satisfied
                {:cont, true}
              else
                ## Right child violates heap property
                {:halt, false}
              end
            end
          else
            ## Left child violates heap property
            {:halt, false}
          end
        end)
    end
  end

  def get_min(%{getter: getter_fun} = heap) do
    getter_fun.(get_key(heap, 1))
  end

  def get_max(%{getter: getter_fun} = heap) do
    getter_fun.(get_key(heap, size(heap)))
  end

  def extract_min(%{array: array} = heap) do
    current_min = get_min(heap)

    case size(heap) do
      0 ->
        :ok

      current_size ->
        Array.swap(array, 1, current_size)
        inc_size(heap, -1)
        sift_down(heap, 1)
    end

    current_min
  end

  def insert(
        %{
          capacity: capacity,
          index_positions: index_positions,
          position_indices: position_indices,
          array: array
        } = heap,
        key
      )
      when is_integer(key) do
    current_size = size(heap)
    if capacity == current_size, do: throw(:heap_over_capacity)
    new_size = current_size + 1
    Array.put(array, new_size, key)
    Array.put(index_positions, new_size, new_size)
    Array.put(position_indices, new_size, new_size)
    inc_size(heap)
    sift_up(heap, new_size)
  end

  def decrease_key(%{array: array} = heap, key, delta)
      when is_integer(key) and is_integer(delta) and delta >= 0 do
    position = get_key_position(heap, key)
    Array.update(array, position, fn key -> key - delta end)
    sift_up(heap, position)
  end

  ## enforce heap property on the array
  def heapify(heap) do
    heapify(heap, size(heap))
  end

  def heapify(heap, position) do
    starting_position = parent_position(position)

    Enum.each(starting_position..1//-1, fn pos ->
      sift_down(heap, pos)
    end)
  end

  defp size_address(capacity) do
    capacity + 1
  end

  defp inc_size(%{capacity: capacity, array: array} = _heap, delta \\ 1) do
    Array.update(array, size_address(capacity), fn size -> size + delta end)
  end

  def get_key(heap, position, heap_size \\ nil)
  ## Get the external key (pointer to external data) given the position in the heap.
  def get_key(%{array: array} = heap, position, heap_size) when is_integer(position) do
    size = heap_size || size(heap)

    if position <= size,
      do:
        Array.get(
          array,
          position
        )
  end

  def get_key(heap, {:key_index, index}, heap_size) when is_integer(index) do
    get_key(heap, get_key_position(heap, index), heap_size)
  end

  def get_key_position(%{index_positions: positions} = _heap, index) do
    Array.get(positions, index)
  end

  defp get_left_child_key(heap, parent_position) do
    get_key(heap, left_child_position(parent_position))
  end

  defp get_right_child_key(heap, parent_position) do
    get_key(heap, right_child_position(parent_position))
  end

  defp left_child_position(parent_position) do
    2 * parent_position
  end

  defp right_child_position(parent_position) do
    2 * parent_position + 1
  end

  defp parent_position(child_position) when is_integer(child_position) do
    div(child_position, 2)
  end

  defp valid_position?(heap, position, heap_size) do
    size = heap_size || size(heap)
    position <= size
  end

  def sift_up(heap, position, key \\ nil)

  def sift_up(_heap, 1, _) do
    1
  end

  def sift_up(%{comparator: compare_fun} = heap, position, key) do
    parent = parent_position(position)
    p_key = get_key(heap, parent)
    c_key = key || get_key(heap, position)

    if compare_fun.(p_key, c_key) do
      position
    else
      swap_elements(heap, {parent, p_key}, {position, c_key})
      sift_up(heap, parent, c_key)
    end
  end

  defp swap_elements(
         %{array: array, index_positions: index_positions, position_indices: position_indices} =
           _heap,
         {position1, key1},
         {position2, key2}
       )
       when is_integer(position1) and is_integer(position2) and is_integer(key1) and
              is_integer(key2) do
    Array.put(array, position1, key2)
    Array.put(array, position2, key1)

    ## Update position -> key index and
    ## key index -> position maps
    case Array.get(position_indices, position1) do
      nil ->
        :ok

      key_index1 ->
        case Array.get(position_indices, position2) do
          nil ->
            :ok

          key_index2 ->
            Array.put(position_indices, position2, key_index1)
            Array.put(position_indices, position1, key_index2)

            Array.put(index_positions, key_index1, position2)
            Array.put(index_positions, key_index2, position1)
        end
    end
  end

  def sift_down(heap, position) do
    sift_down(heap, position, get_key(heap, position), size(heap))
  end

  defp sift_down(%{comparator: compare_fun} = heap, position, key, size) do
    cond do
      position > div(size, 2) ->
        position

      true ->
        left_p = left_child_position(position)
        right_p = right_child_position(position)
        parent_key = key || get_key(heap, position)

        left_key = get_key(heap, left_p)
        right_key = valid_position?(heap, right_p, size) && get_key(heap, right_p)

        swap_with =
          if compare_fun.(parent_key, left_key) do
            ## Rule out right child
            if right_key && !compare_fun.(parent_key, right_key) do
              ## Right child to swap
              {right_p, right_key}
            end
          else
            ## Could be either child
            ## We know left child is `leq` than parent
            if right_key && compare_fun.(right_key, left_key) do
              ## Right child `leq` than left child
              {right_p, right_key}
            else
              {left_p, left_key}
            end
          end

        ## maybe swap
        if swap_with do
          ## We don't use Array.swap/3 to save on retrieving values which are already known
          swap_elements(heap, {position, parent_key}, swap_with)
          sift_down(heap, elem(swap_with, 0), parent_key, size)
        else
          :ok
        end
    end
  end
end
