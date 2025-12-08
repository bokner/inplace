defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm X (Exact cover via dancing links)
  Following the decription in
  The Art of Computer Programming, vol. 4B, by Donald Knuth.
  """
  alias InPlace.{LinkedList}

  def test() do
    [
      [:c, :e],
      [:a, :d, :g],
      [:b, :c, :f],
      [:a, :d, :f],
      [:b, :g],
      [:d, :e, :g]
    ]
  end

  def init(options) do
    ## Options are sets that contain item names.
    ## Build the data structures (roughly as described by D. Knuth)
    {item_map, entry_count, option_lists} =
      Enum.reduce(options, {Map.new(), 1, []}, fn option,
                                                  {directory, entry_idx, option_items} = _acc ->
        {directory, entry_count, items} =
          Enum.reduce(option, {directory, entry_idx, []}, fn item_name,
                                                             {dir_acc, entry_idx_acc,
                                                              option_items_acc} ->
            {
              Map.update(dir_acc, item_name, [entry_idx_acc], fn entries ->
                [entry_idx_acc | entries]
              end),
              entry_idx_acc + 1,
              [entry_idx_acc | option_items_acc]
            }
          end)

        {directory, entry_count, [items | option_items]}
      end)

    ## build item header, item and option lists
    entries = Enum.to_list(1..(entry_count - 1))
    {item_names, item_lists} = Enum.unzip(item_map)
    item_header = LinkedList.new(Enum.to_list(1..map_size(item_map)), undo: true)

    item_lists_ll =
      LinkedList.new(entries, undo: true)
      |> tap(fn ll ->
        Enum.each(item_lists, fn options ->
          LinkedList.circuit(ll, Enum.reverse(options))
        end)
      end)

    ## NOTE: we won't have to cover/uncover options, hence no "undoing" it
    option_lists_ll =
      LinkedList.new(entries, undo: false)
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

  def cover(item, %{
        item_header: item_header,
        item_lists: item_lists,
        option_lists: option_lists
      })
      when is_integer(item) and item > 0 do
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    LinkedList.delete_pointer(item_header, item)
    #   For each i ← D[c], D[D[c]] , . . . , while i != c,
    LinkedList.iterate(item_lists,
      start: item,
      action: fn i ->
        if i != item do
          #     for each j ← R[i], R[R[i]] , . . . , while j != i,
          LinkedList.iterate(option_lists,
            start: i,
            action: fn j ->
              #       set U[D[j]]  ← U[j], D[U[j]]  ← D[j],
              if i != j do
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
end
