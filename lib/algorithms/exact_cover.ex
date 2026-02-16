defmodule InPlace.ExactCover do
  @moduledoc """
  Implementation of Exact Cover.
  Based on https://arxiv.org/pdf/cs/0011047 by Donald Knuth.
  Modified to use "dancing cells" instead of "dancing links"
  """
  alias InPlace.{Array, SparseSet}

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
    {_, item_map, entry_count, option_membership, option_ranges} =
      Enum.reduce(options,
        {1, Map.new(), 0, [], Map.new()},
          fn option,
              {option_idx, directory, entry_idx, option_membership, option_ranges} = _acc ->
        {directory, entry_count, membership} =
          Enum.reduce(option, {directory, entry_idx, option_membership},
            fn item_name,
                {dir_acc, entry_idx_acc, membership_acc} ->
            ## 1-based index, for convenience
            entry_idx_acc = entry_idx_acc + 1

            {
              Map.update(dir_acc, item_name, [entry_idx_acc], fn entries ->
                [entry_idx_acc | entries]
              end),
              entry_idx_acc,
              [option_idx | membership_acc]
            }
          end)

        {option_idx + 1, directory, entry_count, membership, Map.put(option_ranges, option_idx, {entry_idx+1, entry_count})}
      end)

    num_items = map_size(item_map)
    num_options = length(options)
    ## build item header, item and option lists
    {item_names, item_lists} = Enum.unzip(item_map)

    item_header =
      SparseSet.new(num_items)

    top = Array.new(entry_count, 0)
    option_counts = Array.new(num_items, 0)

    Enum.reduce(item_lists, 1, fn options, item_idx ->
      Enum.each(options, fn o -> Array.put(top, o, item_idx) end)
      num_options = length(options)
      Array.put(option_counts, item_idx, num_options)
      item_idx + 1
    end)

    ## sparse-set for item lists
    {_, item_options_map} = Enum.reduce(item_lists, {1, Map.new()}, fn options, {idx, acc} ->
      {idx + 1, Map.put(acc, idx, options)}
    end)

    item_lists_ss = SparseSet.new(entry_count)

    %{
      num_items: num_items,
      num_options: num_options,
      item_header: item_header, ## Sparse set for tracking covered items
      option_member_ids: init_option_member_ids(option_membership),
      option_ranges: option_ranges, ## %{option_id => {first_entry_id, last_entry_id}
      item_names: item_names,
      top: top, ## top[i] points to the element of item header for i-th entry
      item_lists: item_lists_ss, ## Sparse set for entries (contains entry ids)
      item_options: item_options_map, ## %{item_id => options}
      item_option_counts: %{
        counts: option_counts ## Count of active (uncovered) options per item
      },
      num_solutions: Array.new(1, 0),
      ## buffer for building current solution
      solution: Array.new(num_options, 0)
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
      if SparseSet.empty?(item_header) do
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
              cover_option_columns(r, state)
              search(k + 1, state)
              ## Knuth:
              # for each j ← L[r], L[L[r]], . . . , while j != r,
              #  uncover column j.
              ##
              uncover_option_columns(r, state)
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
        if j != option_pointer do
            ## Note: option pointer belongs to already covered item
            ## , so we can skip on it
            # Note2: cover/2 expects header (not item) pointer,
            # so we need to convert
            get_top(state, j)
            |> cover(state)
        end
      end,
      state
    )
  end

  defp uncover_option_columns(option_pointer, state) do
    iterate_row(
      option_pointer,
      fn j ->
        if  j != option_pointer do
            get_top(state, j)
            |> uncover(state)
        end
      end,
      state,
      false
    )
  end


  def min_options_item(%{item_header: item_header} = state) do
      ## Note: we will go through all uncovered items
      ## and find the item with the smallest number of 'covered' options.
      ## We will also be updating global 'minimum' with the second smallest item,
      ## as the "minimum" item will be covered, so won't be in the item set.
      ##
      SparseSet.reduce(
        item_header, {nil, nil},
        fn p, {_min_p, min_acc} = acc ->
          ## find min of option counts iterating over column (item) pointers
          case get_item_options_count(state, p) do
            0 -> {:halt, nil}
            1 ->
              {:halt, {p, 1}}
            count ->
              if count >= min_acc do
                acc
              else
                {p, count}
              end
          end
        end
      )
      |> then(fn
          nil -> nil
          {min_item, _min_value} ->
            min_item
      end)
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

    Enum.reduce_while(1..state.num_options, [], fn idx, acc ->
      case Array.get(solution, idx) do
        0 ->
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
          item_lists: item_lists,
        } = state
      )
      when is_integer(column_pointer) and column_pointer > 0 do
    ## Knuth:
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    ##
    if !covered?(column_pointer, state) do
      SparseSet.delete(item_header, column_pointer)
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
              SparseSet.delete(item_lists, j)
              # and set S[C[j]]  ← S[C[j]]  − 1
              decrease_option_count(state, j)
            end,
            state
          )
        end,
        state
      )
    end
  end

  defp covered?(column_pointer, %{item_header: item_header} = _state) do
    covered?(column_pointer, item_header)
  end

  defp covered?(column_pointer, item_header) do
    !SparseSet.member?(item_header, column_pointer)
  end

  def uncover(
        column_pointer,
        %{
          item_header: item_header,
          item_lists: item_lists,
        } = state
      )
      when is_integer(column_pointer) and column_pointer > 0 do
    ## Knuth:
    # Set L[R[c]]  ← L[c] and R[L[c]]  ← R[c].
    ##

    if SparseSet.undelete(item_header) do
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
            #SparseSet.undelete(item_lists)
            # and set S[C[j]]  ← S[C[j]]  − 1
            increase_option_count(state, j)
          end,
          state,
          false
        )
        |> tap(fn num_options -> SparseSet.undelete(item_lists, num_options) end)
      end,
      state
    )
    end
  end

  defp decrease_option_count(state, item_option_pointer) do
    top = get_top(state, item_option_pointer)

    update_option_count(state, top, fn val ->
      val - 1

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


  defp get_top(%{top: top} = _state, el) do
    get_top(top, el)
  end

  defp get_top(top, el) do
    Array.get(top, el)
  end

  ## `column pointer` is a pointer into `item_header` list.
  defp iterate_column(
         column_pointer,
         iterator_fun,
         %{item_lists: item_lists,
         item_options: item_options} = _state
       ) do

    columns_ss = Map.get(item_options, column_pointer)

    Enum.each(columns_ss, fn el ->
      if SparseSet.member?(item_lists, el), do: iterator_fun.(el)
    end)
  end

  ## `row_entry` is any option value that belongs to the item.
  ## We get the full option given this entry,
  ## then iterate over the option elements.
  defp iterate_row(
         row_pointer,
         iterator_fun,
         %{option_ranges: ranges} = state,
         forward? \\ true
       ) do
    row_id = get_option_id(state, row_pointer)
    {first, last} = Map.get(ranges, row_id)
    range = if forward? do
      first..last
    else
      last..first//-1
    end

    Enum.reduce(range, 0, fn p, acc ->
      if p != row_pointer do
       iterator_fun.(p)
       acc + 1
      else
        acc
      end
    end)
    ## Note: the result is only used for undeletion of multiple options;
    ## otherwise, the side effect of iterator_fun call would be all we need
    ##
  end

end
