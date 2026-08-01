defmodule InPlace.Examples.MST do
  alias InPlace.UnionFind

  def kruskal(edges) do
    ## The edges is a list of {u, v, distance} tuples
    vertices = Enum.reduce(edges, MapSet.new(), fn {v1, v2, _}, acc ->
      MapSet.put(acc, v1) |> MapSet.put(v2)
    end)

    num_vertices = MapSet.size(vertices)
    {vertex_to_idx, idx_to_vertex} = Enum.with_index(vertices, 1)
    |> Enum.reduce({Map.new(), Map.new()}, fn {vertex, idx}, {to_idx_acc, to_vertex_acc} ->
      {
        Map.put(to_idx_acc, vertex, idx),
        Map.put(to_vertex_acc, idx, vertex)
      }
    end)

    uf = UnionFind.new(num_vertices)

    sorted_edges = Enum.sort_by(edges, fn {_v1, _v2, distance} -> distance end)
    {tree, weight} = Enum.reduce_while(sorted_edges, {[], 0},
      fn {from, to, distance} = _edge, {edges_acc, weight_acc}  = acc ->
        from_idx = Map.get(vertex_to_idx, from)
        to_idx = Map.get(vertex_to_idx, to)
        if UnionFind.find(uf, from_idx) == UnionFind.find(uf, to_idx) do
          {:cont, acc}
        else
          acc =  {
            [{from_idx, to_idx} | edges_acc],
            weight_acc + distance
          }

          UnionFind.union(uf, from_idx, to_idx)
          ## All vertices in one set?
          if UnionFind.set_size(uf, 1) == num_vertices do
            {:halt, acc}
          else
            {:cont, acc}
          end
        end
    end)

    {
      Enum.map(tree, fn {v1, v2} -> {Map.get(idx_to_vertex, v1), Map.get(idx_to_vertex, v2)} end),
      weight
    }
  end
end
