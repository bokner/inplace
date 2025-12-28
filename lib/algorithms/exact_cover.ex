defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm DLX (Exact cover via dancing links).
  Based on https://arxiv.org/pdf/cs/0011047 by Donald Knuth.

  Note: there is a never version of this algorithm
  (The Art of Computer Programming, vol. 4B, by Donald Knuth).
  It differs mostly by using more advanced internal data structure.
  """
  alias InPlace.{LinkedList, Array, PriorityQueue}

  def solve(options, solver_opts \\ []) do
    data = init(options)
    solver_opts = Keyword.merge(default_solver_opts(), solver_opts)
    search(1, Map.put(data, :solver_opts, solver_opts))
  end

  defp default_solver_opts() do
    [
      solution_handler: fn options -> IO.inspect(options, label: :solution) end,
      choose_item_fun: fn _step, data -> min_options_item(data) end,
      stop_on: fn data -> num_solutions(data) == 1 end
    ]
  end

  def init(options) do
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
        restore: true
      )

    item_lists_ll =
      LinkedList.new(Enum.to_list(1..(entry_count + num_items)), restore: true)
      |> tap(fn ll ->
        item_lists
        |> Enum.zip((entry_count + 1)..(entry_count + num_items))
        |> Enum.each(fn {options, item_header} ->
          ## create sublists of options per item
          LinkedList.circuit(ll, [item_header | options])
        end)
      end)


    item_top_map =
      LinkedList.iterate(
        item_header,
        fn p, acc ->
          top = LinkedList.data(item_header, p)

          LinkedList.iterate(
            item_lists_ll,
            fn s, acc2 ->
              Map.put(acc2, s, p)
            end,
            start: top,
            initial_value: acc
          )
        end,
        initial_value: Map.new()
      )

    ## NOTE: we won't have to cover/uncover options, hence there is no "undoing" it
    ## We also do not need extra entries for header pointers,
    ## as was the case for item lists.
    ##
    option_lists_ll =
      LinkedList.new(Enum.to_list(1..entry_count), restore: false)
      |> tap(fn ll ->
        Enum.each(
          option_lists,
          fn items -> LinkedList.circuit(ll, Enum.reverse(items)) end
        )
      end)

    top = map_to_array(item_top_map)
    %{
      item_header: item_header,
      option_start_ids: Enum.reverse(option_start_ids),
      item_names: item_names,
      top: top,
      item_lists: item_lists_ll,
      option_lists: option_lists_ll,
      item_option_counts: init_item_option_counts(item_lists),
      num_solutions: Array.new(1, 0),
      solution: Array.new(length(options)) ## buffer for building current solution
    }
  end

  defp search(
         k,
         %{
           item_header: item_header,
           solution: solution,
           solver_opts: solver_opts
         } = data
       ) do

    stop_condition = solver_opts[:stop_on]
    if stop_condition && stop_condition.(data) do
      :complete
    else
      choose_item_fun = solver_opts[:choose_item_fun]
    ## Knuth:
    # If R[h] = h, print the current solution and return.
    ##
    if LinkedList.empty?(item_header) do
      solution(data, Keyword.get(solver_opts, :solution_handler))
    else
      ## Knuth:
      # Otherwise choose a column object c (see below).
      ##
      c = choose_item_fun.(k, data)
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
                  #LinkedList.empty?(item_header) ->
                  #  {:halt, acc}

                  j != r ->
                    # Tricky; cover/2 expects header (not item) pointer,
                    # so we need to convert
                    {columns_acc + 1,
                     get_top(data, j)
                     |> cover(data)
                     |> Kernel.+(entries_acc)
                    }

                  true ->
                    acc
                end
              end,
              data
            )

          search(k + 1, data)
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
end

  def first_item(%{item_header: item_header} = _data) do
    LinkedList.head(item_header)
  end

  def random_item(%{item_header: item_header} = _data) do
    header_size = LinkedList.size(item_header)
    random_position = Enum.random(1..header_size)
    LinkedList.iterate(item_header, fn p, acc ->
      if acc == random_position do
        {:halt, p}
      else
        {:cont, acc + 1}
      end
    end, initial_value: 1)
  end

  def min_options_item(data) do
    min_options_item(data, :heap)
  end

  def min_options_item(%{item_header: item_header} = data, :heap) do
    queue = data.item_option_counts.queue
      case PriorityQueue.extract_min(queue) do
        {key, _priority} ->
    if LinkedList.pointer_deleted?(item_header, key) do
       min_options_item(data)
    else
      key
    end
    nil -> min_options_item(data, :list)
  end
  end


  def min_options_item(%{item_header: item_header} = data, :list) do
    head = LinkedList.head(item_header)
    head_count = get_item_options_count(data, head)
    LinkedList.iterate(item_header, fn p, {_min_p, min_acc} ->
      ## find min of option counts iterating over column (item) pointers
      case get_item_options_count(data, p) do
        count when count <= 1 -> {:halt, {p, 1}} # it's a minimal count
        count  ->
          {p, min(count, min_acc)}
        end
    end, initial_value: {head, head_count})
    |> elem(0)

  end

  defp get_item_options_count(data, item_pointer) do
    Array.get(data.item_option_counts.counts, item_pointer)
  end

  defp solution(data, solution_handler) do
    solution = data[:solution]

    Array.update(data.num_solutions, 1, fn n -> n + 1 end)

    Enum.reduce_while(1..Array.size(solution), [], fn idx, acc ->
      case Array.get(solution, idx) do
        nil ->
          {:halt, acc}

        option_entry ->
          {:cont,
           [
             LinkedList.iterate(data.option_lists,
              fn p, acc ->
                case Enum.find_index(data.option_start_ids, fn val ->
                  val == p
                end) do
                  nil -> {:cont, acc}
                  option_number -> {:halt, option_number}
                end
                end,
             start: option_entry,
             initial_value: false
             )
             | acc
           ]}
      end
    end)
    |> solution_handler.()
  end

  def num_solutions(data) do
    Array.get(data.num_solutions, 1)
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
              # and set S[C[j]]  ← S[C[j]]  − 1
              decrease_option_count(data, j)
              acc2 + 1
            else
              acc2
            end
          end,
          data
        )

      end,
      data
    )
  end

  ## This variant of cover/2 is for debugging only.
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
         } = data
       )
       when is_integer(num_columns) and is_integer(num_entries) do
    restore(num_columns, item_header)
    restore(num_entries, item_lists, fn p ->
      increase_option_count(data, p)
    end)
  end

  defp restore(num_to_restore, linked_list, post_process_fun \\ nil)

  defp restore(0, _linked_list, _post_process_fun) do
    :ok
  end

  defp restore(n, linked_list, post_process_fun) do
    case LinkedList.restore(linked_list) do
      false -> :ok
      {:restored, p} ->
        post_process_fun && post_process_fun.(p)
        restore(n - 1, linked_list, post_process_fun)
    end
  end

  defp decrease_option_count(data, item_option_pointer) do
    change_option_count(data, item_option_pointer, -1)
  end

  def increase_option_count(data, item_option_pointer) do
    change_option_count(data, item_option_pointer, 1)
  end

  # Updates item option count
  defp change_option_count(%{item_option_counts: counts_rec} = data, item_option_pointer, delta) do
    top = get_top(data, item_option_pointer)
    if LinkedList.pointer_deleted?(data.item_header, top) do
      :ignore
    else
    %{counts: counts, queue: queue} = counts_rec
    Array.update(counts, top,
      fn val ->
        (val + delta)
        |> tap(fn priority ->
           PriorityQueue.insert(queue, top, priority) end)
    end)
  end
  end

  defp map_to_array(map) do
    array = Array.new(map_size(map))
    Enum.each(map, fn {key, value} -> Array.put(array, key, value) end)
    array
  end

  defp init_item_option_counts(item_lists) do
    num_items = length(item_lists)
    arr = Array.new(num_items)
    copy = Array.new(num_items)
    p_queue = PriorityQueue.new(num_items, keep_lesser: false)
    item_lists
    |> Enum.with_index(1)
    |> Enum.each(fn {options, item_idx} ->
      num_options = length(options)
      Array.put(arr, item_idx, num_options)
      Array.put(copy, item_idx, num_options)

      PriorityQueue.insert(p_queue, item_idx, num_options)
          end)
    %{counts: arr, copy: copy, queue: p_queue}
  end

  defp get_top(%{top: top} = _data, el) do
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
         initial_value,
         iterator_fun,
         %{item_header: item_header, item_lists: columns} = _data,
         forward? \\ true
       ) do
    column_top = LinkedList.data(item_header, column_pointer)

    LinkedList.iterate(
      columns,
      fn column_element, acc ->
        if column_element != column_top do
          iterator_fun.(column_element, acc)
        else
          acc
        end
      end,
      start:
        (forward? && LinkedList.next(columns, column_top)) || LinkedList.prev(columns, column_top),
      initial_value: initial_value,
      forward: forward?
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
    LinkedList.iterate(
      rows,
      fn p, acc -> iterator_fun.(p, acc) end,
      start: row_pointer,
      initial_value: initial_value,
      forward: forward?
    )
  end

  defp column_pointer(item_name, %{item_names: item_names} = _data) do
    length(item_names) -
      Enum.find_index(item_names, fn name -> name == item_name end)
  end
end
