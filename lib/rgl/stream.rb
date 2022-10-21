# Copied from https://raw.githubusercontent.com/monora/stream/master/lib/stream.rb at Version 0.5.5

STREAM_VERSION = "0.5.5".freeze

##
# Module Stream defines an interface for an external Iterator which
# can move forward and backwards. See README for more information.
#
# The functionality is similar to Smalltalk's ReadStream.
module RGL
  module Stream
    include Enumerable

    # This exception is raised when the Stream is requested to move past
    # the end or beginning.
    class EndOfStreamException < StandardError; end

    # Returns false if the next #forward will return an element.
    def at_end?
      raise NotImplementedError
    end

    # Returns false if the next #backward will return an element.
    def at_beginning?
      raise NotImplementedError
    end

    # Move forward one position. Returns the _target_ of current_edge.
    # Raises Stream::EndOfStreamException if at_end? is true.
    def forward
      raise EndOfStreamException if at_end?

      basic_forward
    end

    # Move backward one position. Returns the _source_ of current_edge. Raises
    # Stream::EndOfStreamException if at_beginning? is true.
    def backward
      raise EndOfStreamException if at_beginning?

      basic_backward
    end

    # Position the stream before its first element, i.e. the next #forward
    # will return the first element.
    def set_to_begin
      basic_backward until at_beginning?
    end

    # Position the stream behind its last element, i.e. the next #backward
    # will return the last element.
    def set_to_end
      basic_forward until at_end?
    end

    protected

      def basic_forward
        raise NotImplementedError
      end

      def basic_backward
        raise NotImplementedError
      end

      def basic_current
        backward
        forward
      end

      def basic_peek
        forward
        backward
      end

    public

    # Move forward until the boolean block is not false and returns the element
    # found. Returns nil if no object matches.
    #
    # This is similar to #detect, but starts the search from the
    # current position. #detect, which is inherited from Enumerable uses
    # #each, which implicitly calls #set_to_begin.
    def move_forward_until
      until at_end?
        element = basic_forward
        return element if yield(element)
      end
      nil
    end

    # Move backward until the boolean block is not false and returns the element
    # found. Returns nil if no object matches.
    def move_backward_until
      until at_beginning?
        element = basic_backward
        return element if yield(element)
      end
      nil
    end

    # Returns the element returned by the last call of #forward. If at_beginning?
    # is true self is returned.
    def current
      at_beginning? ? self : basic_current
    end

    # Returns the element returned by the last call of #backward. If at_end? is
    # true self is returned.
    def peek
      at_end? ? self : basic_peek
    end

    # Returns the array [#current,#peek].
    def current_edge
      [current, peek]
    end

    # Returns the first element of the stream. This is accomplished by calling
    # set_to_begin and #forward, which means a state change.
    def first
      set_to_begin
      forward
    end

    # Returns the last element of the stream. This is accomplished by calling
    # set_to_begin and #backward, which means a state change.
    def last
      set_to_end
      backward
    end

    # Returns true if the stream is empty which is equivalent to at_end? and
    # at_beginning? both being true.
    def empty?
      at_end? and at_beginning?
    end

    # Implements the standard iterator used by module Enumerable, by calling
    # set_to_begin and basic_forward until at_end? is true.
    def each
      set_to_begin
      yield basic_forward until at_end?
    end

    # create_stream is used for each Enumerable to create a stream for it. A
    # Stream as an Enumerable returns itself.
    def create_stream
      self
    end

    # A Stream::WrappedStream should return the wrapped stream unwrapped. If the
    # stream is not a wrapper around another stream it simply returns itself.
    def unwrapped
      self
    end

    # The abstract super class of all concrete Classes implementing the Stream
    # interface. Only used for including module Stream.
    class BasicStream
      include Stream
    end

    # A Singleton class for an empty stream. EmptyStream.instance is the sole
    # instance which answers true for both at_end? and at_beginning?
    class EmptyStream < BasicStream
      require "singleton"
      include Singleton

      def at_end?
        true
      end

      def at_beginning?
        true
      end

      def basic_forward
        raise EndOfStreamException
      end

      def basic_backward
        raise EndOfStreamException
      end
    end

    # A CollectionStream can be used as an external iterator for each
    # interger-indexed collection. The state of the iterator is stored in instance
    # variable @pos.
    #
    # A CollectionStream for an array is created by the method
    # Array#create_stream.
    class CollectionStream < BasicStream
      attr_reader :pos

      # Creates a new CollectionStream for the indexable sequence _seq_.
      def initialize(seq)
        @seq = seq
        set_to_begin
      end

      def at_end?
        @pos + 1 >= @seq.size
      end

      def at_beginning?
        @pos < 0
      end

      # positioning

      def set_to_begin
        @pos = -1
      end

      def set_to_end
        @pos = @seq.size - 1
      end

      def basic_forward
        @pos += 1
        @seq[@pos]
      end

      def basic_backward
        r = @seq[@pos]
        @pos -= 1; r
      end

      protected

        # basic_current and basic_peek can be implemented more efficiently than in
        # superclass
        def basic_current
          @seq[@pos]
        end

        def basic_peek
          @seq[@pos + 1]
        end
    end

    # CollectionStream

    # A simple Iterator for iterating over a sequence of integers starting from
    # zero up to a given upper bound. Mainly used by Stream::FilteredStream. Could
    # be made private but if somebody needs it here it is. Is there a better name
    # for it?
    #
    # The upper bound is stored in the instance variable @stop which can be
    # incremented dynamically by the method increment_stop.
    class IntervalStream < BasicStream
      attr_reader :pos

      # Create a new IntervalStream with upper bound _stop_. stop - 1 is the last
      # element. By default _stop_ is zero which means that the stream is empty.
      def initialize(stop = 0)
        @stop = stop - 1
        set_to_begin
      end

      def at_beginning?
        @pos < 0
      end

      def at_end?
        @pos == @stop
      end

      def set_to_end
        @pos = @stop
      end

      def set_to_begin
        @pos = -1
      end

      # Increment the upper bound by incr.
      def increment_stop(incr = 1)
        @stop += incr
      end

      def basic_forward
        @pos += 1
      end

      def basic_backward
        @pos -= 1
        @pos + 1
      end
    end

    # Class WrappedStream is the abstract superclass for stream classes that wrap
    # another stream. The basic methods are simple delegated to the wrapped
    # stream. Thus creating a WrappedStream on a CollectionStream would yield an
    # equivalent stream:
    #
    #  arrayStream = [1,2,3].create_stream
    #
    #  arrayStream.to_a => [1,2,3]
    #  Stream::WrappedStream.new(arrayStream).to_a => [1,2,3]
    class WrappedStream < BasicStream
      attr_reader :wrapped_stream

      # Create a new WrappedStream wrapping the Stream _other_stream_.
      def initialize(other_stream)
        @wrapped_stream = other_stream
      end

      def at_beginning?
        @wrapped_stream.at_beginning?
      end

      def at_end?
        @wrapped_stream.at_end?
      end

      def set_to_end
        @wrapped_stream.set_to_end
      end

      def set_to_begin
        @wrapped_stream.set_to_begin
      end

      # Returns the wrapped stream unwrapped.
      def unwrapped
        @wrapped_stream.unwrapped
      end

      def basic_forward
        @wrapped_stream.basic_forward
      end

      def basic_backward
        @wrapped_stream.basic_backward
      end
    end

    ##
    # A FilteredStream selects all elements which satisfy a given booelan block of
    # another stream being wrapped.
    #
    # A FilteredStream is created by the method #filtered:
    #
    #  (1..6).create_stream.filtered { |x| x % 2 == 0 }.to_a ==> [2, 4, 6]
    class FilteredStream < WrappedStream
      # Create a new FilteredStream wrapping _other_stream_ and selecting all its
      # elements which satisfy the condition defined by the block_filter_.
      def initialize(other_stream, &filter)
        super other_stream
        @filter = filter
        @position_holder = IntervalStream.new
        set_to_begin
      end

      def at_beginning?
        @position_holder.at_beginning?
      end

      # at_end? has to look ahead if there is an element satisfing the filter
      def at_end?
        @position_holder.at_end? and
          begin
            if @peek.nil?
              @peek = wrapped_stream.move_forward_until(&@filter) or return true
              @position_holder.increment_stop
            end
            false
          end
      end

      def basic_forward
        result =
          if @peek.nil?
            wrapped_stream.move_forward_until(&@filter)
          else
            # Do not move!!
            @peek
          end
        @peek = nil
        @position_holder.forward
        result
      end

      def basic_backward
        wrapped_stream.backward unless @peek.nil?
        @peek = nil
        @position_holder.backward
        wrapped_stream.move_backward_until(&@filter) or self
      end

      def set_to_end
        # Not super which is a WrappedStream, but same behavior as in Stream
        basic_forward until at_end?
      end

      def set_to_begin
        super
        @peek = nil
        @position_holder.set_to_begin
      end

      # Returns the current position of the stream.
      def pos
        @position_holder.pos
      end
    end

    # FilteredStream

    ##
    # Each reversable stream (a stream that implements #backward and
    # at_beginning?) can be wrapped by a ReversedStream.
    #
    # A ReversedStream is created by the method #reverse:
    #
    #  (1..6).create_stream.reverse.to_a ==> [6, 5, 4, 3, 2, 1]
    class ReversedStream < WrappedStream
      # Create a reversing wrapper for the reversable stream _other_stream_. If
      # _other_stream_ does not support backward moving a NotImplementedError is
      # signaled on the first backward move.
      def initialize(other_stream)
        super other_stream
        set_to_begin
      end

      # Returns true if the wrapped stream is at_end?.
      def at_beginning?
        wrapped_stream.at_end?
      end

      # Returns true if the wrapped stream is at_beginning?.
      def at_end?
        wrapped_stream.at_beginning?
      end

      # Moves the wrapped stream one step backward.
      def basic_forward
        wrapped_stream.basic_backward
      end

      # Moves the wrapped stream one step forward.
      def basic_backward
        wrapped_stream.basic_forward
      end

      # Sets the wrapped stream to the beginning.
      def set_to_end
        wrapped_stream.set_to_begin
      end

      # Sets the wrapped stream to the end.
      def set_to_begin
        wrapped_stream.set_to_end
      end
    end

    ##
    # The analog to Enumerable#collect for a stream is a MappedStream wrapping
    # another stream. A MappedStream is created by the method #collect, thus
    # modifying the behavior mixed in by Enumerable:
    #
    #  (1..5).create_stream.collect {|x| x**2}.type ==> Stream::MappedStream
    #  (1..5).collect {|x| x**2} ==> [1, 4, 9, 16, 25]
    #  (1..5).create_stream.collect {|x| x**2}.to_a ==> [1, 4, 9, 16, 25]
    class MappedStream < WrappedStream
      ##
      # Creates a new MappedStream wrapping _other_stream_ which calls the block
      # _mapping_ on each move.
      def initialize(other_stream, &mapping)
        super other_stream
        @mapping = mapping
      end

      # Apply the stored closure for the next element in the wrapped stream and
      # return the result.
      def basic_forward
        @mapping.call(super)
      end

      # Apply the stored closure for the previous element in the wrapped stream
      # and return the result.
      def basic_backward
        @mapping.call(super)
      end
    end

    ##
    # Given a stream of streams. Than a ConcatenatedStream is obtained by
    # concatenating these in the given order. A ConcatenatedStream is created by
    # the methods Stream#concatenate or Stream#concatenate_collected send to a
    # stream of streams or by the method + which concatenats two streams:
    #
    #  ((1..3).create_stream + [4,5].create_stream).to_a ==> [1, 2, 3, 4, 5]
    class ConcatenatedStream < WrappedStream
      alias streamOfStreams wrapped_stream
      private :streamOfStreams

      # Creates a new ConcatenatedStream wrapping the stream of streams
      # _streamOfStreams_.
      def initialize(streamOfStreams)
        super
        set_to_begin
      end

      # If the current stream is at end, than at_end? has to look ahead to find a
      # non empty in the stream of streams, which than gets the current stream.
      def at_end?
        unless @current_stream.at_end?
          return false
        end

        until streamOfStreams.at_end?
          dir = @dir_of_last_move
          @dir_of_last_move = :forward
          s = streamOfStreams.basic_forward
          # if last move was backwards, then @current_stream is
          # equivalent to s. Move to next stream.
          next if dir == :backward

          s.set_to_begin
          if s.at_end? # empty stream?
            next # skip it
          else
            @current_stream = s
            return false # found non empty stream
          end
        end # until
        reached_boundary # sets @dir_of_last_move and @current_stream
      end

      # Same as at_end? the other way round.
      # @return [Boolean]
      def at_beginning?
        # same algorithm as at_end? the other way round.
        unless @current_stream.at_beginning?
          return false
        end

        until streamOfStreams.at_beginning?
          dir = @dir_of_last_move
          @dir_of_last_move = :backward
          s = streamOfStreams.basic_backward
          next if dir == :forward

          s.set_to_end
          if s.at_beginning?
            next
          else
            @current_stream = s
            return false
          end
        end
        reached_boundary
      end

      def set_to_begin
        super; reached_boundary
      end

      def set_to_end
        super; reached_boundary
      end

      # Returns the next element of @current_stream. at_end? ensured that there is
      # one.
      def basic_forward
        @current_stream.basic_forward
      end

      # Returns the previous element of @current_stream. at_beginning? ensured that
      # there is one.
      def basic_backward
        @current_stream.basic_backward
      end

      private

        def reached_boundary
          @current_stream = EmptyStream.instance
          @dir_of_last_move = :none # not :forward or :backward
          true
        end
      # Uff, this was the hardest stream to implement.
    end

    # ConcatenatedStream

    # An ImplicitStream is an easy way to create a stream on the fly without
    # defining a subclass of BasicStream. The basic methods required for a stream
    # are defined with blocks:
    #
    #  s = Stream::ImplicitStream.new { |s|
    #		x = 0
    #		s.at_end_proc = proc { x == 5 }
    #		s.forward_proc = proc { x += 1 }
    #	 }
    #
    #  s.to_a ==> [1, 2, 3, 4, 5]
    #
    # Note that this stream is only partially defined since backward_proc and
    # at_beginning_proc are not defined. It may as well be useful if only moving
    # forward is required by the code fragment.
    #
    # ImplicitStreams can be based on other streams using the method modify
    # which is for example used in the methods for creating stream wrappers which
    # remove the first or last element of an existing stream (see remove_first
    # and remove_last).
    class ImplicitStream < BasicStream
      attr_writer :at_beginning_proc, :at_end_proc, :forward_proc,
                  :backward_proc, :set_to_begin_proc, :set_to_end_proc
      attr_reader :wrapped_stream

      # Create a new ImplicitStream which might wrap an existing stream
      # _other_stream_. If _other_stream_ is supplied the blocks for the basic
      # stream methods are initialized with closures that delegate all operations
      # to the wrapped stream.
      #
      # If a block is given to new, than it is called with the new ImplicitStream
      # stream as parameter letting the client overwriting the default blocks.
      def initialize(other_stream = nil)
        # Initialize with defaults
        @at_beginning_proc = proc { true }
        @at_end_proc = proc { true }

        @set_to_begin_proc = proc {}
        @set_to_end_proc = proc {}

        if other_stream
          @wrapped_stream = other_stream
          @at_beginning_proc = proc { other_stream.at_beginning? }
          @at_end_proc = proc { other_stream.at_end? }
          @forward_proc = proc { other_stream.basic_forward }
          @backward_proc = proc { other_stream.basic_backward }
          @set_to_end_proc = proc { other_stream.set_to_end }
          @set_to_begin_proc = proc { other_stream.set_to_begin }
        end
        yield self if block_given? # let client overwrite defaults
      end

      # Returns the value of @at_beginning_proc.
      def at_beginning?
        @at_beginning_proc.call
      end

      # Returns the value of @at_end_proc.
      def at_end?
        @at_end_proc.call
      end

      # Returns the value of @forward_proc.
      def basic_forward
        @forward_proc.call
      end

      # Returns the value of @backward_proc_proc.
      def basic_backward
        @backward_proc.call
      end

      # Calls set_to_end_proc or super if set_to_end_proc is undefined.
      def set_to_end
        @set_to_end_proc ? @set_to_end_proc.call : super
      end

      # Calls set_to_begin_proc or super if set_to_begin_proc is undefined.
      def set_to_begin
        @set_to_begin_proc ? @set_to_begin_proc.call : super
      end
    end

    # ImplicitStream

    # Stream creation functions

    ##
    # Return a Stream::FilteredStream which iterates over all my elements
    # satisfying the condition specified  by the block.
    def filtered(&block)
      FilteredStream.new(self, &block)
    end

    # Create a Stream::ReversedStream wrapper on self.
    def reverse
      ReversedStream.new self
    end

    # Create a Stream::MappedStream wrapper on self. Instead of returning the
    # stream element on each move, the value of calling _mapping_ is returned
    # instead. See Stream::MappedStream for examples.
    def collect(&mapping)
      MappedStream.new(self, &mapping)
    end

    # Create a Stream::ConcatenatedStream on self, which must be a stream of
    # streams.
    def concatenate
      ConcatenatedStream.new self
    end

    # Create a Stream::ConcatenatedStream, concatenated from streams build with
    # the block for each element of self:
    #
    #  s = [1, 2, 3].create_stream.concatenate_collected { |i|
    #    [i,-i].create_stream
    #  }.
    #  s.to_a ==> [1, -1, 2, -2, 3, -3]
    def concatenate_collected(&mapping)
      collect(&mapping).concatenate
    end

    # Create a Stream::ConcatenatedStream by concatenatating the receiver and
    # _other_stream_
    #
    #  (%w(a b c).create_stream + [4,5].create_stream).to_a
    #  ==> ["a", "b", "c", 4, 5]
    def +(other)
      [self, other].create_stream.concatenate
    end

    # Create a Stream::ImplicitStream which wraps the receiver stream by modifying
    # one or more basic methods of the receiver. As an example the method
    # remove_first uses #modify to create an ImplicitStream which filters the
    # first element away.
    def modify(&block)
      ImplicitStream.new(self, &block)
    end

    # Returns a Stream::ImplicitStream wrapping a Stream::FilteredStream, which
    # eliminates the first element of the receiver.
    #
    #  (1..3).create_stream.remove_first.to_a ==> [2,3]
    def remove_first
      i = 0
      filter = filtered { i += 1; i > 1 }
      filter.modify do |s|
        s.set_to_begin_proc = proc { filter.set_to_begin; i = 0 }
      end
    end

    # Returns a Stream which eliminates the first element of the receiver.
    #
    #  (1..3).create_stream.remove_last.to_a ==> [1,2]
    #
    # <em>Take a look at the source. The implementation is inefficient but
    # elegant.</em>
    def remove_last
      reverse.remove_first.reverse # I like this one
    end
  end
end

# extensions

# The extension on Array could be done for all Objects supporting []
# and size.
class Array
  # Creates a new Stream::CollectionStream on self.
  def create_stream
    Stream::CollectionStream.new self
  end
end

module Enumerable
  # If not an array the enumerable is converted to an array and then
  # to a stream using a Stream::CollectionStream.
  def create_stream
    to_a.create_stream
  end
end
