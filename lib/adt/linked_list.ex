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
    - `deletion` :: :reclaim | :hide | :rewind
      Handles if the element pointer could be restored later (see delete_pointer/2), and how
      to restore it:
      `:reclaim` (default) - element can not be restored, the pointer will be put back to the `allocation` pool;
      `:hide` - element can be restored by re-linking with it's former `left` and `right` neighbors;
       The element stays in the list, but can not be reached
       except by directly addressed by it's pointer. The element can be put back to it's position
       by reconnecting previously prior and next elements back to that element (see hide/2 and restore/2);
      `:rewind` - if specified, the special stack of removed element pointers is maintained.
        The effect of removal will be the same as for  :hide, except that
        The elements can be restored in the reverse order of their removal by using `rewind/1`.
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
    deletion_mode = Keyword.get(opts, :deletion)

    if mode not in [@singly_linked_mode, @doubly_linked_mode] do
      throw({:error, {:unknown_mode, mode}})
    end

    %{
      capacity: size,
      size: Array.new(1, 0),
      ## mode (:singly_linked or :doubly_linked)
      mode: mode,
      ## circular?
      circular: circular?,
      ## Option to handle removals
      deletion: deletion_mode,
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
      if deletion_mode == :rewind do
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
      deletion: :reclaim,
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
  ## (unless `deletion in [:hide, :rewind]`, which disables reuse).
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

  def size(list) do
    Array.get(list.size, 1)
  end

  def inc_size(list, delta) do
    Array.update(list.size, 1, fn s -> s + delta end)
  end

  def available(list) do
    list.capacity - size(list)
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
    :ok
  end

  defp add_pointer_after(list, pointer, data) do
    allocated = allocate(list)
    set_data(list, allocated, data)

    case next(list, pointer) do
      @terminator ->
        ## Empty list, first pointer to set
        wire(list, allocated, allocated)
        set_head(list, allocated)

      next_pointer ->
        wire(list, allocated, next_pointer)
        wire(list, pointer, allocated)
    end

    allocated
  end

  def add_first(list, data) do
    new_pointer = add_pointer_after(list, tail(list), data)
    set_head(list, new_pointer)
  end

  def delete_pointer(list, pointer) do
    if pointer_deleted?(list, pointer) do
      false
    else
      next_pointer = next(list, pointer)
      prev_pointer = prev(list, pointer)
      set_prev(list, next_pointer, prev_pointer)
      set_next(list, prev_pointer, next_pointer)

      if pointer == head(list) do
        set_head(list, (size(list) == 1 && @terminator) || next_pointer)
      end

      dispose_or_hide(list, pointer)
    end
  end

  def pointer_deleted?(list, pointer) do
      empty?(list) ||
        pointer != prev(list, next(list, pointer))
  end

  defp allocate(list) do
    if size(list) == list.capacity do
      throw(:list_over_capacity)
    else
      inc_size(list, 1)
      Stack.pop(list.free)
    end
  end

  defp dispose_or_hide(%{deletion: deletion_mode} = list, pointer) do
    inc_size(list, -1)
    case deletion_mode do
      :hide ->
        :ok
      :reclaim ->
        dispose(list, pointer)
      :rewind ->
        hide(list, pointer)
    end
  end

  defp dispose(list, pointer) do
    Stack.push(list.free, pointer)
  end

  defp hide(list, pointer) do
    Stack.push(list.removed, pointer)
  end

  def rewind(%{deletion: :rewind, removed: removed} = list) do
    case Stack.pop(removed) do
      nil ->
        false

      restored_pointer ->
        restore_pointer(list, restored_pointer)
        {:restored, restored_pointer}
    end
  end

  def rewind(_list) do
    throw(:rewind_disabled)
  end

  def restore_pointer(%{deletion: deletion_mode} = list, pointer) when deletion_mode in [:hide, :rewind] do
    next_pointer = next(list, pointer)
    prev_pointer = prev(list, pointer)
    set_prev(list, next_pointer, pointer)
    set_next(list, prev_pointer, pointer)
    ## Special cases:
    ## - next_pointer for restored pointer
    ## points to a current head;
    ## - the list is empty
    ## - there is no more pointers in `removed` stack
    cond do
      deletion_mode == :rewind && Stack.empty?(list.removed) ->
         set_head(list, 1)

      head(list) in [@terminator, next_pointer] ->
        ## We replace head with the restored pointer
        set_head(list, pointer)

      true ->
        :ok
    end

    inc_size(list, 1)

    :ok
  end

  def restore_pointer(_list, _pointer) do
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

  ############
  ## Iteration
  ############
  def to_list(list) do
    reduce(list, []) |> Enum.reverse()
  end

  def reduce(list, initial_value, reducer \\ nil) do
    iterate(list, reducer || default_reducer(list), initial_value: initial_value)
  end

  defp default_reducer(list) do
    fn p, acc ->
      [data(list, p) | acc]
    end
  end

  def iterate(list, action, opts \\ [])

  def iterate(list, action, opts) do
    start = Keyword.get(opts, :start, head(list))
    forward? = Keyword.get(opts, :forward, true)
    initial_value = Keyword.get(opts, :initial_value, [])

    stop_on =
      Keyword.get(opts, :stop_on, fn next ->
        last_pointer = (list.circular && start) || @terminator
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
        new_acc =
          case result do
            {:cont, r} ->
              r

            r ->
              r
          end

        next_p = next(list, current_pointer)

        if next_p == current_pointer || stop_on.(next_p) do
          new_acc
        else
          iterate_impl(list, next_p, stop_on, action, new_acc)
        end
    end
  end

  ## Iteration with side-effects
  defp iterate_impl(_list, @terminator, _stop_on, action, _forward?)
       when is_function(action, 1) do
    :ok
  end

  defp iterate_impl(list, current_pointer, stop_on, action, forward?)
       when is_function(action, 1) do
    case action.(current_pointer) do
      :halt ->
        :ok

      _ ->
        next_p = (forward? && next(list, current_pointer)) || prev(list, current_pointer)

        if next_p == current_pointer || stop_on.(next_p) do
          :ok
        else
          iterate_impl(list, next_p, stop_on, action, forward?)
        end
    end
  end

  ## "Reducer" iteration
  defp iterate_impl(_list, @terminator, _stop_on, action, _forward?, acc)
       when is_function(action, 2) do
    acc
  end

  defp iterate_impl(list, current_pointer, stop_on, action, forward?, acc)
       when is_function(action, 2) do
    case action.(current_pointer, acc) do
      {:halt, new_acc} ->
        new_acc

      result ->
        new_acc =
          case result do
            {:cont, r} ->
              r

            r ->
              r
          end

        next_p = (forward? && next(list, current_pointer)) || prev(list, current_pointer)

        if stop_on.(next_p) do
          new_acc
        else
          iterate_impl(list, next_p, stop_on, action, forward?, new_acc)
        end
    end
  end

  #################
  ## Positional API
  #################
  @doc """
    Get element at `position` (1-based)
  """
  def get(list, position) when is_integer(position) and position > 0 do
    if position <= size(list) do
      iterate(
        list,
        fn pointer, idx_acc ->
          if idx_acc == position do
            {:halt, data(list, pointer)}
          else
            {:cont, idx_acc + 1}
          end
        end,
        initial_value: 1
      )
    end
  end

  def get(_list, _position) do
    nil
  end

  @doc """
  Insert `data` element at `position` (1-based)
  """
  def insert(list, position, data) when is_integer(position) and is_integer(data) do
    cond do
      position == 1 ->
        add_first(list, data)

      position == size(list) + 1 ->
        append(list, data)

      position <= size(list) ->
        iterate(
          list,
          fn pointer, idx_acc ->
            if idx_acc == position - 1 do
              {:halt, add_pointer_after(list, pointer, data)}
            else
              {:cont, idx_acc + 1}
            end
          end,
          initial_value: 1
        )

      true ->
        false
    end
  end

  @doc """
  Delete element at `position` (1-based)
  """
  def delete(list, position) when is_integer(position) and position > 0 do
    cond do
      position <= size(list) ->
        iterate(
          list,
          fn pointer, idx_acc ->
            if idx_acc == position do
              {:halt, delete_pointer(list, pointer)}
            else
              {:cont, idx_acc + 1}
            end
          end,
          initial_value: 1
        )

      true ->
        false
    end
  end

  #######################################
  ### Sublists (circuits, partitions...)
  #######################################
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
    set_prev(list, second, first)
  end
end
