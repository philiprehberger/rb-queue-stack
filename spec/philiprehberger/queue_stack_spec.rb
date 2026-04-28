# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::QueueStack do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::QueueStack::VERSION).not_to be_nil
    end
  end

  describe 'ClosedError' do
    it 'is a subclass of Error' do
      expect(Philiprehberger::QueueStack::ClosedError).to be < Philiprehberger::QueueStack::Error
    end
  end
end

RSpec.describe Philiprehberger::QueueStack::Queue do
  describe '#enqueue and #dequeue' do
    it 'follows FIFO order' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      expect(q.dequeue).to eq('a')
      expect(q.dequeue).to eq('b')
      expect(q.dequeue).to eq('c')
    end
  end

  describe '#peek' do
    it 'returns the front item without removing it' do
      q = described_class.new
      q.enqueue('first')
      q.enqueue('second')
      expect(q.peek).to eq('first')
      expect(q.size).to eq(2)
    end

    it 'returns nil when empty' do
      q = described_class.new
      expect(q.peek).to be_nil
    end
  end

  describe '#peek_at' do
    it 'returns the same item as #peek for index 0' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      expect(q.peek_at(0)).to eq(q.peek)
      expect(q.peek_at(0)).to eq('a')
    end

    it 'returns the second item in enqueue order for index 1' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      expect(q.peek_at(1)).to eq('b')
    end

    it 'returns the last item for index -1' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      expect(q.peek_at(-1)).to eq('c')
    end

    it 'returns nil when the index is out of range (positive)' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      expect(q.peek_at(5)).to be_nil
    end

    it 'returns nil when the negative index is beyond -size' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      expect(q.peek_at(-3)).to be_nil
    end

    it 'returns nil on an empty queue' do
      q = described_class.new
      expect(q.peek_at(0)).to be_nil
      expect(q.peek_at(-1)).to be_nil
    end

    it 'does not mutate the queue' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      q.peek_at(0)
      q.peek_at(1)
      q.peek_at(-1)
      q.peek_at(99)
      expect(q.size).to eq(3)
      expect(q.to_a).to eq(%w[a b c])
    end
  end

  describe '#size' do
    it 'tracks the number of items' do
      q = described_class.new
      expect(q.size).to eq(0)
      q.enqueue('a')
      expect(q.size).to eq(1)
      q.dequeue
      expect(q.size).to eq(0)
    end
  end

  describe '#empty?' do
    it 'returns true when empty' do
      expect(described_class.new.empty?).to be true
    end

    it 'returns false when not empty' do
      q = described_class.new
      q.enqueue('a')
      expect(q.empty?).to be false
    end
  end

  describe '#full?' do
    it 'returns true when at capacity' do
      q = described_class.new(capacity: 2)
      q.enqueue('a')
      q.enqueue('b')
      expect(q.full?).to be true
    end

    it 'returns false when below capacity' do
      q = described_class.new(capacity: 5)
      q.enqueue('a')
      expect(q.full?).to be false
    end

    it 'returns false when no capacity limit' do
      q = described_class.new
      expect(q.full?).to be false
    end
  end

  describe '#try_dequeue' do
    it 'returns item when available' do
      q = described_class.new
      q.enqueue('item')
      expect(q.try_dequeue(timeout: 0.1)).to eq('item')
    end

    it 'returns nil on timeout' do
      q = described_class.new
      expect(q.try_dequeue(timeout: 0.05)).to be_nil
    end
  end

  describe '#dequeue_if' do
    it 'removes and returns the front item when the block is truthy' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      result = q.dequeue_if { |item| item == 'a' }
      expect(result).to eq('a')
      expect(q.size).to eq(1)
      expect(q.peek).to eq('b')
    end

    it 'leaves the item in place and returns nil when the block is falsy' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      result = q.dequeue_if { |_item| false }
      expect(result).to be_nil
      expect(q.size).to eq(2)
      expect(q.peek).to eq('a')
    end

    it 'returns nil immediately on an empty queue without calling the block' do
      q = described_class.new
      called = false
      start = Time.now
      result = q.dequeue_if do |_item|
        called = true
        true
      end
      expect(result).to be_nil
      expect(called).to be(false)
      expect(Time.now - start).to be < 0.05
    end

    it 'yields the item that would be dequeued (front of the queue)' do
      q = described_class.new
      q.enqueue('first')
      q.enqueue('second')
      yielded = nil
      q.dequeue_if do |item|
        yielded = item
        false
      end
      expect(yielded).to eq('first')
    end

    it 'returns nil on a closed empty queue' do
      q = described_class.new
      q.close
      expect(q.dequeue_if { |_| true }).to be_nil
    end

    it 'still dequeues remaining items on a closed queue when the block is truthy' do
      q = described_class.new
      q.enqueue('a')
      q.close
      expect(q.dequeue_if { |_| true }).to eq('a')
      expect(q.size).to eq(0)
    end

    it 'is thread-safe: only one of many competing callers removes a given item' do
      q = described_class.new
      q.enqueue('shared')

      winners = []
      mutex = Mutex.new

      threads = 10.times.map do
        Thread.new do
          result = q.dequeue_if { |_| true }
          mutex.synchronize { winners << result } if result
        end
      end

      threads.each(&:join)

      expect(winners.compact.length).to eq(1)
      expect(q.size).to eq(0)
    end
  end

  describe '#drain' do
    it 'returns all items in FIFO order' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      expect(q.drain).to eq(%w[a b c])
    end

    it 'leaves the queue empty' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.drain
      expect(q.empty?).to be true
      expect(q.size).to eq(0)
    end

    it 'returns empty array on empty queue' do
      q = described_class.new
      expect(q.drain).to eq([])
    end
  end

  describe '#each' do
    it 'iterates items in FIFO order without removing them' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      collected = q.map { |item| item }
      expect(collected).to eq(%w[a b c])
      expect(q.size).to eq(3)
    end

    it 'returns an Enumerator when no block is given' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      enum = q.each
      expect(enum).to be_a(Enumerator)
      expect(enum.to_a).to eq(%w[a b])
    end
  end

  describe '#to_a' do
    it 'returns a snapshot in FIFO order' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.enqueue('c')
      expect(q.to_a).to eq(%w[a b c])
    end

    it 'does not modify the queue' do
      q = described_class.new
      q.enqueue('x')
      q.to_a
      expect(q.size).to eq(1)
    end
  end

  describe '#close and #closed?' do
    it 'starts as not closed' do
      q = described_class.new
      expect(q.closed?).to be false
    end

    it 'marks queue as closed' do
      q = described_class.new
      q.close
      expect(q.closed?).to be true
    end

    it 'raises ClosedError on enqueue after close' do
      q = described_class.new
      q.close
      expect { q.enqueue('x') }.to raise_error(Philiprehberger::QueueStack::ClosedError)
    end

    it 'allows dequeuing remaining items after close' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.close
      expect(q.dequeue).to eq('a')
      expect(q.dequeue).to eq('b')
    end

    it 'returns nil from dequeue when closed and empty' do
      q = described_class.new
      q.close
      expect(q.dequeue).to be_nil
    end

    it 'returns nil from try_dequeue when closed and empty' do
      q = described_class.new
      q.close
      expect(q.try_dequeue(timeout: 0.1)).to be_nil
    end

    it 'allows drain after close' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.close
      expect(q.drain).to eq(%w[a b])
      expect(q.empty?).to be true
    end

    it 'drain on closed empty queue returns empty array' do
      q = described_class.new
      q.close
      expect(q.drain).to eq([])
    end

    it 'wakes waiting threads on close' do
      q = described_class.new
      result = nil
      thread = Thread.new { result = q.dequeue }
      sleep 0.05
      q.close
      thread.join(1)
      expect(result).to be_nil
    end
  end

  describe 'thread safety' do
    it 'handles concurrent enqueue and dequeue' do
      q = described_class.new(capacity: 10)
      results = []
      mutex = Mutex.new

      producers = 3.times.map do |i|
        Thread.new do
          10.times { |j| q.enqueue("#{i}-#{j}") }
        end
      end

      consumers = 3.times.map do
        Thread.new do
          10.times do
            item = q.try_dequeue(timeout: 1)
            mutex.synchronize { results << item } if item
          end
        end
      end

      producers.each(&:join)
      consumers.each(&:join)

      expect(results.length).to eq(30)
    end
  end

  describe 'FIFO ordering with many items' do
    it 'preserves insertion order for 20 items' do
      q = described_class.new
      (1..20).each { |i| q.enqueue(i) }
      results = 20.times.map { q.dequeue }
      expect(results).to eq((1..20).to_a)
    end
  end

  describe '#peek without removing' do
    it 'does not change size after multiple peeks' do
      q = described_class.new
      q.enqueue('x')
      q.enqueue('y')
      5.times { q.peek }
      expect(q.size).to eq(2)
      expect(q.peek).to eq('x')
    end
  end

  describe 'empty queue operations' do
    it 'peek returns nil on empty queue' do
      q = described_class.new
      expect(q.peek).to be_nil
    end

    it 'try_dequeue returns nil on empty queue' do
      q = described_class.new
      expect(q.try_dequeue(timeout: 0.01)).to be_nil
    end

    it 'size is zero on empty queue' do
      q = described_class.new
      expect(q.size).to eq(0)
    end

    it 'empty? is true on new queue' do
      q = described_class.new
      expect(q.empty?).to be true
    end

    it 'full? is false on empty queue with capacity' do
      q = described_class.new(capacity: 5)
      expect(q.full?).to be false
    end
  end

  describe 'size tracking' do
    it 'tracks size through enqueue and dequeue cycles' do
      q = described_class.new
      5.times { |i| q.enqueue(i) }
      expect(q.size).to eq(5)
      3.times { q.dequeue }
      expect(q.size).to eq(2)
      2.times { |i| q.enqueue(i) }
      expect(q.size).to eq(4)
    end
  end

  describe '#capacity and #remaining_capacity' do
    it 'returns nil for an unlimited queue' do
      q = described_class.new
      expect(q.capacity).to be_nil
      expect(q.remaining_capacity).to be_nil
    end

    it 'returns the configured capacity for a bounded queue' do
      q = described_class.new(capacity: 5)
      expect(q.capacity).to eq(5)
    end

    it 'tracks remaining_capacity after enqueue and dequeue' do
      q = described_class.new(capacity: 3)
      expect(q.remaining_capacity).to eq(3)
      q.enqueue('a')
      expect(q.remaining_capacity).to eq(2)
      q.enqueue('b')
      q.enqueue('c')
      expect(q.remaining_capacity).to eq(0)
      q.dequeue
      expect(q.remaining_capacity).to eq(1)
    end

    it 'returns 0 for remaining_capacity when at capacity' do
      q = described_class.new(capacity: 1)
      q.enqueue('a')
      expect(q.full?).to be(true)
      expect(q.remaining_capacity).to eq(0)
    end
  end
