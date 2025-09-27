defmodule InPlace.Array do
  import Bitwise
  @null (1 <<< 63) - 1

  def new(size, initial_value \\ @null) do
    :atomics.new(size, signed: true)
    |> tap(fn ref ->
      initial_value != 0 &&
        Enum.each(1..size, fn idx -> put(ref, idx, initial_value) end)
    end)
  end

  ## Get element by (1-based) index
  def get(array, idx) when is_integer(idx) do
    case :atomics.get(array, idx) do
      @null -> nil
      val -> val
    end
  end

  def put(array, idx, value) when is_integer(idx) and is_integer(value) do
    :atomics.put(array, idx, value)
  end

  def delete(array, idx) do
    put(array, idx, @null)
  end

  def update(array, idx, update_fun) do
    update_loop(array, idx, get(array, idx), update_fun)
  end

  def update_loop(array, idx, current, update_fun) do
    case :atomics.compare_exchange(array, idx, current, update_fun.(current)) do
      :ok ->
        :ok

      altered ->
        update_loop(array, idx, altered, update_fun)
    end
  end

  def swap(array, idx1, idx2) do
    val1 = get(array, idx1)
    val2 = get(array, idx2)
    put(array, idx1, val2)
    put(array, idx2, val1)
  end

  def to_list(array) do
    Enum.map(1..size(array), fn idx -> :atomics.get(array, idx) end)
  end

  def reduce(array, initial_value, reducer \\ fn el, acc -> [el | acc] end)
      when is_function(reducer) do
    Enum.reduce(1..size(array), initial_value, fn idx, acc ->
      reducer.(:atomics.get(array, idx), acc)
    end)
  end

  def size(array) do
    :atomics.info(array)[:size]
  end
end
