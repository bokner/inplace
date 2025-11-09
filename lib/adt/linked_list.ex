defmodule InPlace.LinkedList do
  @moduledoc """
    Single-linked list.
    The data entries are stored as integers.
    they will be interpreted (as references) by the calling application.
    Note: indices are 1-based.
    Options:
      - mapper_fun (optional, &Function.identity/1 by default): Maps data entries to application data
    """
  alias InPlace.{Array, Stack}

  ## List terminator
  @terminator 0

  def new(size, opts \\ []) when is_integer(size) and size > 0 do
    opts = Keyword.merge(default_opts(), opts)
    %{
      capacity: size,
      next: init_links(size),
      free: init_free(size),
      refs: :atomics.new(size, signed: true),
      mapper_fun: Keyword.get(opts, :mapper_fun)
    }
  end

  def get(%{mapper_fun: mapper} = list, idx) when is_integer(idx) and idx > 0 do
    case get_pointer(list, idx) do
      nil -> nil
      pointer -> mapper.(data(list, pointer))
    end
  end

  def get_pointer(list, idx) when is_integer(idx) and idx > 0 do
    get_pointer(list, head(list), 0, idx)
  end

  defp get_pointer(_list, @terminator, _step, _idx) do
    nil
  end

  defp get_pointer(_list, pointer, step, idx) when step == idx - 1 do
    pointer
  end

  defp get_pointer(list, pointer, step, idx) do
    get_pointer(list, next(list, pointer), step + 1, idx)
  end

  ## insert at the head
  def add_first(%{next: next, refs: refs} = list, data) when is_integer(data) do
    ## Store data in 'free' element of the list
    allocated = allocate(list)
    Array.put(refs, allocated, data)
    ## Have 'head' point to the new element
    old_head = get_and_update_head(list, fn _ -> allocated end)

    ## Update pointer to next element with current head
    Array.put(next, allocated, old_head)
  end

  def add(%{next: pointers, refs: refs} = list, idx, data)
      when is_integer(data) and is_integer(idx) do
    cond do
      idx == 0 ->
        add_first(list, data)

      idx > size(list) ->
        {:error, {:no_index, idx}}

      empty?(list) ->
        add_first(list, data)

      true ->
        idx_pointer = get_pointer(list, idx)
        allocated = allocate(list)
        Array.put(refs, allocated, data)
        Array.put(pointers, allocated, next(list, idx_pointer))
        Array.put(pointers, idx_pointer, allocated)
    end
  end

  def add_last(list, data) when is_integer(data) do
    add(list, size(list), data)
  end

  def delete(%{next: pointers} = list, idx) when is_integer(idx) and idx > 0 do
    cond do
      idx > size(list) ->
        {:error, {:no_index, idx}}
      idx == 1 -> # Removing head
        deallocate(list, idx)
        get_and_update_head(list, fn head -> next(list, head) end)
      true ->
        pointer = get_pointer(list, idx - 1)
        deallocate(list, idx)
        Array.put(pointers, pointer, next(list, next(list, pointer)))
    end
  end

  def to_list(list) do
    to_list(list, head(list), [])
  end

  defp to_list(_list, @terminator, acc) do
    Enum.reverse(acc)
  end

  defp to_list(%{mapper_fun: mapper} = list, pointer, acc) do
    to_list(list, next(list, pointer), [mapper.(data(list, pointer)) | acc])
  end

  def reduce(array, initial_value, reducer \\ fn el, acc -> [el | acc] end)
      when is_function(reducer) do
    Enum.reduce(1..size(array), initial_value, fn idx, acc ->
      reducer.(:atomics.get(array, idx), acc)
    end)
  end

  def empty?(list) do
    head(list) == @terminator
  end

  def size(%{capacity: capacity, free: free} = _list) do
    capacity - Stack.size(free)
  end

  def default_opts() do
    [
      mapper_fun: &Function.identity/1
    ]
  end

  ## Implementation
  ##
  ## Allocate links; the last element will hold the 'head' pointer
  defp init_links(size) do
    ref = :atomics.new(size + 1, signed: false)
    Array.put(ref, size + 1, @terminator)
    ref
  end

  ## The stack for tracking 'free' indices
  ## They can be reused after the element is removed from linked list
  ##
  defp init_free(size) when is_integer(size) do
    ref = Stack.new(size)
    Enum.each(1..size, fn idx -> Stack.push(ref, idx) end)
    ref
  end

  defp head(%{capacity: capacity, next: next} = _list) do
    Array.get(next, capacity + 1)
  end

  defp get_and_update_head(%{capacity: capacity, next: next} = list, update_fun) do
    current_head = head(list)
    Array.put(next, capacity + 1, update_fun.(current_head))
    current_head
  end

  defp data(%{refs: refs} = _list, pointer) do
    Array.get(refs, pointer)
  end

  defp next(%{next: pointers} = _list, pointer) do
    Array.get(pointers, pointer)
  end

  defp allocate(%{free: free} = _list) do
    Stack.pop(free) || throw(:list_over_capacity)
  end

  defp deallocate(%{free: free} = _list, idx) when is_integer(idx) and idx > 0 do
    Stack.push(free, idx)
  end
end
