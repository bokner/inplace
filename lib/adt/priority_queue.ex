defmodule InPlace.PriorityQueue do
  alias InPlace.Heap

  @doc """
    Creates a priority queue.
    Currently backed by binary heap.
    Options:
    :mapper - the function that maps integer (heap) keys to the values in priority queue.
  """
  def new(capacity, opts) do
    opts = Keyword.merge(default_opts(), opts)
    kv_mapping = init_mapping()
    heap = Heap.new(capacity, comparator: fn key1, key2 -> compare_keys(kv_mapping, key1, key2) end)
    %{
      mapping: kv_mapping,
      heap: heap
    }
  end

  def insert(%{mapping: mapping, heap: heap} = _p_queue, value) do
    update_mapping(mapping, Heap.size(heap), value)
    Heap.insert(heap, value)
  end

  defp default_opts() do
    [
      mapper: fn key -> key end
    ]
  end

  defp init_mapping() do
    key = {__MODULE__, make_ref()}
    :persistent_term.put(key, Map.new())
    key
  end

  defp update_mapping(mapping, key, value) do
  end

  defp compare_keys(mapping, key1, key2) do
  end
end
