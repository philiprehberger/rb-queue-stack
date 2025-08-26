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
      include Enumerable

      # Create a new queue.
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

      # Add an item to the back of the queue. Blocks if at capacity.
      #
      # @param item [Object] the item to enqueue
      # @return [void]
      # @raise [ClosedError] if the queue has been closed
      def enqueue(item)
        @mutex.synchronize do
          raise ClosedError, 'cannot enqueue on a closed queue' if @closed

          @not_full.wait(@mutex) while @capacity && @items.length >= @capacity
          @items.push(item)
          @not_empty.signal
        end
      end

      # Remove and return the front item. Blocks if empty (returns nil if closed and empty).
      #
      # @return [Object, nil] the dequeued item or nil if closed and empty
      def dequeue
        @mutex.synchronize do
          while @items.empty?
            return nil if @closed

            @not_empty.wait(@mutex)
          end
          item = @items.shift
          @not_full.signal
          item
        end
      end

      # Try to enqueue an item without blocking indefinitely.
      #
      # With timeout: nil, returns immediately. With a numeric timeout, waits up to
      # that many seconds for space to become available.
      #
      # @param item [Object] the item to enqueue
      # @param timeout [Numeric, nil] seconds to wait, or nil for non-blocking
      # @return [Boolean] true if enqueued, false if full (or timed out)
      # @raise [ClosedError] if the queue has been closed
      def try_enqueue(item, timeout: nil)
        @mutex.synchronize do
          raise ClosedError, 'cannot enqueue on a closed queue' if @closed

          if @capacity && @items.length >= @capacity
            return false if timeout.nil? || timeout <= 0

            deadline = Time.now + timeout
            while @items.length >= @capacity
              remaining = deadline - Time.now
              return false if remaining <= 0

              @not_full.wait(@mutex, remaining)
              raise ClosedError, 'cannot enqueue on a closed queue' if @closed
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

      # Try to dequeue an item with a timeout.
      #
      # @param timeout [Numeric] seconds to wait
      # @return [Object, nil] the dequeued item or nil on timeout
      def try_dequeue(timeout:)
        deadline = Time.now + timeout
        @mutex.synchronize do
          while @items.empty?
            return nil if @closed

            remaining = deadline - Time.now
            return nil if remaining <= 0

            @not_empty.wait(@mutex, remaining)
          end
          item = @items.shift
          @not_full.signal
          item
        end
      end

      # Remove and return all items as an array (FIFO order). Non-blocking.
      #
      # @return [Array] all items in FIFO order
      def drain
        @mutex.synchronize do
          result = @items.dup
          @items.clear
          @not_full.broadcast
          result
        end
      end

      # Iterate items without removing them (snapshot of current state, FIFO order).
      # Returns an Enumerator if no block is given.
      #
      # @yield [item] each item in FIFO order
      # @return [Enumerator, self]
      def each(&block)
        snapshot = @mutex.synchronize { @items.dup }
        return snapshot.each unless block

        snapshot.each(&block)
        self
      end

      # Return a snapshot of items as an array (FIFO order).
      #
      # @return [Array]
      def to_a
        @mutex.synchronize { @items.dup }
      end

      # Mark the queue as closed. New enqueue calls will raise ClosedError.
      # Existing items can still be dequeued. Wakes all waiting threads.
      #
      # @return [void]
      def close
        @mutex.synchronize do
          @closed = true
          @not_empty.broadcast
          @not_full.broadcast
        end
      end

      # Whether the queue has been closed.
      #
      # @return [Boolean]
      def closed?
        @mutex.synchronize { @closed }
      end

      # Peek at the front item without removing it.
      #
      # @return [Object, nil] the front item or nil if empty
      def peek
        @mutex.synchronize { @items.first }
      end

      # Peek at the item at the given position without removing it.
      #
      # Indexing follows +Array#[]+ semantics: +0+ is the front of the queue,
      # +size - 1+ is the back, and negative indices count from the back
      # (+-1+ is the last item). Returns +nil+ when the index is out of range.
      #
      # @param index [Integer] position in the queue (supports negative indices)
      # @return [Object, nil] the item at the position or nil if out of range
      def peek_at(index)
        @mutex.synchronize { @items[index] }
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
