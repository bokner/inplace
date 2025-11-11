defmodule InPlace.LinkedList do
  @moduledoc """
  [Singly linked list](https://en.wikipedia.org/wiki/Linked_list#Singly_linked_list)
  The data entries are stored as integers.
  they will be interpreted (as references) by the calling application.
  Note: indices are 1-based.
  Options:
    - `mode` :: :singly_linked | :doubly_linked
    - :mapper_fun (optional, &Function.identity/1 by default) - maps data entries to application data
  """
  alias InPlace.{Array, Stack}

  ## List terminator
  @terminator 0
  @singly_linked_mode :singly_linked
  @doubly_linked_mode :doubly_linked

  def new(size, opts \\ []) when is_integer(size) and size > 0 do
    opts = Keyword.merge(default_opts(), opts)
    mode = Keyword.get(opts, :mode)
    if mode not in [@singly_linked_mode, @doubly_linked_mode] do
      throw({:error, {:unknown_mode, mode}})
    end

    %{
      capacity: size,
      ## mode (:singly_linked or :doubly_linked)
      mode: Keyword.get(opts, :mode),
      ## holds the pointer to the first element of the list
      handle: init_handle(mode),
      # pointers (links) to the next element
      next: init_links(size),
      # keeps unused pointers
      free: init_free(size),
      # references to the data
      refs: :atomics.new(size, signed: true),
      # mapper `reference -> data`
      mapper_fun: Keyword.get(opts, :mapper_fun)
    }
    |> then(fn state ->
      if mode == @doubly_linked_mode do
        Map.put(state, :prev, init_links(size))
      else
        state
      end
    end)
  end

  def get(list, idx) when is_integer(idx) and idx > 0 do
    case get_pointer(list, idx) do
      nil -> nil
      pointer -> data(list, pointer)
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


  def add_first(list, data) when is_integer(data) do
    ## Store data in 'free' element of the list
    allocated = allocate(list)
    set_data(list, allocated, data)
    head = head(list)
    set_next(list, allocated, head)
    add_first_mode(list, head, allocated)
    ## Allocated element becomes the new head
    set_head(list, allocated)
  end

  defp add_first_mode(%{mode: @singly_linked_mode} = _list, _head, _allocated) do
    :ok
  end

  defp add_first_mode(%{mode: @doubly_linked_mode} = list, head, allocated) do
    set_previous(list, allocated, @terminator)
    if head(list) == @terminator do
      set_tail(list, allocated)
    else
      set_previous(list, head, allocated)
    end
  end

  def insert(%{mode: mode} = list, idx, data)
      when is_integer(data) and is_integer(idx) and idx > 0 do
    cond do
      idx > size(list) ->
        {:error, {:no_index, idx}}

      empty?(list) ->
        add_first(list, data)

      true ->
        idx_pointer = get_pointer(list, idx)
        next_pointer = next(list, idx_pointer)
        allocated = allocate(list)
        set_data(list, allocated, data)
        set_next(list, allocated, next_pointer)
        set_next(list, idx_pointer, allocated)
        ## Build `prev` links
        ## allocated.prev <- idx_pointer
        if mode == @doubly_linked_mode do
          set_previous(list, allocated, idx_pointer)
          ## allocated.next.prev <- allocated
          if next_pointer == @terminator do
            ## insertion at the end - update the tail
            set_tail(list, allocated)
          else
            ## insertion in between - point the `prev` link of next pointer
            ## to newly allocated element
            set_previous(list, next_pointer, allocated)
          end
        end
    end
  end

  def add_last(list, data) when is_integer(data) do
    if empty?(list) do
      add_first(list, data)
    else
      insert(list, size(list), data)
    end
  end

  def delete(%{mode: mode} = list, idx) when is_integer(idx) and idx > 0 do
    cond do
      idx > size(list) ->
        {:error, {:no_index, idx}}

      # Removing first element of the list
      idx == 1 ->
        deallocate(list, idx)
        head = head(list)
        set_head(list, next(list, head))
        if mode == @doubly_linked_mode && head != @terminator do
          set_previous(list, head, @terminator)
        end

      true ->
        pointer = get_pointer(list, idx - 1)
        next_pointer = next(list, pointer)
        deallocate(list, idx)
        set_next(list, pointer, next(list, next_pointer))
    end
  end

  defp delete_mode(%{mode: @singly_linked_mode} = _list, _pointer, _next_pointer, _last?) do
    :ok
  end

  defp delete_mode(%{handle: handle, mode: @doubly_linked_mode, prev: prev} = _list, pointer, next_pointer, last?) do
    prev_element = Array.get(prev, pointer)
    if last? do
      Array.put(handle, 2, prev_element)
    else
      Array.put(prev, prev_element, next_pointer)
    end
  end

  def to_list(list) do
    to_list(list, head(list), [])
  end

  defp to_list(_list, @terminator, acc) do
    Enum.reverse(acc)
  end

  defp to_list(list, pointer, acc) do
    to_list(list, next(list, pointer), [data(list, pointer) | acc])
  end

  def empty?(list) do
    head(list) == @terminator
  end

  def size(%{capacity: capacity, free: free} = _list) do
    capacity - Stack.size(free)
  end

  def default_opts() do
    [
      mode: @singly_linked_mode,
      mapper_fun: &Function.identity/1
    ]
  end

  ## Helpers
  ##
  ## Initialize handle.
  ## First element - pointer to the head
  ## Second element (for :doubly_linked) is a tail
  defp init_handle(mode) do
    size = if mode == @singly_linked_mode do
      1
    else
      2
    end

    Array.new(size, @terminator)
  end
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

  def head(%{handle: handle} = _list) do
    Array.get(handle, 1)
  end

  def tail(%{mode: @singly_linked_mode} = _list) do
    nil
  end

  def tail(%{handle: handle, mode: @doubly_linked_mode}) do
    Array.get(handle, 2)
  end

  def set_next(_list, @terminator, _next_pointer) do
    :noop
  end

  def set_next(%{next: pointers} = _list, pointer, next_pointer) do
    Array.put(pointers, pointer, next_pointer)
  end

  def set_previous(_list, @terminator, _next_pointer) do
    :noop
  end

  def set_previous(%{mode: @doubly_linked_mode, prev: pointers} = _list, pointer, prev_pointer) do
    Array.put(pointers, pointer, prev_pointer)
  end

  def set_previous(_list, _pointer, _prev_pointer) do
    :noop
  end

  def set_data(%{refs: refs} = _list, pointer, data_ref) do
    Array.put(refs, pointer, data_ref)
  end

  def set_head(%{handle: handle} = _list, pointer) do
    Array.put(handle, 1, pointer)
  end

  def set_tail(%{handle: handle, mode: @doubly_linked_mode} = _list, pointer) do
    Array.put(handle, 2, pointer)
  end

  def set_tail(_list, _pointer) do
    :noop
  end

  def data(%{refs: refs, mapper_fun: mapper} = _list, pointer) do
    mapper.(Array.get(refs, pointer))
  end

  def next(_list, @terminator) do
    nil
  end

  def next(%{next: pointers} = _list, pointer) do
    Array.get(pointers, pointer)
  end

  def prev(_list, @terminator) do
    nil
  end

  def prev(%{prev: pointers} = _list, pointer) do
    Array.get(pointers, pointer)
  end

  def allocate(%{free: free} = _list) do
    Stack.pop(free) || throw(:list_over_capacity)
  end

  def deallocate(%{free: free} = _list, idx) when is_integer(idx) and idx > 0 do
    Stack.push(free, idx)
  end
end