end

RSpec.describe Philiprehberger::QueueStack::Stack do
  describe '#push and #pop' do
    it 'follows LIFO order' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.push('c')
      expect(s.pop).to eq('c')
      expect(s.pop).to eq('b')
      expect(s.pop).to eq('a')
    end
  end

  describe '#peek' do
    it 'returns the top item without removing it' do
      s = described_class.new
      s.push('first')
      s.push('second')
      expect(s.peek).to eq('second')
      expect(s.size).to eq(2)
    end

    it 'returns nil when empty' do
      s = described_class.new
      expect(s.peek).to be_nil
    end
  end

  describe '#size' do
    it 'tracks the number of items' do
      s = described_class.new
      expect(s.size).to eq(0)
      s.push('a')
      expect(s.size).to eq(1)
      s.pop
      expect(s.size).to eq(0)
    end
  end

  describe '#empty?' do
    it 'returns true when empty' do
      expect(described_class.new.empty?).to be true
    end

    it 'returns false when not empty' do
      s = described_class.new
      s.push('a')
      expect(s.empty?).to be false
    end
  end

  describe '#full?' do
    it 'returns true when at capacity' do
      s = described_class.new(capacity: 2)
      s.push('a')
      s.push('b')
      expect(s.full?).to be true
    end

    it 'returns false when below capacity' do
      s = described_class.new(capacity: 5)
      s.push('a')
      expect(s.full?).to be false
    end

    it 'returns false when no capacity limit' do
      s = described_class.new
      expect(s.full?).to be false
    end
  end

  describe '#try_pop' do
    it 'returns item when available' do
      s = described_class.new
      s.push('item')
      expect(s.try_pop(timeout: 0.1)).to eq('item')
    end

    it 'returns nil on timeout' do
      s = described_class.new
      expect(s.try_pop(timeout: 0.05)).to be_nil
    end
  end

  describe '#pop_if' do
    it 'removes and returns the top item when the block is truthy' do
      s = described_class.new
      s.push('a')
      s.push('b')
      result = s.pop_if { |item| item == 'b' }
      expect(result).to eq('b')
      expect(s.size).to eq(1)
      expect(s.peek).to eq('a')
    end

    it 'leaves the item in place and returns nil when the block is falsy' do
      s = described_class.new
      s.push('a')
      s.push('b')
      result = s.pop_if { |_item| false }
      expect(result).to be_nil
      expect(s.size).to eq(2)
      expect(s.peek).to eq('b')
    end

    it 'returns nil immediately on an empty stack without calling the block' do
      s = described_class.new
      called = false
      start = Time.now
      result = s.pop_if do |_item|
        called = true
        true
      end
      expect(result).to be_nil
      expect(called).to be(false)
      expect(Time.now - start).to be < 0.05
    end

    it 'yields the item that would be popped (top of the stack)' do
      s = described_class.new
      s.push('bottom')
      s.push('top')
      yielded = nil
      s.pop_if do |item|
        yielded = item
        false
      end
      expect(yielded).to eq('top')
    end

    it 'returns nil on a closed empty stack' do
      s = described_class.new
      s.close
      expect(s.pop_if { |_| true }).to be_nil
    end

    it 'still pops remaining items on a closed stack when the block is truthy' do
      s = described_class.new
      s.push('a')
      s.close
      expect(s.pop_if { |_| true }).to eq('a')
      expect(s.size).to eq(0)
    end

    it 'is thread-safe: only one of many competing callers removes a given item' do
      s = described_class.new
      s.push('shared')

      winners = []
      mutex = Mutex.new

      threads = 10.times.map do
        Thread.new do
          result = s.pop_if { |_| true }
          mutex.synchronize { winners << result } if result
        end
      end

      threads.each(&:join)

      expect(winners.compact.length).to eq(1)
      expect(s.size).to eq(0)
    end
  end

  describe '#drain' do
    it 'returns all items in LIFO order (top first)' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.push('c')
      expect(s.drain).to eq(%w[c b a])
    end

    it 'leaves the stack empty' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.drain
      expect(s.empty?).to be true
      expect(s.size).to eq(0)
    end

    it 'returns empty array on empty stack' do
      s = described_class.new
      expect(s.drain).to eq([])
    end
  end

  describe '#each' do
    it 'iterates items in LIFO order without removing them' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.push('c')
      collected = s.map { |item| item }
      expect(collected).to eq(%w[c b a])
      expect(s.size).to eq(3)
    end

    it 'returns an Enumerator when no block is given' do
      s = described_class.new
      s.push('a')
      s.push('b')
      enum = s.each
      expect(enum).to be_a(Enumerator)
      expect(enum.to_a).to eq(%w[b a])
    end
  end

  describe '#to_a' do
    it 'returns a snapshot in LIFO order (top first)' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.push('c')
      expect(s.to_a).to eq(%w[c b a])
    end

    it 'does not modify the stack' do
      s = described_class.new
      s.push('x')
      s.to_a
      expect(s.size).to eq(1)
    end
  end

  describe '#close and #closed?' do
    it 'starts as not closed' do
      s = described_class.new
      expect(s.closed?).to be false
    end

    it 'marks stack as closed' do
      s = described_class.new
      s.close
      expect(s.closed?).to be true
    end

    it 'raises ClosedError on push after close' do
      s = described_class.new
      s.close
      expect { s.push('x') }.to raise_error(Philiprehberger::QueueStack::ClosedError)
    end

    it 'allows popping remaining items after close' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.close
      expect(s.pop).to eq('b')
      expect(s.pop).to eq('a')
    end

    it 'returns nil from pop when closed and empty' do
      s = described_class.new
      s.close
      expect(s.pop).to be_nil
    end

    it 'returns nil from try_pop when closed and empty' do
      s = described_class.new
      s.close
      expect(s.try_pop(timeout: 0.1)).to be_nil
    end

    it 'allows drain after close' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.close
      expect(s.drain).to eq(%w[b a])
      expect(s.empty?).to be true
    end

    it 'drain on closed empty stack returns empty array' do
      s = described_class.new
      s.close
      expect(s.drain).to eq([])
    end

    it 'wakes waiting threads on close' do
      s = described_class.new
      result = nil
      thread = Thread.new { result = s.pop }
      sleep 0.05
      s.close
      thread.join(1)
      expect(result).to be_nil
    end
  end

  describe 'thread safety' do
    it 'handles concurrent push and pop' do
      s = described_class.new(capacity: 10)
      results = []
      mutex = Mutex.new

      producers = 3.times.map do |i|
        Thread.new do
          10.times { |j| s.push("#{i}-#{j}") }
        end
      end

      consumers = 3.times.map do
        Thread.new do
          10.times do
            item = s.try_pop(timeout: 1)
            mutex.synchronize { results << item } if item
          end
        end
      end

      producers.each(&:join)
      consumers.each(&:join)

      expect(results.length).to eq(30)
    end
  end

  describe 'LIFO ordering with many items' do
    it 'returns items in reverse insertion order' do
      s = described_class.new
      (1..10).each { |i| s.push(i) }
      results = 10.times.map { s.pop }
      expect(results).to eq((1..10).to_a.reverse)
    end
  end

  describe '#peek without removing' do
    it 'does not change size after multiple peeks' do
      s = described_class.new
      s.push('x')
      s.push('y')
      5.times { s.peek }
      expect(s.size).to eq(2)
      expect(s.peek).to eq('y')
    end
  end

  describe 'empty stack operations' do
    it 'peek returns nil on empty stack' do
      s = described_class.new
      expect(s.peek).to be_nil
    end

    it 'try_pop returns nil on empty stack' do
      s = described_class.new
      expect(s.try_pop(timeout: 0.01)).to be_nil
    end

    it 'size is zero on empty stack' do
      s = described_class.new
      expect(s.size).to eq(0)
    end

    it 'empty? is true on new stack' do
      s = described_class.new
      expect(s.empty?).to be true
    end

    it 'full? is false on empty stack with capacity' do
      s = described_class.new(capacity: 5)
      expect(s.full?).to be false
    end
  end

  describe Philiprehberger::QueueStack::Queue, '#try_enqueue and #clear' do
    it 'returns true when there is room' do
      q = described_class.new(capacity: 2)
      expect(q.try_enqueue('a')).to be true
      expect(q.size).to eq(1)
    end

    it 'returns false immediately when full and no timeout' do
      q = described_class.new(capacity: 1)
      q.enqueue('a')
      expect(q.try_enqueue('b')).to be false
      expect(q.size).to eq(1)
    end

    it 'returns false after waiting up to timeout when full' do
      q = described_class.new(capacity: 1)
      q.enqueue('a')
      start = Time.now
      expect(q.try_enqueue('b', timeout: 0.05)).to be false
      expect(Time.now - start).to be >= 0.04
    end

    it 'succeeds within timeout when space frees up' do
      q = described_class.new(capacity: 1)
      q.enqueue('a')
      Thread.new do
  sleep 0.02
  q.dequeue
