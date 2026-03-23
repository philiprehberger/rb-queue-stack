# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::QueueStack do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::QueueStack::VERSION).not_to be_nil
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
end
