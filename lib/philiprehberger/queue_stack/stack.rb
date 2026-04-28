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
      include Enumerable

      # Create a new stack.
      #
      # @param capacity [Integer, nil] maximum number of items (nil for unlimited)
      def initialize(capacity: nil)
        @items = []
        @capacity = capacity
        @closed = false
        @mutex = Mutex.new
        @not_empty = ConditionVariable.new
        @not_full = ConditionVariable.new
      end

      # Push an item onto the top of the stack. Blocks if at capacity.
      #
      # @param item [Object] the item to push
      # @return [void]
      # @raise [ClosedError] if the stack has been closed
      def push(item)
        @mutex.synchronize do
          raise ClosedError, 'cannot push on a closed stack' if @closed

          @not_full.wait(@mutex) while @capacity && @items.length >= @capacity
          @items.push(item)
          @not_empty.signal
        end
      end

      # Pop and return the top item. Blocks if empty (returns nil if closed and empty).
      #
      # @return [Object, nil] the popped item or nil if closed and empty
      def pop
        @mutex.synchronize do
          while @items.empty?
            return nil if @closed

            @not_empty.wait(@mutex)
          end
          item = @items.pop
          @not_full.signal
          item
        end
      end

      # Try to push an item without blocking indefinitely.
      #
      # With timeout: nil, returns immediately. With a numeric timeout, waits up to
      # that many seconds for space to become available.
      #
      # @param item [Object] the item to push
      # @param timeout [Numeric, nil] seconds to wait, or nil for non-blocking
      # @return [Boolean] true if pushed, false if full (or timed out)
      # @raise [ClosedError] if the stack has been closed
      def try_push(item, timeout: nil)
        @mutex.synchronize do
          raise ClosedError, 'cannot push on a closed stack' if @closed

          if @capacity && @items.length >= @capacity
            return false if timeout.nil? || timeout <= 0

            deadline = Time.now + timeout
            while @items.length >= @capacity
              remaining = deadline - Time.now
              return false if remaining <= 0

              @not_full.wait(@mutex, remaining)
              raise ClosedError, 'cannot push on a closed stack' if @closed
            end
          end

          @items.push(item)
          @not_empty.signal
          true
        end
      end

      # Remove all items without returning them. Signals any blocked producers.
      #
      # @return [void]
      def clear
        @mutex.synchronize do
          @items.clear
          @not_full.broadcast
        end
      end

      # Conditionally pop the top item. The block is called with the item that
      # would be popped next. If the block returns truthy, the item is removed
      # and returned. Otherwise the item is left in place and +nil+ is returned.
      # Returns +nil+ immediately if the stack is empty (non-blocking).
      #
      # @yield [item] the top item
      # @return [Object, nil] the removed item, or nil if empty or block returned false
      def pop_if
        @mutex.synchronize do
          return nil if @items.empty?
          return nil unless yield(@items.last)

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
            return nil if @closed

            remaining = deadline - Time.now
            return nil if remaining <= 0

            @not_empty.wait(@mutex, remaining)
          end
          item = @items.pop
          @not_full.signal
          item
        end
      end

      # Remove and return all items as an array (LIFO order, top first). Non-blocking.
      #
      # @return [Array] all items in LIFO order (top first)
      def drain
        @mutex.synchronize do
          result = @items.reverse
          @items.clear
          @not_full.broadcast
          result
        end
      end

      # Iterate items without removing them (snapshot of current state, LIFO order).
      # Returns an Enumerator if no block is given.
      #
      # @yield [item] each item in LIFO order (top first)
      # @return [Enumerator, self]
      def each(&block)
        snapshot = @mutex.synchronize { @items.reverse }
        return snapshot.each unless block

        snapshot.each(&block)
        self
      end

      # Return a snapshot of items as an array (LIFO order, top first).
      #
      # @return [Array]
      def to_a
        @mutex.synchronize { @items.reverse }
      end

      # Mark the stack as closed. New push calls will raise ClosedError.
      # Existing items can still be popped. Wakes all waiting threads.
      #
      # @return [void]
      def close
        @mutex.synchronize do
          @closed = true
          @not_empty.broadcast
          @not_full.broadcast
        end
      end

      # Whether the stack has been closed.
      #
      # @return [Boolean]
      def closed?
        @mutex.synchronize { @closed }
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

      # The configured capacity, or +nil+ for an unlimited stack.
      #
      # @return [Integer, nil]
      def capacity
        @mutex.synchronize { @capacity }
      end

      # Number of additional items the stack can accept before it is full.
      #
      # Returns +nil+ for unlimited stacks. For bounded stacks returns
      # +capacity - size+, clamped to a minimum of 0.
      #
      # @return [Integer, nil]
      def remaining_capacity
        @mutex.synchronize do
          next nil unless @capacity

          [@capacity - @items.length, 0].max
        end
      end
    end
  end
end
