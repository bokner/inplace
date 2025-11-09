defmodule InPlace.LinkedList do
  @moduledoc """
  [Singly linked list](https://en.wikipedia.org/wiki/Linked_list#Singly_linked_list)
  The data entries are stored as integers.
  they will be interpreted (as references) by the calling application.
  Note: indices are 1-based.
  Options:
    - :mapper_fun (optional, &Function.identity/1 by default) - maps data entries to application data
  """
  alias InPlace.{Array, Stack}

  ## List terminator
  @terminator 0

  def new(size, opts \\ []) when is_integer(size) and size > 0 do
    opts = Keyword.merge(default_opts(), opts)

    %{
      capacity: size,
      ## holds the pointer to the first element of the list
      handle: Array.new(1, @terminator),
      # pointers (links) to the next element
      next: init_links(size),
      # keeps unused pointers
      free: init_free(size),
      # references to the data
      refs: :atomics.new(size, signed: true),
      # mapper `reference -> data`
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

  def add_first(%{next: next, refs: refs} = list, data) when is_integer(data) do
    ## Store data in 'free' element of the list
    allocated = allocate(list)
    Array.put(refs, allocated, data)
    ## Have 'handle' point to the new element
    _old_handle = get_and_update_handle(list, fn handle ->
      Array.put(next, allocated, handle)
      allocated
    end)

    ## Return the pointer for allocated element
    {:ok, allocated}
  end

  def insert(%{next: pointers, refs: refs} = list, idx, data)
      when is_integer(data) and is_integer(idx) and idx > 0 do
    cond do
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
    if empty?(list) do
      add_first(list, data)
    else
      insert(list, size(list), data)
    end
  end

  def delete(%{next: pointers} = list, idx) when is_integer(idx) and idx > 0 do
    cond do
      idx > size(list) ->
        {:error, {:no_index, idx}}

      # Removing first element of the list
      idx == 1 ->
        deallocate(list, idx)
        get_and_update_handle(list, fn handle -> next(list, handle) end)

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
  ## Allocate links (pointers to the next element)
  defp init_links(size) do
    :atomics.new(size, signed: false)
  end

  ## The stack for tracking 'free' indices
  ## They can be reused after the element is removed from linked list
  ##
  defp init_free(size) when is_integer(size) do
    ref = Stack.new(size)
    Enum.each(1..size, fn idx -> Stack.push(ref, idx) end)
    ref
  end

  defp head(%{handle: handle} = _list) do
    Array.get(handle, 1)
  end

  defp get_and_update_handle(%{handle: handle} = list, update_fun) do
    current_head = head(list)
    Array.put(handle, 1, update_fun.(current_head))
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
