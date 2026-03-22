# frozen_string_literal: true

module Philiprehberger
  module QueueStack
    # Thread-safe LIFO stack with optional capacity limit and blocking operations.
    #
    # @example
    #   s = Stack.new(capacity: 10)
    #   s.push('item')
    #   s.pop  # => 'item'
    class Stack
      # Create a new stack.
      #
      # @param capacity [Integer, nil] maximum number of items (nil for unlimited)
      def initialize(capacity: nil)
        @items = []
        @capacity = capacity
        @mutex = Mutex.new
        @not_empty = ConditionVariable.new
        @not_full = ConditionVariable.new
      end

      # Push an item onto the top of the stack. Blocks if at capacity.
      #
      # @param item [Object] the item to push
      # @return [void]
      def push(item)
        @mutex.synchronize do
          @not_full.wait(@mutex) while @capacity && @items.length >= @capacity
          @items.push(item)
          @not_empty.signal
        end
      end

      # Pop and return the top item. Blocks if empty.
      #
      # @return [Object] the popped item
      def pop
        @mutex.synchronize do
          @not_empty.wait(@mutex) while @items.empty?
          item = @items.pop
          @not_full.signal
          item
        end
      end

      # Try to pop an item with a timeout.
      #
      # @param timeout [Numeric] seconds to wait
      # @return [Object, nil] the popped item or nil on timeout
      def try_pop(timeout:)
        deadline = Time.now + timeout
        @mutex.synchronize do
          while @items.empty?
            remaining = deadline - Time.now
            return nil if remaining <= 0

            @not_empty.wait(@mutex, remaining)
          end
          item = @items.pop
          @not_full.signal
          item
        end
      end

      # Peek at the top item without removing it.
      #
      # @return [Object, nil] the top item or nil if empty
      def peek
        @mutex.synchronize { @items.last }
      end

      # Return the number of items in the stack.
      #
      # @return [Integer]
      def size
        @mutex.synchronize { @items.length }
      end

      # Whether the stack is empty.
      #
      # @return [Boolean]
      def empty?
        @mutex.synchronize { @items.empty? }
      end

      # Whether the stack is at capacity.
      #
      # @return [Boolean]
      def full?
        @mutex.synchronize { @capacity ? @items.length >= @capacity : false }
      end
    end
  end
end
