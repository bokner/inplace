defmodule BitGraph.StackTest do
  use ExUnit.Case

  alias BitGraph.Stack

  describe "Stack" do
    test "operations" do
      ## Fresh stack
      stack = Stack.new(100)
      assert Stack.empty?(stack)
      refute Stack.peek(stack)
      refute Stack.pop(stack)

      ## Push
      nums = Enum.shuffle(1..100)
      Enum.each(Enum.with_index(nums, 1),
        fn {num, idx} ->
          Stack.push(stack, num)
          assert Stack.peek(stack) == num
          refute Stack.empty?(stack)
          assert num == Stack.peek(stack)
          assert idx == Stack.size(stack)
      end)

      ## Stack overflow (we are now at capacity, 100 elements in the stack)
      assert catch_throw({:error, :stackoverflow} = Stack.push(stack, 101))
      assert Stack.size(stack) == 100

      ## Pop
      Enum.each(1..100, fn i ->
        top = Stack.peek(stack)
        el = Stack.pop(stack)
        assert top == el
        assert el in 1..100
        assert Stack.size(stack) == 100 - i
      end)

      assert Stack.empty?(stack)
    end
  end
end