end
      expect(q.try_enqueue('b', timeout: 1)).to be true
    end

    it 'raises ClosedError when closed' do
      q = described_class.new
      q.close
      expect { q.try_enqueue('a') }.to raise_error(Philiprehberger::QueueStack::ClosedError)
    end

    it 'unblocks producers via clear' do
      q = described_class.new(capacity: 1)
      q.enqueue('a')
      Thread.new do
  sleep 0.02
  q.clear
end
      expect(q.try_enqueue('b', timeout: 1)).to be true
      expect(q.size).to eq(1)
    end

    it 'clear empties the queue' do
      q = described_class.new
      q.enqueue('a')
      q.enqueue('b')
      q.clear
      expect(q.empty?).to be true
    end
  end

  describe Philiprehberger::QueueStack::Stack, '#try_push and #clear' do
    it 'returns true when there is room' do
      s = described_class.new(capacity: 2)
      expect(s.try_push('a')).to be true
      expect(s.size).to eq(1)
    end

    it 'returns false immediately when full and no timeout' do
      s = described_class.new(capacity: 1)
      s.push('a')
      expect(s.try_push('b')).to be false
      expect(s.size).to eq(1)
    end

    it 'returns false after waiting up to timeout when full' do
      s = described_class.new(capacity: 1)
      s.push('a')
      start = Time.now
      expect(s.try_push('b', timeout: 0.05)).to be false
      expect(Time.now - start).to be >= 0.04
    end

    it 'succeeds within timeout when space frees up' do
      s = described_class.new(capacity: 1)
      s.push('a')
      Thread.new do
  sleep 0.02
  s.pop
