# Copied form https://github.com/monora/rgl/blob/master/lib/rgl/graph_wrapper.rb at version 0.5.9

module RGL
  module GraphWrapper
    # @return [Graph] the wrapped graph
    attr_accessor :graph

    # Creates a new GraphWrapper on _graph_.
    #
    def initialize(graph)
      @graph = graph
    end
  end # module GraphWrapper
end # RGL
