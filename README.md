# InPlace

Collection of mutable data structures.

Status: proof of concept, please use at your own risk.

An experimental library that has implementations of several ADTs based on [atomics module](https://www.erlang.org/doc/apps/erts/atomics.html)

Currently implemented:

- arrays
- stacks
- queues
- heaps
- priority queues
- linked lists
- bitsets


Check out the implementation of [X algorithm by Donald Knuth](https://en.wikipedia.org/wiki/Knuth%27s_Algorithm_X), accompanied by the [implementation of Sudoku]() as an example of usage.
[X algorithm](https://en.wikipedia.org/wiki/Knuth%27s_Algorithm_X) is built on the idea of [Dancing Links](https://en.wikipedia.org/wiki/Dancing_links), which is a technique to modify linked lists in place.