end
      expect(s.try_push('b', timeout: 1)).to be true
    end

    it 'raises ClosedError when closed' do
      s = described_class.new
      s.close
      expect { s.try_push('a') }.to raise_error(Philiprehberger::QueueStack::ClosedError)
    end

    it 'clear empties the stack' do
      s = described_class.new
      s.push('a')
      s.push('b')
      s.clear
      expect(s.empty?).to be true
    end
  end

  describe '#capacity and #remaining_capacity' do
    it 'returns nil for an unlimited stack' do
      s = described_class.new
      expect(s.capacity).to be_nil
      expect(s.remaining_capacity).to be_nil
    end

    it 'returns the configured capacity for a bounded stack' do
      s = described_class.new(capacity: 4)
      expect(s.capacity).to eq(4)
    end

    it 'tracks remaining_capacity after push and pop' do
      s = described_class.new(capacity: 3)
      expect(s.remaining_capacity).to eq(3)
      s.push('a')
      expect(s.remaining_capacity).to eq(2)
      s.push('b')
      s.push('c')
      expect(s.remaining_capacity).to eq(0)
      s.pop
      expect(s.remaining_capacity).to eq(1)
    end

    it 'returns 0 for remaining_capacity when at capacity' do
      s = described_class.new(capacity: 1)
      s.push('a')
      expect(s.full?).to be(true)
      expect(s.remaining_capacity).to eq(0)
    end
  end
end
