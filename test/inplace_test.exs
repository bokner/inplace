defmodule InplaceTest do
  use ExUnit.Case
  doctest Inplace

  test "greets the world" do
    assert Inplace.hello() == :world
  end
end
