defmodule InPlace.HeapSort do
  alias InPlace.Heap

  def sort(list, order \\ :asc) do
    size = length(list)
    sign = (order == :desc && 1 || -1)
    heap = Heap.new(size)
    Enum.each(list, fn el -> Heap.insert(heap, sign * el) end)
    extract_all(heap, size, sign)
  end

  defp extract_all(heap, size, sign) do
    extract_next(heap, size, [], sign)
  end

  defp extract_next(_heap, 0, acc, _sign) do
    acc
  end

  defp extract_next(heap, size, acc, sign) do
    extract_next(heap, size - 1, [sign * Heap.extract_min(heap)| acc], sign)
  end
end
