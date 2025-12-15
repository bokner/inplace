defmodule InPlace.ExactCoverTest do
  use ExUnit.Case

  alias InPlace.ExactCover

  require Logger

  describe "ExactCover" do

    test "Knuth and Wikipedia instances" do
      Enum.each([knuth_instance(), wiki_instance()],
        fn instance ->
          assert_instance(instance)
      end)
    end

    defp async_solution_handler(instance) do
      fn solution -> send(self(),
          Enum.map(solution, fn option_id ->
            Enum.at(instance, option_id)
          end)
          )
      end
    end

    defp knuth_instance() do
      {
      [
        [:c, :e, :f],
        [:a, :d, :g],
        [:b, :c, :f],
        [:a, :d],
        [:b, :g],
        [:d, :e, :g]
      ],
        [[:b, :g], [:a, :d], [:c, :e, :f]]
      }
    end

    defp wiki_instance() do
      ##  https://en.wikipedia.org/wiki/Exact_cover#Detailed_example
      {
      [
        [1, 4, 7],
        [1, 4],
        [4, 5, 7],
        [3, 5, 6],
        [2, 3, 6, 7],
        [2, 7]
      ],
      [[3, 5, 6], [2, 7], [1, 4]]
      }
    end

    defp assert_instance(instance) do
      {options, expected_solution} = instance
      ExactCover.solve(options,
        solution_handler: async_solution_handler(options)
      )

      received = receive do
        msg -> msg
      end


      assert Enum.sort(received) == Enum.sort(expected_solution)

      assert_exact_cover(options, received)

    end

    defp assert_exact_cover(options, solution) do
      combined = Enum.reduce(tl(solution), MapSet.new(hd(solution)),
        fn option, acc ->
          option_set = MapSet.new(option)
          assert MapSet.disjoint?(option_set, acc)
          MapSet.union(option_set, acc)
      end)

      assert MapSet.new(List.flatten(options)) == combined
    end
  end
end
