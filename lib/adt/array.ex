defmodule BitGraph.Array do
  def new(size) do
    :atomics.new(size, signed: :true)
  end

  ## Get element by (1-based) index
  def get(array, idx) do
    :atomics.get(array, idx)
  end

  def put(array, idx, value) when is_integer(value) do
    :atomics.put(array, idx, value)
  end

  def to_list(array) do
    Enum.map(1..size(array), fn idx -> :atomics.get(array, idx) end)
  end

  def reduce(array, initial_value, reducer \\ fn el, acc -> [el | acc] end) when is_function(reducer) do
    Enum.reduce(1..size(array), initial_value, fn idx, acc ->
      reducer.(:atomics.get(array, idx), acc)
    end)
  end

  def size(array) do
    :atomics.info(array)[:size]
  end
end
