defmodule InPlace.XCC do
  @moduledoc """
    XCC (Exact Cover with Colors) solver.
    Follows the implementation described in:
    THE ART OF COMPUTER PROGRAMMING
    VOLUME 4, FASCICLE 7
    by Donald Knuth
  """

  def init(options) do
    ## Options are sets that contain item names, optionally marked with color codes.
    ## See the material referenced above for details.
    ##################################################
    ## Build the state structures (roughly as described by D. Knuth)
  end

  def test() do
    options =
      [
        ["p", "q", "x", "y:A"],
        ["p", "r", "x:A", "y"],
        ["p", "x:B"],
        ["q", "x:A"],
        ["r", "y:B"]
      ]
    end
end
