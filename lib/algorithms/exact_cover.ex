defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm X (Exact cover via dancing links)
  Following the decription in
  The Art of Computer Programming, vol. 4B, by Donald Knuth.
  """
  alias InPlace.{LinkedList}

  def test() do
    [
      [:c, :e, :f],
      [:a, :d, :g],
      [:b, :c, :f],
      [:a, :d],
      [:b, :g],
      [:d, :e, :g]
    ]
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
            entry_idx_acc = entry_idx_acc + 1 ## 1-based index, for convenience
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
    item_header = LinkedList.new(Enum.map(1..num_items, fn header_idx ->
      ## Header pointers.
      ## They will be used as the 'heads' of correspondent item lists.
      ## For the test example:
      ## `:c` item will be in the header with pointer 1 and content 17
      ## (as there are 16 entries total across all option lists)
      ## Then the item list that corresponds to :c, will form
      ## a (17, 1, 8) circuit.
      header_idx + entry_count
    end), undo: true)

    item_lists_ll =
      LinkedList.new(Enum.to_list(1..(entry_count + num_items)), undo: true)
      |> tap(fn ll ->
        item_lists
        |> Enum.zip(entry_count+1..entry_count + num_items)
        |> Enum.each(fn {options, item_header} ->
          LinkedList.circuit(ll, [item_header | Enum.reverse(options)])
        end)
      end)

    ## NOTE: we won't have to cover/uncover options, hence no "undoing" it
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
      item_lists: item_lists_ll,
      option_lists: option_lists_ll
    }
  end

  def search(step, %{item_header: item_header} = data) do
    if LinkedList.empty?(item_header) do
      solution(data)
    else
      c = choose_item(data)
      cover(c, data)

    end
  end

  def choose_item(%{item_header: item_header} = data) do
    LinkedList.head(item_header)
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
  def cover(item_pointer, %{
        item_header: item_header,
        item_lists: item_lists,
        option_lists: option_lists
      })
      when is_integer(item_pointer) and item_pointer > 0 do
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    LinkedList.delete_pointer(item_header, item_pointer)
    #  For each i ← D[c], D[D[c]] , . . . , while i != c,
    item_list_head = LinkedList.data(item_header, item_pointer)
    LinkedList.iterate(item_lists,
      start: item_list_head,
      action: fn i ->
        if i != item_list_head do
          # For each j ← R[i], R[R[i]] , . . . , while j != i,
          LinkedList.iterate(option_lists,
            start: i,
            action: fn j ->
              # set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
              if i != j do
                IO.inspect("Remove option #{j} from #{item_options(j, item_lists) |> Enum.join(",")}")
                LinkedList.delete_pointer(item_lists, j)
              end
            end
          )
          #       and set S[C[j]]  ← S[C[j]]  − 1
          ## TODO: this is for tracking list sizes; important for branching
          ## , but we'll leave it out for now.
        end
      end
    )
  end

  ## This is for debugging only.
  ## We won't need to pass item name/id, passing item pointer
  ## would be sufficient for the implementation
  def cover(item_name, %{item_names: item_names} = data) do
    cover(item_pointer(item_name, item_names), data)
  end

  def item_options(member, item_lists) do
    LinkedList.iterate(item_lists,
      initial_value: [],
      start: member, action: fn p, acc -> [p | acc] end)
  end

  def item_pointer(item_name, item_names) do
    length(item_names) - Enum.find_index(item_names, fn name -> name == item_name end)
  end
end
