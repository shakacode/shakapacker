# topsort.rb
# Copied form https://github.com/monora/rgl/blob/master/lib/rgl/topsort.rb at version 0.5.9

require "rgl/graph_iterator"

module RGL
  # Topological Sort Iterator
  #
  # The topological sort algorithm creates a linear ordering of the vertices
  # such that if edge (u,v) appears in the graph, then u comes before v in
  # the ordering. The graph must be a directed acyclic graph (DAG).
  #
  # The iterator can also be applied to an undirected graph or to a directed graph
  # which contains a cycle. In this case, the Iterator does not reach all
  # vertices. The implementation of {Graph#acyclic?} uses this fact.
  #
  # @see Graph#topsort_iterator
  class TopsortIterator
    include GraphIterator

    def initialize(g)
      super(g)
      set_to_begin
    end

    def set_to_begin
      @waiting   = Array.new
      @inDegrees = Hash.new(0)

      graph.each_vertex do |u|
        @inDegrees[u] = 0 unless @inDegrees.has_key?(u)
        graph.each_adjacent(u) do |v|
          @inDegrees[v] += 1
        end
      end

      @inDegrees.each_pair do |v, indegree|
        @waiting.push(v) if indegree.zero?
      end
    end

    # @private
    def basic_forward
      u = @waiting.pop
      graph.each_adjacent(u) do |v|
        @inDegrees[v] -= 1
        @waiting.push(v) if @inDegrees[v].zero?
      end
      u
    end

    def at_beginning?
      true
    end

    def at_end?
      @waiting.empty?
    end
  end # class TopsortIterator

  module Graph
    # @return [TopsortIterator] for the graph.
    #
    def topsort_iterator
      TopsortIterator.new(self)
    end

    # Returns true if the graph contains no cycles. This is only meaningful
    # for directed graphs. Returns false for undirected graphs.
    #
    def acyclic?
      topsort_iterator.length == num_vertices
    end
  end # module Graph
end # module RGL
