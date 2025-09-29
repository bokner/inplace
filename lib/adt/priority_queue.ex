defmodule InPlace.PriorityQueue do
  alias InPlace.Heap

  @doc """
    Creates a priority queue.
    Currently backed by binary heap.
    The priorities are {term(), number()} tuples,
    where the 2nd element defines the priority on the 1st element.
    Options:
    :comparator - the boolean function that compares 2 priorities (default is Kernel.<=/2)
  """
  def new(capacity, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)
    kv_mapping = init_mapping()
    compare_fun = Keyword.get(opts, :comparator)
    getter_fun = fn key -> get_mapping(kv_mapping, key) end
    heap = Heap.new(capacity,
      getter: getter_fun,
      comparator: fn key1, key2 -> compare_priorities(getter_fun, key1, key2, compare_fun) end)

    %{
      mapping: kv_mapping,
      heap: heap
    }
  end

  def size(%{heap: heap} = _p_queue) do
    Heap.size(heap)
  end

  def empty?(%{heap: heap} = _p_queue) do
    Heap.empty?(heap)
  end

  def valid?(%{heap: heap} = _p_queue) do
    Heap.valid?(heap)
  end

  def insert(%{mapping: mapping, heap: heap} = _p_queue, key, priority) when is_number(priority) do
    key_index = Heap.size(heap) + 1
    update_mapping(mapping, key_index, {key, priority})
    Heap.insert(heap, key_index)
  end

  def get_min(%{heap: heap} = _p_queue) do
    Heap.get_min(heap)
  end

  def extract_min(%{mapping: mapping, heap: heap} = _p_queue) do
    #extract_mapping(mapping, 1)
    min_key = Heap.get_key(heap, 1)
    Heap.extract_min(heap)
    |> tap(fn _ -> extract_mapping(mapping, min_key) end)
  end


  defp default_opts() do
    Heap.default_opts()
  end

  defp init_mapping() do
    {__MODULE__, make_ref()}
  end

  defp mapping_key(mapping, key_index) do
    {mapping, key_index}
  end

  defp update_mapping(mapping, key_index, value) do
    Process.put(mapping_key(mapping, key_index), value)
  end

  def get_mapping(mapping, key_index) do
    Process.get(mapping_key(mapping, key_index))
  end

  defp extract_mapping(mapping, key_index) do
    Process.delete(mapping_key(mapping, key_index))
  end


  defp compare_priorities(getter_fun, pkey1, pkey2, compare_fun) do
    {_key1, priority1} = getter_fun.(pkey1)
    {_key2, priority2} = getter_fun.(pkey2)

    compare_fun.(priority1, priority2)
  end
end
