defmodule InPlace.Utils.BitVector do
  @moduledoc """
  Low-level operations on :atomics
  """
  import Bitwise
def new(size) do
    words = div(size + 63, 64)
    ref = :atomics.new(words, signed: false)
    {:bit_vector, ref}
end



def get({:bit_vector, ref}, idx) do
    word_idx = div(idx, 64) + 1
    mask = bsl(1, rem(idx, 64))
    case band(mask, :atomics.get(ref, word_idx)) do
        0 -> 0
        ^mask -> 1
    end
  end

def set({:bit_vector, ref}, idx) do
    mask = bsl(1, rem(idx, 64))
    update(ref, idx, fn word -> bor(word, mask) end)
end

def clear({:bit_vector, ref}, idx) do
    mask = bnot(bsl(1, rem(idx, 64)))
    update(ref, idx, fn word -> band(word, mask) end)
end

def flip({:bit_vector, ref}, idx) do
    mask = bsl(1, rem(idx, 64))
    update(ref, idx, fn word -> bxor(word, mask) end)
end

def update(ref, idx, update_fun) do
    word_idx = div(idx, 64) + 1
    update_loop(ref, word_idx, update_fun, :atomics.get(ref, word_idx))
end

defp update_loop(ref, word_idx, update_fun, current_value) do
  case :atomics.compare_exchange(ref, word_idx, current_value, update_fun.(current_value)) do
       :ok ->
          :ok
       was ->
          update_loop(ref, word_idx, update_fun, was)
       end
      end

end
