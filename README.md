# philiprehberger-queue_stack

[![Tests](https://github.com/philiprehberger/rb-queue-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-queue-stack/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-queue_stack.svg)](https://rubygems.org/gems/philiprehberger-queue_stack)
[![License](https://img.shields.io/github/license/philiprehberger/rb-queue-stack)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Thread-safe Queue and Stack with capacity limits and blocking operations

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-queue_stack"
```

Or install directly:

```bash
gem install philiprehberger-queue_stack
```

## Usage

```ruby
require "philiprehberger/queue_stack"

q = Philiprehberger::QueueStack::Queue.new(capacity: 100)
q.enqueue('task')
item = q.dequeue  # => 'task'
```

### Queue (FIFO)

```ruby
q = Philiprehberger::QueueStack::Queue.new(capacity: 10)
q.enqueue('first')
q.enqueue('second')
q.dequeue   # => 'first'
q.peek      # => 'second'
q.size      # => 1
```

### Stack (LIFO)

```ruby
s = Philiprehberger::QueueStack::Stack.new(capacity: 10)
s.push('first')
s.push('second')
s.pop       # => 'second'
s.peek      # => 'first'
s.size      # => 1
```

### Blocking with Timeout

```ruby
q = Philiprehberger::QueueStack::Queue.new
item = q.try_dequeue(timeout: 5)  # waits up to 5 seconds

s = Philiprehberger::QueueStack::Stack.new
item = s.try_pop(timeout: 5)  # waits up to 5 seconds
```

### Capacity Limits

```ruby
q = Philiprehberger::QueueStack::Queue.new(capacity: 3)
q.full?   # => false
3.times { |i| q.enqueue(i) }
q.full?   # => true
# enqueue blocks until space is available
```

## API

### `Queue`

| Method | Description |
|--------|-------------|
| `.new(capacity:)` | Create a queue with optional capacity limit |
| `#enqueue(item)` | Add item to back (blocks if full) |
| `#dequeue` | Remove and return front item (blocks if empty) |
| `#try_dequeue(timeout:)` | Dequeue with timeout, returns nil on timeout |
| `#peek` | View front item without removing |
| `#size` | Number of items |
| `#empty?` | Whether the queue is empty |
| `#full?` | Whether the queue is at capacity |

### `Stack`

| Method | Description |
|--------|-------------|
| `.new(capacity:)` | Create a stack with optional capacity limit |
| `#push(item)` | Push item on top (blocks if full) |
| `#pop` | Remove and return top item (blocks if empty) |
| `#try_pop(timeout:)` | Pop with timeout, returns nil on timeout |
| `#peek` | View top item without removing |
| `#size` | Number of items |
| `#empty?` | Whether the stack is empty |
| `#full?` | Whether the stack is at capacity |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
