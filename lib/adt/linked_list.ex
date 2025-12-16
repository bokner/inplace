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
    |> tap(fn ll -> Enum.each(values, fn v -> add_last(ll, v) end) end)
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
    |> then(fn state ->
      if undo? do
        Map.put(state, :removed, Stack.new(size))
      else
        state
      end
    end)

  end

  @doc """
  This will create a circuit out of the list of pointers.

  !!!!! Hazard warning !!!!!
  If you want to avoid infinite loops
  while iterating over the list that contains circuits,
  make sure that you start the iteration within the circuit
  (using :start option fir iterate/2).

  For instance
  ```elixir
  import InPlace.LinkedList
  ll = new(Enum.to_list(1..10))
  circuit(ll, [2, 4, 6])
  iterate, start: 1, action: fn p -> IO.inspect(p) end
  ```
  will loop indefinitely, as the iteration will be trapped in `2 -> 4 -> 6` circuit
  once entering it from `1` pointer.
  """
  def circuit(_list, []) do
    :ok
  end

  def circuit(list, [single]) do
    wire(list, single, single)
  end

  def circuit(list, [first, second | rest] = _pointers) do
    wire(list, first, second)
    last = circuit_impl(list, second, rest)
    ## Short the circuit
    wire(list, last, first)
  end

  defp circuit_impl(_list, last, []) do
    last
  end

  defp circuit_impl(list, current, [next | rest]) do
    wire(list, current, next)
    circuit_impl(list, next, rest)
  end

  defp wire(list, first, second) do
    set_next(list, first, second)
    set_previous(list, second, first)
  end

  def get(list, idx) when is_integer(idx) and idx > 0 do
    case get_pointer(list, idx) do
      nil -> nil
      pointer -> data(list, pointer)
    end
  end

  def get_pointer(list, idx) when is_integer(idx) and idx > 0  do
    get_pointer(list, head(list), 0, idx)
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
        next_pointer = next_pointer(list, idx_pointer)
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

  def delete(list, idx) when is_integer(idx) and idx > 0 do
    if idx > size(list) do
      {:error, {:no_index, idx}}
    else
      # Removing first element of the list
      if idx == 1 do
        current_head = head(list)
        delete_pointer(list, current_head)

        {:removed, current_head}
      else
        pointer = get_pointer(list, idx - 1)
        pointer_to_delete = next_pointer(list, pointer)
        pointer_next = next_pointer(list, pointer_to_delete)
        set_next(list, pointer, pointer_next)
        delete_pointer(list, pointer_to_delete)

        {:removed, pointer_to_delete}
      end
    end
  end

  def delete_pointer(_list, @terminator) do
    :ok
  end

  def delete_pointer(%{mode: mode} = list, pointer) do
    forget_or_hide(list, pointer)

    cond do
      pointer == head(list) ->
        next_head = next_pointer(list, pointer)
        set_head(list, next_head)

        if mode == @doubly_linked_mode && next_head != @terminator do
          set_previous(list, next_head, @terminator)
        end

      mode == @doubly_linked_mode ->
        next_pointer = next_pointer(list, pointer)
        if pointer == tail(list) do
            ## Last element
          new_tail = prev(list, pointer)
          set_tail(list, new_tail)
        end
        prev_pointer = prev(list, pointer)
        set_next(list, prev_pointer, next_pointer)
        set_previous(list, next_pointer, prev_pointer)

      true ->
        :ok
    end
  end

  def pointer_deleted?(%{mode: mode} = list, pointer) do
    if mode == @doubly_linked_mode do
      # previous = prev(list, pointer)
      # previous == @terminator ||
      # pointer != next(list, previous)
      case next_pointer(list, pointer) do
        @terminator ->
          previous = prev_pointer(list, pointer)
          previous == @terminator ||pointer != next_pointer(list, previous)
        next ->
          pointer != prev_pointer(list, next)
        end
    else
      false
    end
  end

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

  def empty?(list) do
    head(list) == @terminator
  end

  def size(%{undo: undo?, capacity: capacity, free: free} = list) do
    capacity - Stack.size(free) - (undo? && Stack.size(list.removed) || 0)
  end

  def default_opts() do
    [
      mode: @doubly_linked_mode,
      circular: true,
      undo: false,
      mapper_fun: &Function.identity/1
    ]
  end

  ## Helpers
  ##
  ## Initialize handle.
  ## First element - pointer to the head
  ## Second element (for :doubly_linked) is a tail
  defp init_handle(mode) do
    size =
      if mode == @singly_linked_mode do
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
  ## (unless `undo=true`, which disables reuse).
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
    :ok
  end

  def set_next(%{next: pointers} = _list, pointer, next_pointer) do
    Array.put(pointers, pointer, next_pointer)
  end

  def set_previous(_list, @terminator, _next_pointer) do
    :ok
  end

  def set_previous(%{mode: @doubly_linked_mode, prev: pointers} = _list, pointer, prev_pointer) do
    Array.put(pointers, pointer, prev_pointer)
  end

  def set_previous(_list, _pointer, _prev_pointer) do
    :ok
  end

  def set_data(%{refs: refs} = _list, pointer, data_ref) do
    Array.put(refs, pointer, data_ref)
  end

  def set_head(%{handle: handle} = list, pointer) do
    Array.put(handle, 1, pointer)

    if pointer == @terminator || size(list) == 1 do
      set_tail(list, pointer)
    end
    :ok
  end

  def set_tail(%{handle: handle, mode: @doubly_linked_mode} = _list, pointer) do
    Array.put(handle, 2, pointer)
  end

  def set_tail(_list, _pointer) do
    :ok
  end

  def data(%{refs: refs, mapper_fun: mapper} = _list, pointer) do
    mapper.(Array.get(refs, pointer))
  end

  def next(%{circular: circular?} = list, pointer) do
    case next_pointer(list, pointer) do
      @terminator when circular? ->
        head(list)
      next_pointer ->
        next_pointer
      end
  end

  def prev(%{circular: circular?} = list, pointer) do
    case prev_pointer(list, pointer) do
      @terminator when circular? ->
        tail(list)
      next_pointer ->
        next_pointer
      end
  end


  ## The `next_pointer/2` and `prev_pointer/2` functions ignore `circular` option,
  ## and act based on position of list terminator.
  ## We will use it when updating the list,
  ## so we can treat internal structure uniformly.
  ## The navigation over circular lists is implemented by next/2 and prev/2.
  ##
  defp next_pointer(%{next: pointers} = _list, pointer) do
    Array.get(pointers, pointer)
  end

  defp prev_pointer(%{prev: pointers} =  _list, pointer) do
    Array.get(pointers, pointer)
  end

  defp prev_pointer(_singly_linked, _pointer) do
    nil
  end

  defp allocate(%{free: free} = _list) do
    Stack.pop(free) || throw(:list_over_capacity)
  end

  ## If `undo` is enabled, record the pointer to removed element.
  ## Could be restored later for circular doubly linked list
  ## See `restore/1
  ##

  defp forget_or_hide(%{undo: undo?} = list, pointer) when is_integer(pointer) and pointer > 0 do
    cond do
      is_nil(undo?) ->
        :ok
      undo? ->
        hide_pointer(list, pointer)
      true ->
        forget_pointer(list, pointer)
      end
  end

  defp forget_pointer(%{free: free} = _list, pointer) do
    Stack.push(free, pointer)
  end

  defp hide_pointer(%{removed: removed} = _list, pointer) do
   Stack.push(removed, pointer)
  end

  def num_free_pointers(%{free: free} = _list) do
    Stack.size(free)
  end

  def restore(%{undo: true, removed: removed} = list) do
    case Stack.pop(removed) do
      nil -> false
      restored_pointer ->
        restore_pointer(list, restored_pointer)
      end
  end

  def restore(_list) do
    false
  end

  def restore_pointer(list, pointer) do
    next_pointer = next_pointer(list, pointer)
    ## Special case: next_pointer for restored pointer
    ## is a current head
    if next_pointer == head(list) do
      ## We replace head with the restored pointer
      set_head(list, pointer)
    else
      prev_pointer = prev(list, pointer)
      set_next(list, prev_pointer, pointer)
    end
    set_previous(list, next_pointer, pointer)
  end

end
