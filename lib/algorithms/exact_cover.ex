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
          item_lists: item_lists,
          solution: solution
        } = data,
        choose_column_fun \\ fn _step, data -> choose_column(data) end
      ) do
    IO.inspect("Search #{k}")
    # If R[h] = h, print the current solution and return.
    if LinkedList.empty?(item_header) do
      solution(data)
    else
      # Otherwise choose a column object c (see below).
      c = choose_column_fun.(k, data)
      # Cover column c.
      updated_columns = cover(c, data)
      ## ...and all columns that have elements removed
      ## by covering column `c`
      Enum.each(updated_columns, fn item -> cover(item, data) end)

      # For each r ← D[c], D[D[c]], . . . , while r != c,
      top = LinkedList.data(item_header, c)

      LinkedList.iterate(item_lists,
        start: LinkedList.next(item_lists, top),
        action: fn r ->
          if r == top do
            :halt
          else
            #   set O[k] ← r;
            Array.put(solution, k, r)
          end
        end
      )

      # Uncover column c (see below) and return.

      # search(step, data)
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

  ## `item_pointer` is a pointer to
  ## an entry in "item header" list.
  ## This entry, in turn, contains the pointer to
  ## a head of a sublist in item_lists,
  ## from which we will handle (reduce) the options
  ## associated with the item.
  ##
  def cover(
        item_pointer,
        %{
          item_header: item_header,
          top: top,
          item_lists: item_lists
        } = data
      )
      when is_integer(item_pointer) and item_pointer > 0 do
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    IO.inspect("Covering #{get_item_name(item_pointer, data)}", label: :cover)
    LinkedList.delete_pointer(item_header, item_pointer)
    #  For each i ← D[c], D[D[c]] , . . . , while i != c,
    iterate_column(
      item_pointer,
      # For each j ← R[i], R[R[i]] , . . . , while j != i,
      fn i ->
        iterate_row(
          i,
          fn j ->
            # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
            if i != j do
              item_name = get_item_name(Map.get(top, j), data)

              IO.inspect(
                "Remove option #{j} from #{item_name} (#{item_options(j, item_lists) |> Enum.join(",")})"
              )

              LinkedList.delete_pointer(item_lists, j)
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
  def cover(item_name, %{item_names: item_names} = data) do
    cover(item_pointer(item_name, item_names), data)
  end

  ## `column pointer` is a pointer in `item_header` linked list.
  ## The element is points to is a 'top' of the column,
  ## which is a pointer in `item_lists` linked list
  def iterate_column(
        column_pointer,
        iterator_fun,
        %{item_header: item_header, item_lists: columns} = _data
      ) do
    column_top = LinkedList.data(item_header, column_pointer)

    LinkedList.iterate(columns,
      start: LinkedList.next(columns, column_top),
      action: fn column_element ->
        column_element != column_top && iterator_fun.(column_element)
      end
    )
  end

  ## `row_pointer` is any pointer in the list of `option_lists` items.
  ## `option_lists` is a linked list partitioned by option sublists
  ## , each sublist represents an option.
  def iterate_row(row_pointer, iterator_fun, %{option_lists: rows} = _data) do
    LinkedList.iterate(rows,
      start: row_pointer,
      action: fn p -> iterator_fun.(p) end
    )
  end

  def item_options(member, item_lists) do
    LinkedList.iterate(item_lists,
      initial_value: [],
      start: member,
      action: fn p, acc -> [p | acc] end
    )
  end

  def item_pointer(item_name, item_names) do
    length(item_names) -
      Enum.find_index(item_names, fn name -> name == item_name end)
  end

  def get_item_name(pointer, %{item_names: names} = _data) do
    Enum.at(names, length(names) - pointer)
  end
end
