defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Algorithm X (Exact cover via dancing links)
  Following the decription in
  The Art of Computer Programming, vol. 4B, by Donald Knuth.
  """
  alias InPlace.{LinkedList, Array}

  def init(options) do
    ## Options are sets that contain item names.
    ## Build:
    ## - `directory` : (map) `item => index`
    ## - `header` : circular doubly linked list of item indices
    ## - `item_options` : circular doubly linked lists of options, one per item ("vertical lists").
    ## - `option_items` : circular doubly linked lists of items, one per option ("horizontal lists").

    ## Step 1: create directory and option_items
    {item_directory, option_items} =
      Enum.reduce(options, {Map.new(), []}, fn option, {dir_acc, option_items_acc} ->
        item_list = LinkedList.new(length(option), mode: :doubly_linked, undo: true, circular: true)
        dir_acc = Enum.reduce(option, dir_acc, fn name, dir_acc2 ->
          {item_idx, dir_acc2} = case Map.get(dir_acc2, name) do
            nil ->
              new_idx = map_size(dir_acc2) + 1
              {new_idx, Map.put(dir_acc2, name, new_idx)}
            item_idx ->
              {item_idx, dir_acc2}
            end
          ## Add to item list
          LinkedList.add_last(item_list, item_idx)
          dir_acc2
        end)
        {dir_acc, [item_list | option_items_acc]}
      end)

    ## Make "indexed" options follow in the same order as original options
    option_items = Enum.reverse(option_items)

    ## Step 2: create "item header" list
    ##
    item_header = LinkedList.new(map_size(item_directory), mode: :doubly_linked, undo: true, circular: true)
    Enum.each(1..map_size(item_directory), fn idx -> LinkedList.add_last(item_header, idx) end)

    ## Step 3: create lists of options, one per item
    item_options =
    option_items
    |> Enum.with_index(1)
    |> Enum.reduce(Map.new(), fn {option_ll, option_idx}, acc ->
      ## Collect options for each item
      Enum.reduce(LinkedList.to_list(option_ll), acc, fn item, acc2 ->
        Map.update(acc2, item, [option_idx], fn m -> [option_idx | m] end)
      end)
      end)
      |> Map.new(fn {item_idx, options} ->
        {item_idx,
          LinkedList.new(length(options), mode: :doubly_linked, undo: true, circular: true)
          |> tap(fn ll -> Enum.each(options, fn opt_idx -> LinkedList.add_last(ll, opt_idx) end) end)
        }
      end)


    %{
      directory: item_directory,
      header: item_header,
      item_columns: item_options,
      option_rows: option_items |> Enum.with_index(1) |> Map.new(fn {option, idx} -> {idx, option} end)
    }
  end

  ## Cover item `i`.
  ## We delete all of the options
  ## that involve `i`, from the list of currently active options,
  ## and we also delete `i`
  ## from the list of items that need to be covered.
  ##
  def cover(i, %{header: header, item_columns: item_columns, option_rows: option_rows} = _data) do
    ## Get an item column i
    item_column = Map.get(item_columns, i)
    
  end

  def uncover(i, data) do
  end

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
end
