defmodule InPlace.LinkedList do
  @moduledoc """
  [Singly linked list](https://en.wikipedia.org/wiki/Linked_list#Singly_linked_list)
  The data entries are stored as integers.
  They will be interpreted (as references) by the calling application.
  Note: indices are 1-based.
  Options:
    - `mode` :: :singly_linked | :doubly_linked
    - `circular` :: boolean()
      optional, `false` by default;
    - `undo` :: boolean()
      If true (`false` by default), the removed elements can be restored, one at time, in reverse order
       (see `restore/1`). This can be used as a mechanism for backtracking
    - `:mapper_fun`  # maps data entries to application data
      optional, &Function.identity/1 by default
  """
  alias InPlace.{Array, Stack}

  ## List terminator
  @terminator 0
  @singly_linked_mode :singly_linked
  @doubly_linked_mode :doubly_linked

  def new(values_or_size, opts \\ [])

  def new(values, opts) when is_list(values) do
    new(max(length(values), Keyword.get(opts, :capacity, 0)), opts)
    |> tap(fn ll -> Enum.each(values, fn v -> append(ll, v) end) end)
  end

  def new(size, opts) when is_integer(size) and size > 0 do
    opts = Keyword.merge(default_opts(), opts)
    mode = Keyword.get(opts, :mode)
    circular? = Keyword.get(opts, :circular)
    undo? = Keyword.get(opts, :undo) && circular? && mode == @doubly_linked_mode

    if mode not in [@singly_linked_mode, @doubly_linked_mode] do
      throw({:error, {:unknown_mode, mode}})
    end

    %{
      capacity: size,
      ## mode (:singly_linked or :doubly_linked)
      mode: mode,
      ## circular?
      circular: circular?,
      ## Option to "undo" removals; see restore/1
      undo: undo?,
      ## holds the pointer to the first element of the list
      handle: init_handle(mode),
      # pointers (links) to the next element
      next: init_links(size),
      # pointer (links) to the previous element
      prev: init_links(size),
      # allocation pool
      free: init_free(size),
      # references to the data
      refs: :atomics.new(size, signed: true),
      # mapper `reference -> data`
      mapper_fun: Keyword.get(opts, :mapper_fun)
    }
    |> then(fn state ->
      if undo? do
        Map.put(state, :removed, Stack.new(size))
      else
        state
      end
    end)

  end

  ## Initialization
  ##
  defp default_opts() do
    [
      mode: @doubly_linked_mode,
      circular: true,
      undo: true,
      mapper_fun: &Function.identity/1

    ]
  end

  ## Initialize handle.
  ## Holds pointer to first element
  defp init_handle(_mode) do
    Array.new(1, @terminator)
  end

  ## Allocate links (pointers to the next element)
  defp init_links(size) do
    :atomics.new(size, signed: false)
  end

  ## The stack for tracking 'free' indices
  ## They can be reused after the element is removed from linked list
  ## (unless `undo=true`, which disables reuse).
  defp init_free(size) when is_integer(size) do
    ref = Stack.new(size)
    Enum.each(size..1//-1, fn idx -> Stack.push(ref, idx) end)
    ref
  end

  def head(%{handle: handle} = _list) do
    Array.get(handle, 1)
  end

  def tail(list) do
    prev(list, head(list))
  end

  def empty?(list) do
    head(list) == @terminator
  end

  def size(%{undo: undo?, capacity: capacity, free: free} = list) do
    capacity - Stack.size(free) - (undo? && Stack.size(list.removed) || 0)
  end

  def next(_list, @terminator) do
    @terminator
  end

  def next(list, pointer) do
    Array.get(list.next, pointer)
  end

  def prev(_list, @terminator) do
    @terminator
  end

  def prev(list, pointer) do
    Array.get(list.prev, pointer)
  end

  def append(list, data) when is_integer(data) do
    last_pointer = tail(list)
    add_pointer_after(list, last_pointer, data)
  end

  defp add_pointer_after(list, pointer, data) do
    allocated = allocate(list)
    set_data(list, allocated, data)
    case next(list, pointer) do
      @terminator ->
        ## Empty list, first pointer to set
        set_next(list, allocated, allocated)
        set_prev(list, allocated, allocated)
        set_head(list, allocated)
      next_pointer ->
        set_next(list, allocated, next_pointer)
        set_next(list, pointer, allocated)
        set_prev(list, allocated, pointer)
        set_prev(list, next_pointer, allocated)
    end
    allocated
  end

  def add_first(list, data) do
    new_pointer = add_pointer_after(list, tail(list), data)
    set_head(list, new_pointer)
  end

  def delete_pointer(list, pointer) do
    next_pointer = next(list, pointer)
    prev_pointer = prev(list, pointer)
    set_prev(list, next_pointer, prev_pointer)
    set_next(list, prev_pointer, next_pointer)
    if pointer == head(list) do
      set_head(list, size(list) == 1 && @terminator || next_pointer)
    end
    
    deallocate(list, pointer)
  end

  defp allocate(list) do
    Stack.pop(list.free) || throw(:list_over_capacity)
  end

  defp deallocate(list, pointer) do
    Stack.push(list.free, pointer)
  end

  defp set_head(list, pointer) do
    Array.put(list.handle, 1, pointer)
  end

  defp set_next(_list, _pointer, @terminator) do
    throw(:setting_invalid_next_pointer)
  end

  defp set_next(list, pointer, next_pointer) do
    Array.put(list.next, pointer, next_pointer)
  end

  defp set_prev(_list, _pointer, @terminator) do
    throw(:setting_invalid_prev_pointer)
  end

  defp set_prev(list, pointer, prev_pointer) do
    Array.put(list.prev, pointer, prev_pointer)
  end


  def set_data(list, pointer, data) do
    Array.put(list.refs, pointer, data)
  end

  def data(%{refs: refs, mapper_fun: mapper} = _list, pointer) do
    mapper.(Array.get(refs, pointer))
  end



end
