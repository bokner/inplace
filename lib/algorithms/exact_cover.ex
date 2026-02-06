defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm DLX (Exact cover via dancing links).
  Based on https://arxiv.org/pdf/cs/0011047 by Donald Knuth.

  Note: there is a never version of this algorithm
  (The Art of Computer Programming, vol. 4B, by Donald Knuth).
  It differs mostly by using more advanced internal state structure.
  """
  alias InPlace.{LinkedList, Array}

  def solve(options, solver_opts \\ []) do
    state = init(options)
    solver_opts = Keyword.merge(default_solver_opts(), solver_opts)

    try do
      search(1, Map.put(state, :solver_opts, solver_opts))
    catch
      :complete ->
        :ok
    end
  end

  defp default_solver_opts() do
    [
      solution_handler: fn options -> IO.inspect(options, label: :solution) end,
      choose_item_fun: fn _step, state -> min_options_item(state) end,
      stop_on: fn state -> num_solutions(state) == 1 end
    ]
  end

  def init(options) do
    ## Options are sets that contain item names.
    ## Build the state structures (roughly as described by D. Knuth)
    {item_map, entry_count, option_lists, option_membership} =
      Enum.reduce(
        Enum.with_index(options, 1), {Map.new(), 0, [], []},
          fn {option, option_idx},
              {directory, entry_idx, option_items, option_membership} = _acc ->
        {directory, entry_count, items, membership} =
          Enum.reduce(option, {directory, entry_idx, [], option_membership},
            fn item_name,
                {dir_acc, entry_idx_acc, option_items_acc, membership_acc} ->
            ## 1-based index, for convenience
            entry_idx_acc = entry_idx_acc + 1

            {
              Map.update(dir_acc, item_name, [entry_idx_acc], fn entries ->
                [entry_idx_acc | entries]
              end),
              entry_idx_acc,
              [entry_idx_acc | option_items_acc],
              [option_idx | membership_acc]
            }
          end)

        {directory, entry_count, [items | option_items], membership}
      end)

    #IO.inspect(option_membership, label: :membership)
    num_items = map_size(item_map)
    ## build item header, item and option lists
    {item_names, item_lists} = Enum.unzip(item_map)

    item_header =
      LinkedList.new(
        Enum.map(1..num_items, fn header_idx ->
          ## Header pointers.
          ## They will be used as the 'heads' of correspondent item lists.
          ## For the test example:
          ## `:c` item will be in the header with pointer 1 and content 17
          ## (as there are 16 entries total across all option lists)
          ## Then the item list that corresponds to :c, will form
          ## a (17, 1, 8) circuit.
          header_idx + entry_count
        end),
        deletion: :hide
      )

    option_counts = Array.new(num_items, 0)
    min_option_item = Array.new(2, 0)

    item_lists_ll =
      LinkedList.new(Enum.to_list(1..(entry_count + num_items)), deletion: :hide)
      |> tap(fn ll ->
        {_, min_option_idx, min_option_count} =
        item_lists
        |> Enum.reduce({1, nil, nil}, fn options, {item_header_idx, min_option_idx, min_option_count} ->
          item_top = entry_count + item_header_idx
          num_options = length(options)
          Array.put(option_counts, item_header_idx, num_options)
          ## create sublists of options per item
          item_options = [item_top | options]
          LinkedList.circuit(ll, item_options)
          {min_option_idx, min_option_count} =
            if num_options < min_option_count do
              {item_header_idx, num_options}
            else
              {min_option_idx, min_option_count}
            end
          {item_header_idx + 1, min_option_idx, min_option_count}
        end)
        update_min_item(min_option_item, min_option_idx, min_option_count)
      end)

    top = Array.new(num_items + entry_count, 0)
    LinkedList.iterate(
        item_header,
        fn p ->
          item_top = LinkedList.data(item_header, p)

          LinkedList.iterate(
            item_lists_ll,
            fn s ->
              Array.put(top, s, p)
            end,
            start: item_top
          )
        end
      )

    ## NOTE: we won't have to cover/uncover options, hence there is no "undoing" it
    ## We also do not need extra entries for header pointers,
    ## as was the case for item lists.
    ##
    option_lists_ll =
      LinkedList.new(Enum.to_list(1..entry_count), deletion: :hide)
      |> tap(fn ll ->
        Enum.each(
          option_lists,
          fn items -> LinkedList.circuit(ll, items) end
        )
      end)

    %{
      item_header: item_header,
      option_member_ids: init_option_member_ids(option_membership),
      item_names: item_names,
      top: top,
      item_lists: item_lists_ll,
      option_lists: option_lists_ll,
      item_option_counts: %{counts: option_counts, min_item: min_option_item},
      num_solutions: Array.new(1, 0),
      ## buffer for building current solution
      solution: Array.new(length(options))
    }
  end

  defp search(
         k,
         %{
           item_header: item_header,
           solution: solution,
           solver_opts: solver_opts
         } = state
       ) do
    stop_condition = solver_opts[:stop_on]

    if stop_condition && stop_condition.(state) do
      throw(:complete)
    else
      choose_item_fun = solver_opts[:choose_item_fun]
      ## Knuth:
      # If R[h] = h, print the current solution and return.
      ##
      if LinkedList.empty?(item_header) do
        solution(state, Keyword.get(solver_opts, :solution_handler))
      else
        ## Knuth:
        # Otherwise choose a column object c (see below).
        ##
        c = choose_item_fun.(k, state)
        ## Knuth:
        # Cover column c.
        ##
        if c do
          cover(c, state)
          ## Knuth:
          # For each r ← D[c], D[D[c]], . . . , while r != c,
          #
          iterate_column(
            c,
            fn r ->
              ## Knuth:
              #   set O[k] ← r;
              ##
              add_to_solution(solution, k, r)
              ## Knuth:
              # for each j ← R[r], R[R[r]], . . . , while j != r,
              #  cover column j
              ##
              # {_num_covered_columns, _num_removed_entries} =
              cover_option_columns(r, state)
              search(k + 1, state)
              ## Knuth:
              # for each j ← L[r], L[L[r]], . . . , while j != r,
              #  uncover column j.
              ##
              uncover_option_columns(r, state)
              # uncover(r, num_covered_columns, num_removed_entries, state)
              # uncover(r, )
            end,
            state
          )

          ## Knuth:
          # Uncover column c and return.
          ##
          uncover(c, state)
        end
      end
    end
  end

  defp cover_option_columns(option_pointer, state) do
    iterate_row(
      option_pointer,
      fn j ->
        cond do
          j != option_pointer ->
            # Tricky; cover/2 expects header (not item) pointer,
            # so we need to convert
            get_top(state, j)
            |> cover(state)

          true ->
            :ok
        end
      end,
      state
    )
  end

  defp uncover_option_columns(option_pointer, state) do
    iterate_row(
      option_pointer,
      fn j ->
        cond do
          j != option_pointer ->
            # Tricky; cover/2 expects header (not item) pointer,
            # so we need to convert
            get_top(state, j)
            |> uncover(state)

          true ->
            :ok
        end
      end,
      state,
      false
    )
  end

  def random_item(%{item_header: item_header} = _state) do
    header_size = LinkedList.size(item_header)
    random_position = Enum.random(1..header_size)

    LinkedList.iterate(
      item_header,
      fn p, acc ->
        if acc == random_position do
          {:halt, p}
        else
          {:cont, acc + 1}
        end
      end,
      initial_value: 1
    )
  end

  def min_options_item(%{item_header: item_header} = state) do
    {min_item, min_option_count} = get_min_item(state)

    if covered?(min_item, state) do
      LinkedList.iterate(
        item_header,
        fn p, {_min_p, min_acc} = acc ->
          ## find min of option counts iterating over column (item) pointers
          case get_item_options_count(state, p) do
            0 -> acc
            1 ->
              {:halt, {p, 1}}
            count ->
              {p, min(count, min_acc)}
          end
        end,
        initial_value: {nil, nil},
        forward: true
      )
      |> then(fn {min_item, min_value} ->
        if min_option_count > min_value do
           update_min_item(state, min_item, min_value)
        end

        min_item
      end)
    else
      min_item
    end
  end

  defp get_item_options_count(state, item_pointer) do
    Array.get(state.item_option_counts.counts, item_pointer)
  end

  defp add_to_solution(solution, step, item) do
    Array.put(solution, step, item)
  end

  defp solution(state, solution_handler) do
    solution = state[:solution]

    Array.update(state.num_solutions, 1, fn n -> n + 1 end)

    Enum.reduce_while(1..Array.size(solution), [], fn idx, acc ->
      case Array.get(solution, idx) do
        nil ->
          {:halt, acc}

        option_entry ->
          {:cont,
           [
            ## solution_handler expects 0-based option index
            (get_option_id(state, option_entry) - 1) | acc
           ]}
      end
    end)
    |> solution_handler.()
  end

  def num_solutions(state) do
    Array.get(state.num_solutions, 1)
  end

  ## `column_pointer` is a pointer to
  ## an entry in "item header" list.
  ## This entry, in turn, contains the pointer to
  ## a head of a sublist in item_lists,
  ## from which we will handle (reduce) the options
  ## associated with the item.
  ##
  def cover(
        column_pointer,
        %{
          item_header: item_header,
          item_lists: item_lists
        } = state
      )
      when is_integer(column_pointer) and column_pointer > 0 do
    ## Knuth:
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    ##

    LinkedList.delete_pointer(item_header, column_pointer)
    ## Knuth:
    #  For each i ← D[c], D[D[c]] , . . . , while i != c,
    ##
    iterate_column(
      column_pointer,
      ## count of removed entries
      ## Knuth:
      # For each j ← R[i], R[R[i]] , . . . , while j != i,
      ##
      fn i ->
        iterate_row(
          i,
          fn j ->
            ## Knuth:
            # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
            ##
            if i != j do
              LinkedList.delete_pointer(item_lists, j)
              # and set S[C[j]]  ← S[C[j]]  − 1
              decrease_option_count(state, j)
            end
          end,
          state
        )
      end,
      state
    )
  end

  ## This variant of cover/2 is for debugging only.
  ## We won't need to pass item name/id, passing item pointer
  ## would be sufficient for the implementation
  def cover(item_name, state) do
    cover(column_pointer(item_name, state), state)
  end

  defp covered?(column_pointer, %{item_header: item_header} = _state) do
    LinkedList.pointer_deleted?(item_header, column_pointer)
  end

  def uncover(
        column_pointer,
        %{
          item_header: item_header,
          item_lists: item_lists
        } = state
      )
      when is_integer(column_pointer) and column_pointer > 0 do
    ## Knuth:
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    ##

    LinkedList.restore_pointer(item_header, column_pointer)
    ## Knuth:
    #  For each i ← D[c], D[D[c]] , . . . , while i != c,
    ##
    iterate_column(
      column_pointer,
      ## count of removed entries
      ## Knuth:
      # For each j ← R[i], R[R[i]] , . . . , while j != i,
      ##
      fn i ->
        iterate_row(
          i,
          fn j ->
            ## Knuth:
            # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
            ##
            if i != j do
              LinkedList.restore_pointer(item_lists, j)
              # and set S[C[j]]  ← S[C[j]]  − 1
              increase_option_count(state, j)
            end
          end,
          state,
          false
        )
      end,
      state
    )
  end

  defp decrease_option_count(state, item_option_pointer) do
    top = get_top(state, item_option_pointer)

    update_option_count(state, top, fn val ->
      new_val = val - 1

      maybe_update_min_item(state, top, new_val)
      new_val
    end)
  end

  def increase_option_count(state, item_option_pointer) do
    top = get_top(state, item_option_pointer)
    update_option_count(state, top, fn val -> val + 1 end)
  end

  ## 'update_fun/1' takes and updates current option count for given item header pointer
  def update_option_count(state, item_header_pointer, update_fun)
      when is_function(update_fun, 1) do
    Array.update(state.item_option_counts.counts, item_header_pointer, update_fun)
  end

  ## Mapping from 'absolute' option member ids (as in option_lists)
  ## to option ids they belong to
  defp init_option_member_ids(option_membership) do
    ## option membership is in reverse order, i.e. the members that belong to the first
    ## option are in the end of the membership list.
    l = length(option_membership)
    arr = Array.new(l, 0)

    Enum.reduce(option_membership, l, fn idx, acc ->
      Array.put(arr, acc, idx)
        acc - 1
      end)
      arr
  end

  defp get_option_id(%{option_member_ids: option_ids} = _state, option_entry) do
    Array.get(option_ids, option_entry)
  end

  defp update_min_item(
         %{item_option_counts: %{min_item: min_item}} = _state,
         item_pointer,
         option_count
       ) do
    update_min_item(min_item, item_pointer, option_count)
  end

  defp update_min_item(min_item, item_pointer, option_count) do
    Array.put(min_item, 1, item_pointer)
    Array.put(min_item, 2, option_count)
  end

  defp get_min_item(%{item_option_counts: %{min_item: min_item}} = _state) do
    {Array.get(min_item, 1), Array.get(min_item, 2)}
  end

  defp maybe_update_min_item(state, item_pointer, option_count) do
    {_current_min_item, current_min_count} = get_min_item(state)

    if current_min_count > option_count ||
         (current_min_count == option_count && !covered?(item_pointer, state)) do
      update_min_item(state, item_pointer, option_count)
    else
      :ok
    end
  end

  defp get_top(%{top: top} = _state, el) do
    get_top(top, el)
  end

  defp get_top(top, el) do
    Array.get(top, el)
  end

  ## `column pointer` is a pointer in `item_header` linked list.
  ## The element it points to is a 'top' of the column,
  ## which is a pointer in `item_lists` linked list
  defp iterate_column(
         column_pointer,
         iterator_fun,
         %{item_header: item_header, item_lists: columns} = _state
       ) do
    column_top = LinkedList.data(item_header, column_pointer)

    LinkedList.iterate(
      columns,
      fn column_element ->
        if column_element != column_top do
          iterator_fun.(column_element)
        end
      end,
      start:
        LinkedList.next(columns, column_top)
    )
  end

  ## `row_pointer` is any pointer in the list of `option_lists` items.
  ## `option_lists` is a linked list partitioned by option sublists
  ## , each sublist represents an option.
  defp iterate_row(
         row_pointer,
         iterator_fun,
         %{option_lists: rows} = _state,
         forward? \\ true
       ) do
    LinkedList.iterate(
      rows,
      fn p ->
        if p != row_pointer, do: iterator_fun.(p)
      end,
      start: row_pointer,
      forward: forward?
    )
  end

  defp column_pointer(item_name, %{item_names: item_names} = _state) do
    length(item_names) -
      Enum.find_index(item_names, fn name -> name == item_name end)
  end
end
