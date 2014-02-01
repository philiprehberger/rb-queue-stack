# frozen_string_literal: true

module Philiprehberger
  module QueueStack
    # Thread-safe FIFO queue with optional capacity limit and blocking operations.
    #
    # @example
    #   q = Queue.new(capacity: 10)
    #   q.enqueue('item')
    #   q.dequeue  # => 'item'
    class Queue
      # Create a new queue.
      #
      # @param capacity [Integer, nil] maximum number of items (nil for unlimited)
      def initialize(capacity: nil)
        @items = []
        @capacity = capacity
        @mutex = Mutex.new
        @not_empty = ConditionVariable.new
        @not_full = ConditionVariable.new
      end

      # Add an item to the back of the queue. Blocks if at capacity.
      #
      # @param item [Object] the item to enqueue
      # @return [void]
      def enqueue(item)
        @mutex.synchronize do
          @not_full.wait(@mutex) while @capacity && @items.length >= @capacity
          @items.push(item)
          @not_empty.signal
        end
      end

      # Remove and return the front item. Blocks if empty.
      #
      # @return [Object] the dequeued item
      def dequeue
        @mutex.synchronize do
          @not_empty.wait(@mutex) while @items.empty?
          item = @items.shift
          @not_full.signal
          item
        end
      end

      # Try to dequeue an item with a timeout.
      #
      # @param timeout [Numeric] seconds to wait
      # @return [Object, nil] the dequeued item or nil on timeout
      def try_dequeue(timeout:)
        deadline = Time.now + timeout
        @mutex.synchronize do
          while @items.empty?
            remaining = deadline - Time.now
            return nil if remaining <= 0

            @not_empty.wait(@mutex, remaining)
          end
          item = @items.shift
          @not_full.signal
          item
        end
      end

      # Peek at the front item without removing it.
      #
      # @return [Object, nil] the front item or nil if empty
      def peek
        @mutex.synchronize { @items.first }
      end

      # Return the number of items in the queue.
      #
      # @return [Integer]
      def size
        @mutex.synchronize { @items.length }
      end

      # Whether the queue is empty.
      #
      # @return [Boolean]
      def empty?
        @mutex.synchronize { @items.empty? }
      end

      # Whether the queue is at capacity.
      #
      # @return [Boolean]
      def full?
        @mutex.synchronize { @capacity ? @items.length >= @capacity : false }
      end
    end
  end
end
