defmodule InPlace.PriorityQueue do
  alias InPlace.Heap

  @doc """
    Creates a priority queue.
    Currently backed by binary heap.
    The priorities are {term(), number()} tuples,
    where the 2nd element defines the priority on the 1st element.
    Options:
    :comparator - the boolean function that compares 2 priorities (default is Kernel.</2)
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
      opts: opts,
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

  def insert(p_queue, {key, priority}) do
    insert(p_queue, key, priority)
  end

  def insert(%{heap: %{getter: getter_fun} = _heap, opts: opts} = p_queue, key, priority) when is_integer(key) and is_number(priority) do
    current_priority = get_priority(getter_fun, key)
        if !current_priority || !Keyword.get(opts, :comparator).(current_priority, priority) do
          ## We insert if no key yet, or if the new priority for the same key is
          ## 'lesser' than the current
          insert_new(p_queue, key, priority)
        else
          :noop
        end
  end

  defp insert_new(%{mapping: mapping, heap: heap} = _p_queue, key, priority) do
      update_mapping(mapping, key, {key, priority})
      Heap.insert(heap, key)
  end

  def get_min(%{heap: heap} = _p_queue) do
    Heap.get_min(heap)
  end

  def extract_min(%{mapping: mapping, heap: heap} = p_queue) do
    if !empty?(p_queue) do
    min_key = Heap.get_key(heap, 1)
    Heap.extract_min(heap)

    if get_mapping(mapping, min_key) do
      extract_mapping(mapping, min_key)
    else
      ## there is no mapping; it must be a duplicate key (with larger priority)
      ## because the mapping was removed when extracting the key with lesser priority.
      ## Ignore and extract again
      extract_min(p_queue)
    end
  end
  end


  defp default_opts() do
    [
    comparator: &Kernel.</2
    ]
  end

  defp init_mapping() do
    {__MODULE__, make_ref()}
  end

  defp mapping_key(mapping, key) do
    {mapping, key}
  end

  defp update_mapping(mapping, key, value) do
    Process.put(mapping_key(mapping, key), value)
  end

  def get_mapping(%{mapping: mapping} = _p_queue, key) do
    get_mapping(mapping, key)
  end

  def get_mapping(mapping, key) do
    Process.get(mapping_key(mapping, key))
  end

  defp extract_mapping(mapping, key) do
    Process.delete(mapping_key(mapping, key))
  end


  defp compare_priorities(getter_fun, pkey1, pkey2, compare_fun) do
    priority1 = get_priority(getter_fun, pkey1)
    priority2 = get_priority(getter_fun, pkey2)

    compare_fun.(priority1, priority2)
  end

  defp get_priority(getter_fun, key) do
    case getter_fun.(key) do
      nil -> nil
      {_key, priority} -> priority
    end
  end
end
