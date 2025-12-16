defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm DLX (Exact cover via dancing links).
  Based on https://arxiv.org/pdf/cs/0011047 by Donald Knuth.

  Note: there is a never version of this algorithm
  (The Art of Computer Programming, vol. 4B, by Donald Knuth).
  It differs mostly by using more advanced internal data structure.
  """
  alias InPlace.{LinkedList, Array}

  def solve(options, solver_opts \\ []) do
    data = init(options)
    search(1, data, Keyword.merge(default_solver_opts(), solver_opts))
  end

  defp default_solver_opts() do
    [
      solution_handler: fn options -> IO.inspect(options, label: :solution) end
    ]
  end

  defp init(options) do
    ## Options are sets that contain item names.
    ## Build the data structures (roughly as described by D. Knuth)
    {item_map, entry_count, option_lists, option_start_ids} =
      Enum.reduce(options, {Map.new(), 0, [], []}, fn option,
                                                      {directory, entry_idx, option_items,
                                                       option_start_ids} = _acc ->
        option_start_idx = entry_idx + 1

        {directory, entry_count, items} =
          Enum.reduce(option, {directory, entry_idx, []}, fn item_name,
                                                             {dir_acc, entry_idx_acc,
                                                              option_items_acc} ->
            ## 1-based index, for convenience
            entry_idx_acc = entry_idx_acc + 1

            {
              Map.update(dir_acc, item_name, [entry_idx_acc], fn entries ->
                [entry_idx_acc | entries]
              end),
              entry_idx_acc,
              [entry_idx_acc | option_items_acc]
            }
          end)

        {directory, entry_count, [items | option_items], [option_start_idx | option_start_ids]}
      end)

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
        undo: true
      )

    item_lists_ll =
      LinkedList.new(Enum.to_list(1..(entry_count + num_items)), undo: true)
      |> tap(fn ll ->
        item_lists
        |> Enum.zip((entry_count + 1)..(entry_count + num_items))
        |> Enum.each(fn {options, item_header} ->
          LinkedList.circuit(ll, [item_header | Enum.reverse(options)])
        end)
      end)

    item_top_map =
      LinkedList.iterate(item_header,
        initial_value: Map.new(),
        action: fn p, acc ->
          top = LinkedList.data(item_header, p)

          LinkedList.iterate(item_lists_ll,
            start: top,
            initial_value: acc,
            action: fn s, acc2 ->
              Map.put(acc2, s, p)
            end
          )
        end
      )

    ## NOTE: we won't have to cover/uncover options, hence there is no "undoing" it
    ## We also do not need extra entries for header pointers,
    ## as was the case for item lists.
    ##
    option_lists_ll =
      LinkedList.new(Enum.to_list(1..entry_count), undo: false)
      |> tap(fn ll ->
        Enum.each(
          option_lists,
          fn items -> LinkedList.circuit(ll, Enum.reverse(items)) end
        )
      end)

    %{
      item_header: item_header,
      option_start_ids: Enum.reverse(option_start_ids),
      item_names: item_names,
      top: item_top_map,
      item_lists: item_lists_ll,
      option_lists: option_lists_ll,
      solution: Array.new(length(options))
    }
  end

  defp search(
         k,
         %{
           item_header: item_header,
           top: top,
           solution: solution
         } = data,
         solver_opts,
         choose_column_fun \\ fn _step, data -> choose_column(data) end
       ) do
    ## Knuth:
    # If R[h] = h, print the current solution and return.
    ##
    if LinkedList.empty?(item_header) do
      solution(data, Keyword.get(solver_opts, :solution_handler))
    else
      ## Knuth:
      # Otherwise choose a column object c (see below).
      ##
      c = choose_column_fun.(k, data)
      ## Knuth:
      # Cover column c.
      ##
      num_removed_entries = cover(c, data)
      ## Knuth:
      # For each r ← D[c], D[D[c]], . . . , while r != c,
      ##
      iterate_column(
        c,
        nil,
        fn r, _acc ->
          ## Knuth:
          #   set O[k] ← r;
          ##
          Array.put(solution, k, r)
          ## Knuth:
          # for each j ← R[r], R[R[r]], . . . , while j != r,
          #  cover column j
          ##
          {num_covered_columns, num_removed_entries} =
            iterate_row(
              r,
              {0, 0},
              fn j, {columns_acc, entries_acc} = acc ->
                cond do
                  LinkedList.empty?(item_header) ->
                    {:halt, acc}

                  j != r ->
                    # Tricky; cover/2 expects header (not item) pointer,
                    # so we need to convert
                    {columns_acc + 1,
                     Map.get(top, j)
                     |> cover(data)
                     |> Kernel.+(entries_acc)}

                  true ->
                    acc
                end
              end,
              data
            )

          search(k + 1, data, solver_opts, choose_column_fun)
          ## Knuth:
          # for each j ← L[r], L[L[r]], . . . , while j != r,
          #  uncover column j.
          ##
          uncover(num_covered_columns, num_removed_entries, data)
        end,
        data
      )

      ## Knuth:
      # Uncover column c and return.
      ##
      uncover(1, num_removed_entries, data)
    end
  end

  defp choose_column(%{item_header: item_header} = _data) do
    LinkedList.head(item_header)
  end

  defp solution(data, solution_handler) do
    solution = data[:solution]

    Enum.reduce_while(1..Array.size(solution), [], fn idx, acc ->
      case Array.get(solution, idx) do
        nil ->
          {:halt, acc}

        option_entry ->
          {:cont,
           [
             Enum.find_index(data.option_start_ids, fn val ->
               val == option_entry
             end)
             | acc
           ]}
      end
    end)
    |> solution_handler.()
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
        } = data
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
      0,
      ## Knuth:
      # For each j ← R[i], R[R[i]] , . . . , while j != i,
      ##
      fn i, acc ->
        iterate_row(
          i,
          acc,
          fn j, acc2 ->
            ## Knuth:
            # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
            ##
            if i != j do
              LinkedList.delete_pointer(item_lists, j)
              acc2 + 1
            else
              acc2
            end
          end,
          data
        )

        ## Knuth:
        # and set S[C[j]]  ← S[C[j]]  − 1
        ## TODO: this is for tracking list sizes; important for branching
        ## , but we'll leave it out for now.
      end,
      data
    )
  end

  ## This is for debugging only.
  ## We won't need to pass item name/id, passing item pointer
  ## would be sufficient for the implementation
  def cover(item_name, data) do
    cover(column_pointer(item_name, data), data)
  end

  defp uncover(
         num_columns,
         num_entries,
         %{
           item_header: item_header,
           item_lists: item_lists
         } = _data
       )
       when is_integer(num_columns) and is_integer(num_entries) do
    restore(num_columns, item_header)
    restore(num_entries, item_lists)
  end

  defp restore(0, _linked_list) do
    :ok
  end

  defp restore(n, linked_list) do
    if LinkedList.restore(linked_list) do
      restore(n - 1, linked_list)
    else
      :ok
    end
  end

  ## `column pointer` is a pointer in `item_header` linked list.
  ## The element is points to is a 'top' of the column,
  ## which is a pointer in `item_lists` linked list
  defp iterate_column(
         column_pointer,
         initial_value,
         iterator_fun,
         %{item_header: item_header, item_lists: columns} = _data,
         forward? \\ true
       ) do
    column_top = LinkedList.data(item_header, column_pointer)

    LinkedList.iterate(columns,
      start:
        (forward? && LinkedList.next(columns, column_top)) || LinkedList.prev(columns, column_top),
      initial_value: initial_value,
      forward: forward?,
      action: fn column_element, acc ->
        if column_element != column_top do
          iterator_fun.(column_element, acc)
        else
          acc
        end
      end
    )
  end

  ## `row_pointer` is any pointer in the list of `option_lists` items.
  ## `option_lists` is a linked list partitioned by option sublists
  ## , each sublist represents an option.
  defp iterate_row(
         row_pointer,
         initial_value,
         iterator_fun,
         %{option_lists: rows} = _data,
         forward? \\ true
       ) do
    LinkedList.iterate(rows,
      start: row_pointer,
      initial_value: initial_value,
      forward: forward?,
      action: fn p, acc -> iterator_fun.(p, acc) end
    )
  end

  defp column_pointer(item_name, %{item_names: item_names} = _data) do
    length(item_names) -
      Enum.find_index(item_names, fn name -> name == item_name end)
  end
end
