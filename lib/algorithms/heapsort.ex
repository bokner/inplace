defmodule InPlace.HeapSort do
  alias InPlace.Heap

  def sort(list, order \\ :asc) do
    size = length(list)
    heap = Heap.new(size)
    Enum.each(list, fn el -> Heap.insert(heap, el) end)
    extract_all(heap, size)
    |> then(fn sorted ->
      if order == :asc do
        Enum.reverse(sorted)
      else
        sorted
      end
    end)
  end

  defp extract_all(heap, size) do
    extract_next(heap, size, [])
  end

  defp extract_next(_heap, 0, acc) do
    acc
  end

  defp extract_next(heap, size, acc) do
    extract_next(heap, size - 1, [Heap.extract_min(heap)| acc])
  end
end
