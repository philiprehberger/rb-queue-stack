# philiprehberger-queue_stack

[![Tests](https://github.com/philiprehberger/rb-queue-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-queue-stack/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-queue_stack.svg)](https://rubygems.org/gems/philiprehberger-queue_stack)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-queue-stack)](https://github.com/philiprehberger/rb-queue-stack/commits/main)

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
q.enqueue('third')
q.peek         # => 'first'
q.peek_at(1)   # => 'second'
q.peek_at(-1)  # => 'third'
q.peek_at(99)  # => nil (out of range)
q.dequeue      # => 'first'
q.size         # => 2
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

### Drain

```ruby
q = Philiprehberger::QueueStack::Queue.new
q.enqueue('a')
q.enqueue('b')
q.enqueue('c')
q.drain  # => ['a', 'b', 'c'] (queue is now empty)

s = Philiprehberger::QueueStack::Stack.new
s.push('a')
s.push('b')
s.push('c')
s.drain  # => ['c', 'b', 'a'] (stack is now empty)
```

### Iteration

```ruby
q = Philiprehberger::QueueStack::Queue.new
q.enqueue('a')
q.enqueue('b')
q.each { |item| puts item }  # prints 'a', 'b'
q.to_a                        # => ['a', 'b'] (queue unchanged)
```

### Non-Blocking Insertion

```ruby
q = Philiprehberger::QueueStack::Queue.new(capacity: 1)
q.enqueue('a')
q.try_enqueue('b')                 # => false (full, no wait)
q.try_enqueue('b', timeout: 0.5)   # => false after waiting up to 0.5s

s = Philiprehberger::QueueStack::Stack.new(capacity: 1)
s.push('a')
s.try_push('b')                    # => false (full, no wait)
```

### Clear

```ruby
q = Philiprehberger::QueueStack::Queue.new
q.enqueue('a'); q.enqueue('b')
q.clear
q.empty?  # => true
```

### Close / Shutdown

```ruby
q = Philiprehberger::QueueStack::Queue.new
q.enqueue('a')
q.close
q.closed?     # => true
q.dequeue     # => 'a'
q.dequeue     # => nil (closed and empty)
q.enqueue('b') # raises Philiprehberger::QueueStack::ClosedError
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
| `#try_enqueue(item, timeout: nil)` | Non-blocking enqueue, returns true/false (waits up to timeout if given) |
| `#dequeue` | Remove and return front item (blocks if empty) |
| `#try_dequeue(timeout:)` | Dequeue with timeout, returns nil on timeout |
| `#clear` | Remove all items without returning them |
| `#peek` | View front item without removing |
| `#peek_at(index)` | View item at the given position (supports negative indices, returns nil if out of range) |
| `#drain` | Remove and return all items as array (FIFO order) |
| `#each` | Iterate items without removing (returns Enumerator if no block) |
| `#to_a` | Snapshot as array (FIFO order) |
| `#close` | Mark as closed (new enqueues raise `ClosedError`) |
| `#closed?` | Whether the queue has been closed |
| `#size` | Number of items |
| `#empty?` | Whether the queue is empty |
| `#full?` | Whether the queue is at capacity |

### `Stack`

| Method | Description |
|--------|-------------|
| `.new(capacity:)` | Create a stack with optional capacity limit |
| `#push(item)` | Push item on top (blocks if full) |
| `#try_push(item, timeout: nil)` | Non-blocking push, returns true/false (waits up to timeout if given) |
| `#pop` | Remove and return top item (blocks if empty) |
| `#try_pop(timeout:)` | Pop with timeout, returns nil on timeout |
| `#clear` | Remove all items without returning them |
| `#peek` | View top item without removing |
| `#drain` | Remove and return all items as array (LIFO order) |
| `#each` | Iterate items without removing (returns Enumerator if no block) |
| `#to_a` | Snapshot as array (LIFO order) |
| `#close` | Mark as closed (new pushes raise `ClosedError`) |
| `#closed?` | Whether the stack has been closed |
| `#size` | Number of items |
| `#empty?` | Whether the stack is empty |
| `#full?` | Whether the stack is at capacity |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-queue-stack)

🐛 [Report issues](https://github.com/philiprehberger/rb-queue-stack/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-queue-stack/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
