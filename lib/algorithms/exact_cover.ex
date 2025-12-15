defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm X (Exact cover via dancing links)
  Following the decription in
  The Art of Computer Programming, vol. 4B, by Donald Knuth.
  """
  alias InPlace.{LinkedList, Array}

  def test() do
    [
      [:c, :e, :f],
      [:a, :d, :g],
      [:b, :c, :f],
      [:a, :d],
      [:b, :g],
      [:d, :e, :g]
    ]
    |> init()
  end

  def init(options) do
    ## Options are sets that contain item names.
    ## Build the data structures (roughly as described by D. Knuth)
    {item_map, entry_count, option_lists} =
      Enum.reduce(options, {Map.new(), 0, []}, fn option,
                                                  {directory, entry_idx, option_items} = _acc ->
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

        {directory, entry_count, [items | option_items]}
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
        undo: true #nil
      )

    item_lists_ll =
      LinkedList.new(Enum.to_list(1..(entry_count + num_items)), undo: true) # nil)
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
      item_names: item_names,
      top: item_top_map,
      item_lists: item_lists_ll,
      option_lists: option_lists_ll,
      solution: Array.new(length(options))
    }
  end

  def search(
        k,
        %{
          item_header: item_header,
          top: top,
          solution: solution
        } = data,
        choose_column_fun \\ fn _step, data -> choose_column(data) end
      ) do
    IO.inspect("Search #{k} started")
    # If R[h] = h, print the current solution and return.
    if LinkedList.empty?(item_header) do
      solution(data)
    else
      # Otherwise choose a column object c (see below).
      c = choose_column_fun.(k, data)
      # Cover column c.
      num_removed_entries = cover(c, data)
      # For each r ← D[c], D[D[c]], . . . , while r != c,
      iterate_column(c, nil, fn r, _acc ->
            #   set O[k] ← r;
            IO.inspect("r = #{r}")
            Array.put(solution, k, r)
            IO.inspect("O[#{k}] <- #{r}")
            #for each j ← R[r], R[R[r]], . . . , while j != r,
            #  cover column j
            {num_covered_columns, num_removed_entries} =
              iterate_row(r, {0, 0}, fn j, {columns_acc, entries_acc} = acc ->
              if j != r do
              # Tricky; cover/2 expects header (not item) pointer,
              # so we need to convert
              IO.inspect("j = #{j}")
              {columns_acc + 1,
              Map.get(top, j)
              |> cover(data)
              |> Kernel.+(entries_acc)
              }
              else
                acc
              end
            end, data)
            search(k+1, data, choose_column_fun)
            # for each j ← L[r], L[L[r]], . . . , while j != r,
            #  uncover column j (see below).
            #r = Array.get(solution, k)

            # iterate_row(r, nil, fn j, _acc ->
            #   if j != r do
            #     uncover(Map.get(top, j), data)
            #   end
            # end, data, false)
            uncover(num_covered_columns, num_removed_entries, data)
          end,
        data
      )

      # Uncover column c and return.
      uncover(1, num_removed_entries, data)
      IO.inspect("Search #{k} completed")
    end
  end

  def choose_column(%{item_header: item_header} = _data) do
    LinkedList.head(item_header)
  end

  def choose_column_alphabetical(data) do
    LinkedList.iterate(data[:item_header],
      initial_value: [],
      action: fn p, acc -> [p | acc] end
    )
    |> Enum.sort_by(fn idx -> get_item_name(idx, data) end)
    |> hd
  end

  defp solution(data) do
    IO.inspect("solved")
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
          top: top,
          item_lists: item_lists
        } = data
      )
      when is_integer(column_pointer) and column_pointer > 0 do
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    IO.inspect("Covering #{get_item_name(column_pointer, data)}", label: :cover)
    LinkedList.delete_pointer(item_header, column_pointer)
    IO.inspect("Deleted column pointer #{column_pointer}")
    #IO.inspect("Iterating over #{item_options(column_pointer, data)}")
    #  For each i ← D[c], D[D[c]] , . . . , while i != c,
    iterate_column(
      column_pointer,
      0, ## count of removed entries
      # For each j ← R[i], R[R[i]] , . . . , while j != i,
      fn i, acc ->
        iterate_row(
          i,
          acc,
          fn j, acc2 ->
            # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
            if i != j do
              item_name = get_item_name(Map.get(top, j), data)

              IO.inspect(
                "Remove option #{j} from #{item_name}" #(#{item_options(j, data) |> Enum.join(",")})"
              )

              LinkedList.delete_pointer(item_lists, j)
              acc2 + 1
            else
              acc2
            end
          end,
          data
        )

        #       and set S[C[j]]  ← S[C[j]]  − 1
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

  def uncover(num_columns, num_entries,
        %{
          item_header: item_header,
          item_lists: item_lists
        } = _data
      )
    when is_integer(num_columns) and is_integer(num_entries) do
      restore(num_columns, item_header)
      restore(num_entries, item_lists)
    # For each i = U[c], U[U[c]] , . . . , while i != c,
    # for each j ← L[i], L[L[i]] , . . . , while j != i,
    # set S C[j]  ← S [j]  + 1,
    # and set U[D[j]]  ← j, D[U[j]]  ← j.
    # Set L[R[c]]  ← c and R[L[c]]  ← c.
  end

  # def uncover(
  #       column_pointer,
  #       %{
  #         item_header: item_header,
  #         top: top,
  #         item_lists: item_lists
  #       } = data
  #     )
  #     when is_integer(column_pointer) and column_pointer > 0 do
  #   # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
  #   column_name = get_item_name(column_pointer, data)
  #   IO.inspect("Uncovering #{column_name}", label: :cover)
  #   LinkedList.restore_pointer(item_header, column_pointer)
  #   IO.inspect("Header pointer restored")
  #   #  For each i ← D[c], D[D[c]] , . . . , while i != c,
  #   iterate_column(
  #     column_pointer,
  #     0, ## count of removed entries
  #     # For each j ← R[i], R[R[i]] , . . . , while j != i,
  #     fn i, acc ->
  #       iterate_row(
  #         i,
  #         acc,
  #         fn j, acc2 ->
  #           # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
  #           if i != j do
  #             item_name = get_item_name(Map.get(top, j), data)

  #             IO.inspect(
  #               "Restore option #{j} from #{item_name}" # (#{item_options(j, data) |> Enum.join(",")})"
  #             )

  #             LinkedList.restore_pointer(item_lists, j)
  #             acc2 + 1
  #           else
  #             acc2
  #           end
  #         end,
  #         data, false
  #       )

  #       #       and set S[C[j]]  ← S[C[j]]  − 1
  #       ## TODO: this is for tracking list sizes; important for branching
  #       ## , but we'll leave it out for now.
  #     end,
  #     data, false
  #   )
  # end



  def restore(0, _linked_list) do
    :ok
  end

  def restore(n, linked_list) do
    LinkedList.restore(linked_list)
    restore(n - 1, linked_list)
  end


  ## `column pointer` is a pointer in `item_header` linked list.
  ## The element is points to is a 'top' of the column,
  ## which is a pointer in `item_lists` linked list
  def iterate_column(
        column_pointer,
        initial_value,
        iterator_fun,
        %{item_header: item_header, item_lists: columns} = _data, forward? \\ true
      ) do
    column_top = LinkedList.data(item_header, column_pointer)

    LinkedList.iterate(columns,
      start: forward? && LinkedList.next(columns, column_top) || LinkedList.prev(columns, column_top),
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
  def iterate_row(row_pointer, initial_value, iterator_fun, %{option_lists: rows} = _data, forward? \\ true) do
    LinkedList.iterate(rows,
      start: row_pointer,
      initial_value: initial_value,
      forward: forward?,
      action: fn p, acc -> iterator_fun.(p, acc) end
    )
  end

  ## `entry` is a pointer to the member of `item_lists`
  def item_options(entry, %{item_lists: item_lists} = _data) when is_integer(entry) do
    LinkedList.iterate(item_lists,
      initial_value: [],
      start: entry,
      action: fn p, acc -> [p | acc] end
    )
  end

  def item_options(item_name, data) do
    item_options(map_size(data.top) + 1 - column_pointer(item_name, data), data)
  end



  def column_pointer(item_name, %{item_names: item_names} = _data) do
    length(item_names) -
      Enum.find_index(item_names, fn name -> name == item_name end)
  end

  def get_item_name(pointer, %{item_names: names} = _data) do
    Enum.at(names, length(names) - pointer)
  end
end
