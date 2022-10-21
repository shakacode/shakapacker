# base.rb
# Copied form https://github.com/monora/rgl/blob/master/lib/rgl/base.rb at version 0.5.9

# version information
RGL_VERSION = "0.5.9"

# Module {RGL} defines the namespace for all modules and classes of the graph
# library. The main module is {Graph} which defines the abstract behavior of
# all graphs in the library. Other important modules or classes are:
#
# * Class {AdjacencyGraph} provides a concrete implementation of an undirected graph.
# * Module {Edge} defines edges of a graph.
# * {GraphIterator} and {GraphVisitor} provide support for iterating and searching.
# * {DOT} helps to visualize graphs.

module RGL
  class NotDirectedError < RuntimeError; end

  class NotUndirectedError < RuntimeError; end

  class NoVertexError < IndexError; end

  class NoEdgeError < IndexError; end

  INFINITY = 1.0 / 0.0 # positive infinity

  # Module {Edge} includes classes for representing edges of directed and
  # undirected graphs. There is no need for a vertex class, because every ruby
  # object can be a vertex of a graph.
  #
  module Edge
    # An {Edge} is simply a directed pair +(source -> target)+. Most library
    # functions try do omit to instantiate edges. They instead use two vertex
    # parameters for representing edges (see {Graph#each_edge}). If a client wants to
    # store edges explicitly {DirectedEdge} or {UnDirectedEdge} instances are
    # returned (i.e. {Graph#edges}).
    #
    class DirectedEdge
      attr_accessor :source, :target
      # Can be used to create an edge from a two element array.
      #
      def self.[](*a)
        new(a[0], a[1])
      end

      # Create a new DirectedEdge with source +a+ and target +b+.
      #
      def initialize(a, b)
        @source, @target = a, b
      end

      # Two directed edges (u,v) and (x,y) are equal iff u == x and v == y. +eql?+
      # is needed when edges are inserted into a +Set+. +eql?+ is aliased to +==+.
      def eql?(edge)
        (source == edge.source) && (target == edge.target)
      end

      alias == eql?

      def hash
        source.hash ^ target.hash
      end

      # Returns (v,u) if self == (u,v).
      # @return [Edge]
      def reverse
        self.class.new(target, source)
      end

      # Edges can be indexed. +edge.at(0) == edge.source+, +edge.at(n) ==
      # edge.target+ for all +n>0+. Edges can thus be used as a two element array.
      #
      def [](index)
        index.zero? ? source : target
      end

      # Returns string representation of the edge
      # @example
      #   DirectedEdge[1,2].to_s == "(1-2)"
      # @return [String]
      def to_s
        "(#{source}-#{target})"
      end

      # Since Ruby 2.0 #inspect no longer calls #to_s. So we alias it to to_s (fixes #22)
      alias inspect to_s

      # Returns the array [source,target].
      # @return [Array]
      def to_a
        [source, target]
      end

      # Sort support is dispatched to the <=> method of Array
      #
      def <=>(e)
        self.to_a <=> e.to_a
      end
    end # DirectedEdge

    # An undirected edge is simply an undirected pair (source, target) used in
    # undirected graphs.
    # @example
    #   UnDirectedEdge[u,v] == UnDirectedEdge[v,u]
    #
    class UnDirectedEdge < DirectedEdge
      def eql?(edge)
        super || ((target == edge.source) && (source == edge.target))
      end

      # @example
      #   UnDirectedEdge[1,2].to_s == "(1=2)"
      # @return (see DirectedEdge#to_s)
      def to_s
        "(#{source}=#{target})"
      end
    end
  end # Edge

  # In _BGL_ terminology the module Graph defines the graph concept (see {Graph
  # Concepts}[https://www.boost.org/libs/graph/doc/graph_concepts.html]). We
  # however do not distinguish between the IncidenceGraph, EdgeListGraph and
  # VertexListGraph concepts, which would complicate the interface too much.
  # These concepts are defined in BGL to differentiate between efficient access
  # to edges and vertices.
  #
  # The RGL Graph concept contains only a few requirements that are common to
  # all the graph concepts. These include, especially, the iterators defining
  # the sets of vertices and edges (see {#each_vertex} and {#each_adjacent}). Most
  # other functions are derived from these fundamental iterators, i.e.
  # {#each_edge}, {#num_vertices} or {#num_edges}.
  #
  # Each graph is an enumerable of vertices.
  #
  module Graph
    include Enumerable
    include Edge
    # The +each_vertex+ iterator defines the set of vertices of the graph. This
    # method must be defined by concrete graph classes. It defines the BGL
    # VertexListGraph concept.
    #
    def each_vertex() # :yields: v
      raise NotImplementedError
    end

    # The +each_adjacent+ iterator defines the out edges of vertex +v+. This
    # method must be defined by concrete graph classes. Its defines the BGL
    # IncidenceGraph concept.
    # @param v a vertex of the graph
    #
    def each_adjacent(v) # :yields: v
      raise NotImplementedError
    end

    # The +each_edge+ iterator should provide efficient access to all edges of the
    # graph. Its defines the BGL EdgeListGraph concept.
    #
    # This method must *not* be defined by concrete graph classes, because it
    # can be implemented using {#each_vertex} and {#each_adjacent}. However for
    # undirected graphs the function is inefficient because we must not yield
    # (v,u) if we already visited edge (u,v).
    def each_edge(&block)
      if directed?
        each_vertex do |u|
          each_adjacent(u) { |v| yield u, v }
        end
      else
        each_edge_aux(&block) # concrete graphs should to this better
      end
    end

    # Vertices get enumerated. A graph is thus an enumerable of vertices.
    #
    def each(&block)
      each_vertex(&block)
    end

    # Is the graph directed? The default returns false.
    def directed?
      false
    end

    # Returns true if +v+ is a vertex of the graph. Same as #include? inherited
    # from Enumerable. Complexity is O(num_vertices) by default. Concrete graph
    # may be better here (see AdjacencyGraph).
    # @param (see #each_adjacent)
    def has_vertex?(v)
      include?(v) # inherited from enumerable
    end

    # Returns true if the graph has no vertices, i.e. num_vertices == 0.
    #
    def empty?
      num_vertices.zero?
    end

    # Synonym for #to_a inherited by Enumerable.
    # @return [Array] of vertices
    def vertices
      to_a
    end

    # @return [Class] the class for edges: {Edge::DirectedEdge} or {Edge::UnDirectedEdge}.
    #
    def edge_class
      directed? ? DirectedEdge : UnDirectedEdge
    end

    # @return [Array] of edges (DirectedEdge or UnDirectedEdge) of the graph
    # It uses {#each_edge} to compute the edges
    def edges
      result = []
      c = edge_class
      each_edge { |u, v| result << c.new(u, v) }
      result
    end

    # @return [Array] of vertices adjacent to vertex +v+.
    # @param (see #each_adjacent)
    def adjacent_vertices(v)
      r = []
      each_adjacent(v) { |u| r << u }
      r
    end

    # Returns the number of out-edges (for directed graphs) or the number of
    # incident edges (for undirected graphs) of vertex +v+.
    # @return [int]
    # @param (see #each_adjacent)
    def out_degree(v)
      r = 0
      each_adjacent(v) { |u| r += 1 }
      r
    end

    # @return [int] the number of vertices
    #
    def size # Why not in Enumerable?
      inject(0) { |n, v| n + 1 }
    end

    alias num_vertices size

    # @return [int] the number of edges
    #
    def num_edges
      r = 0
      each_edge { |u, v| r += 1 }
      r
    end

    # Utility method to show a string representation of the edges of the graph.
    # @return [String]
    def to_s
      edges.collect { |e| e.to_s }.sort.join
    end

    # Two graphs are equal iff they have equal directed? property as well as
    # vertices and edges sets.
    # @param [Graph] other
    def eql?(other)
      equal?(other) || eql_graph?(other)
    end

    alias == eql?

    private

      def eql_graph?(other)
        other.is_a?(Graph) && directed? == other.directed? && eql_vertices_set?(other) && eql_edges_set?(other)
      end

      def eql_vertices_set?(other)
        other_num_vertices = 0

        other.each_vertex do |v|
          if has_vertex?(v)
            other_num_vertices += 1
          else
            return false
          end
        end

        other_num_vertices == num_vertices
      end

      def eql_edges_set?(other)
        other_num_edges = 0

        other.each_edge do |u, v|
          if has_edge?(u, v)
            other_num_edges += 1
          else
            return false
          end
        end

        other_num_edges == num_edges
      end

      def each_edge_aux
        # needed in each_edge
        visited = Hash.new

        each_vertex do |u|
          each_adjacent(u) do |v|
            edge = UnDirectedEdge.new(u, v)

            unless visited.has_key?(edge)
              visited[edge] = true
              yield u, v
            end
          end
        end
      end
  end # module Graph
end # module RGL
