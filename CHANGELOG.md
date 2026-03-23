# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage to 36 examples

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Thread-safe FIFO Queue with enqueue, dequeue, peek, and size
- Thread-safe LIFO Stack with push, pop, peek, and size
- Configurable capacity limits for both Queue and Stack
- Blocking operations that wait when empty or at capacity
- Timeout-based try_dequeue and try_pop operations
- Empty and full status checks
- Mutex and ConditionVariable for thread-safe access
