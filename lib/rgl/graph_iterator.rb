# Copied form https://github.com/monora/rgl/blob/master/lib/rgl/graph_iterator.rb at version 0.5.9

require "rgl/stream"

require "rgl/graph_wrapper"

module RGL
  # A GraphIterator is the abstract basis for all Iterators on graphs.
  # Each graph iterator should implement the protocol defined in module
  # {https://rubydoc.info/github/monora/stream Stream}.
  #
  module GraphIterator
    include Stream
    include GraphWrapper

    # @return [int]
    def length
      inject(0) { |sum| sum + 1 }
    end
  end
end # RGL
