defmodule InPlace.Stack do
  alias InPlace.Array

  def new(max_capacity) when is_integer(max_capacity) and max_capacity > 0 do
    Array.new(max_capacity + 1, 0)
  end

  def size(stack) do
    Array.get(stack, 1)
  end

  def peek(stack) do
    case size(stack) do
      0 -> nil
      t_idx -> Array.get(stack, t_idx + 1)
    end
  end

  def empty?(stack) do
    size(stack) == 0
  end

  def pop(stack) do
    peek(stack)
    |> tap(fn top -> is_nil(top) || :atomics.sub(stack, 1, 1) end)
  end

  def push(stack, value) when is_integer(value) do
    if size(stack) == Array.size(stack) - 1 do
       throw({:error, :stackoverflow})
    else
      new_size = :atomics.add_get(stack, 1, 1)
      Array.put(stack, new_size + 1, value)
    end
  end
end
