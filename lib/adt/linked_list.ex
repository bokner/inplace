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
    - `reclaim` :: boolean()
      Handles if the element can be restored after removal (see delete_pointer/2).
      `true` - element can not be restored, the place occupied by it can be reclaimed
        (we will add the pointer to the removed element to the list of free pointers);
      `false` - the element will be "hidden" by connecting prior and next elements of that element.
       The element stays in the list, but can not be reached
       except by directly addressed by it's pointer. The element can be put back to it's position
       by reconnecting previously prior and next elements back to that element (see hide/2 and restore/2);
        Additionally, supports 'removal history', which could be used to "rewind" removals
        in reverse order (see restore/1).
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
    restore? = Keyword.get(opts, :restore)

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
      restore: restore?,
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
      if restore? do
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
      restore: false,
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
  ## (unless `restore=true`, which disables reuse).
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

  def size(%{restore: restore?, capacity: capacity, free: free} = list) do
    capacity - Stack.size(free) - (restore? && Stack.size(list.removed) || 0)
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
    apply_restore_strategy(list, pointer)
  end

  defp allocate(list) do
    Stack.pop(list.free) || throw(:list_over_capacity)
  end

  defp apply_restore_strategy(list, pointer) do
    if list.restore do
      store_removal(list, pointer)
    else
      deallocate(list, pointer)
    end
  end


  defp deallocate(list, pointer) do
    Stack.push(list.free, pointer)
  end

  defp store_removal(list, pointer) do
    Stack.push(list.removed, pointer)
  end

  def restore(%{restore: true, removed: removed} = list) do
    case Stack.pop(removed) do
      nil -> false
      restored_pointer ->
        restore(list, restored_pointer)
      end
  end

  def restore(_list) do
    throw(:restore_disabled)
  end

  def restore(%{restore: true} = list, pointer) do
    next_pointer = next(list, pointer)
    set_prev(list, next_pointer, pointer)
    set_next(list, prev(list, pointer), pointer)
    ## Special case: next_pointer for restored pointer
    ## is a current head
    if next_pointer == head(list) do
      ## We replace head with the restored pointer
      set_head(list, pointer)
    end

  end

  def restore(_list, _pointer) do
    throw(:restore_disabled)
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

  ## Iteration
  ##
  def to_list(list) do
    reduce(list, []) |> Enum.reverse()
  end

  def reduce(list, initial_value, reducer \\ nil) do
    iterate(list, action: (reducer || default_reducer(list)), initial_value: initial_value)
  end

  defp default_reducer(list) do
    (fn p, acc ->
        [data(list, p) | acc]
    end)
  end

  def iterate(list, opts \\ [])

  def iterate(list, opts) do
    start = Keyword.get(opts, :start, head(list))
    forward? = Keyword.get(opts, :forward, true)
    action = Keyword.get(opts, :action, default_reducer(list))
    initial_value = Keyword.get(opts, :initial_value, [])
    stop_on = Keyword.get(opts, :stop_on, fn next ->
      last_pointer = list.circular && start || @terminator
      next == last_pointer
    end)

    ## If action is of arity 1, it's a "side-effect" function.
    ## The argument is a pointer.
    ## For instance, it might conditionally delete some entries,
    ## etc.
    ## The result of the action call would be ignored.
    ## If action is of arity 2, it's a "reducer" function
    ## The arguments are : pointer and accumulated value
    ## If {:halt, term()} is returned, the iteration is halted with term()
    ## If {:cont, term()} or term() is returned, the iteration continues.
    ##
    cond do
      is_function(action, 1) ->
        iterate_impl(list, start, stop_on, action, forward?)
      is_function(action, 2) ->
        iterate_impl(list, start, stop_on, action, forward?, initial_value)
      true ->
        throw({:error, :action_invalid_arity})
    end

  end

  ## "Reducer" iteration
  defp iterate_impl(_list, @terminator, _stop_on, action, acc) when is_function(action, 2) do
    acc
  end

  defp iterate_impl(list, current_pointer, stop_on, action, acc) when is_function(action, 2) do
    case action.(current_pointer, acc) do
      {:halt, new_acc} ->
        new_acc
      result ->
        new_acc = case result do
            {:cont, r} ->
              r
            r -> r
          end
          next_p = next(list, current_pointer)

          if stop_on.(next_p) do
              new_acc
          else
            iterate_impl(list, next_p, stop_on, action, new_acc)
          end
        end

  end

  ## Iteration with side-effects
  defp iterate_impl(_list, @terminator, _stop_on, action, _forward?) when is_function(action, 1) do
    :ok
  end

  defp iterate_impl(list, current_pointer, stop_on, action, forward?) when is_function(action, 1) do
    case action.(current_pointer) do
      :halt -> :ok
      _ ->
        next_p = forward? && next(list, current_pointer) || prev(list, current_pointer)
        if stop_on.(next_p) do
          :ok
        else
          iterate_impl(list, next_p, stop_on, action, forward?)
        end
      end
  end

  ## "Reducer" iteration
  defp iterate_impl(_list, @terminator, _stop_on, action, _forward?, acc) when is_function(action, 2) do
    acc
  end

  defp iterate_impl(list, current_pointer, stop_on, action, forward?, acc) when is_function(action, 2) do
    case action.(current_pointer, acc) do
      {:halt, new_acc} ->
        new_acc
      result ->
        new_acc = case result do
            {:cont, r} ->
              r
            r -> r
          end
          next_p = forward? && next(list, current_pointer) || prev(list, current_pointer)

          if stop_on.(next_p) do
              new_acc
          else
            iterate_impl(list, next_p, stop_on, action, forward?, new_acc)
          end
        end

  end





end
