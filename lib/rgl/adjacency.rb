# adjacency.rb
# Copied from https://raw.githubusercontent.com/monora/rgl/master/lib/rgl/adjacency.rb at version 0.5.9
#
require "rgl/mutable"
require "set"

module RGL
  # The +DirectedAdjacencyGraph+ class implements a generalized adjacency list
  # graph structure. An AdjacencyGraph is basically a two-dimensional structure
  # (ie, a list of lists). Each element of the first dimension represents a
  # vertex. Each of the vertices contains a one-dimensional structure that is
  # the list of all adjacent vertices.
  #
  # The class for representing the adjacency list of a vertex is, by default, a
  # +Set+. This can be configured by the client, however, when an AdjacencyGraph
  # is created.
  class DirectedAdjacencyGraph
    include MutableGraph

    # Shortcut for creating a DirectedAdjacencyGraph
    # @example
    #   RGL::DirectedAdjacencyGraph[1,2, 2,3, 2,4, 4,5].edges.to_a.to_s =>
    #     "(1-2)(2-3)(2-4)(4-5)"
    #
    def self.[](*a)
      result = new
      0.step(a.size - 1, 2) { |i| result.add_edge(a[i], a[i + 1]) }
      result
    end

    # The new empty graph has as its edgelist class the given class. The default
    # edgelist class is Set, to ensure set semantics for edges and vertices.
    #
    # If other graphs are passed as parameters their vertices and edges are
    # added to the new graph.
    # @param [Class] edgelist_class
    # @param [Array[Graph]] other_graphs
    def initialize(edgelist_class = Set, *other_graphs)
      @edgelist_class = edgelist_class
      @vertices_dict = Hash.new
      other_graphs.each do |g|
        g.each_vertex { |v| add_vertex v }
        g.each_edge { |v, w| add_edge v, w }
      end
    end

    # Copy internal vertices_dict
    #
    def initialize_copy(orig)
      @vertices_dict = orig.instance_eval { @vertices_dict }.dup
      @vertices_dict.keys.each do |v|
        @vertices_dict[v] = @vertices_dict[v].dup
      end
    end

    # Iterator for the keys of the vertices list hash.
    # @see Graph#each_vertex
    def each_vertex(&b)
      @vertices_dict.each_key(&b)
    end

    # @see Graph#each_adjacent
    def each_adjacent(v, &b)
      adjacency_list = (@vertices_dict[v] or raise NoVertexError, "No vertex #{v}.")
      adjacency_list.each(&b)
    end

    # @return true.
    #
    def directed?
      true
    end

    # Complexity is O(1), because the vertices are kept in a +Hash+ containing
    # as values the lists of adjacent vertices of _v_.
    #
    # @see Graph#has_vertex
    def has_vertex?(v)
      @vertices_dict.has_key?(v)
    end

    # Complexity is O(1), if a Set is used as adjacency list. Otherwise,
    # complexity is O(out_degree(v)).
    # @see Graph#has_edge?
    def has_edge?(u, v)
      has_vertex?(u) && @vertices_dict[u].include?(v)
    end

    # If the vertex is already in the graph (using +eql?+), the method does
    # nothing.
    # @see MutableGraph#add_vertex
    def add_vertex(v)
      @vertices_dict[v] ||= @edgelist_class.new
    end

    # @see MutableGraph#add_edge.
    def add_edge(u, v)
      add_vertex(u) # ensure key
      add_vertex(v) # ensure key
      basic_add_edge(u, v)
    end

    # @see MutableGraph#remove_vertex.
    def remove_vertex(v)
      @vertices_dict.delete(v)

      # remove v from all adjacency lists
      @vertices_dict.each_value { |adjList| adjList.delete(v) }
    end

    # @see MutableGraph::remove_edge.
    def remove_edge(u, v)
      @vertices_dict[u].delete(v) unless @vertices_dict[u].nil?
    end

    # Converts the adjacency list of each vertex to be of type +klass+. The
    # class is expected to have a new constructor which accepts an enumerable as
    # parameter.
    # @param [Class] klass
    def edgelist_class=(klass)
      @vertices_dict.keys.each do |v|
        @vertices_dict[v] = klass.new @vertices_dict[v].to_a
      end
    end

    protected

      def basic_add_edge(u, v)
        @vertices_dict[u].add(v)
      end
  end # class DirectedAdjacencyGraph

  # AdjacencyGraph is an undirected Graph. The methods
  # {DirectedAdjacencyGraph#add_edge} and {DirectedAdjacencyGraph#remove_edge}
  # are reimplemented: if an edge (u,v) is added or removed, then the reverse
  # edge (v,u) is also added or removed.
  #
  class AdjacencyGraph < DirectedAdjacencyGraph
    # @return false.
    #
    def directed?
      false
    end

    # Also removes (v,u)
    # @see DirectedAdjacencyGraph#remove_edge
    def remove_edge(u, v)
      super
      @vertices_dict[v].delete(u) unless @vertices_dict[v].nil?
    end

    protected

      def basic_add_edge(u, v)
        super
        @vertices_dict[v].add(u) # Insert backwards edge
      end
  end # class AdjacencyGraph

  module Graph
    # Convert a general graph to an AdjacencyGraph. If the graph is directed,
    # returns a {DirectedAdjacencyGraph}; otherwise, returns an {AdjacencyGraph}.
    # @return {DirectedAdjacencyGraph} or {AdjacencyGraph}
    def to_adjacency
      result = (directed? ? DirectedAdjacencyGraph : AdjacencyGraph).new
      each_vertex { |v| result.add_vertex(v) }
      each_edge { |u, v| result.add_edge(u, v) }
      result
    end

    # Return a new DirectedAdjacencyGraph which has the same set of vertices.
    # If (u,v) is an edge of the graph, then (v,u) is an edge of the result.
    #
    # If the graph is undirected, the result is self.
    # @return [DirectedAdjacencyGraph]
    def reverse
      return self unless directed?
      result = DirectedAdjacencyGraph.new
      each_vertex { |v| result.add_vertex v }
      each_edge { |u, v| result.add_edge(v, u) }
      result
    end

    # Return a new {AdjacencyGraph} which has the same set of vertices. If (u,v)
    # is an edge of the graph, then (u,v) and (v,u) (which are the same edges)
    # are edges of the result.
    #
    # If the graph is undirected, the result is +self+.
    # @return [AdjacencyGraph]
    def to_undirected
      return self unless directed?
      AdjacencyGraph.new(Set, self)
    end
  end # module Graph
end # module RGL
