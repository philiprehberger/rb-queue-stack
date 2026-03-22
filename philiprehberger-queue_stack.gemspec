# frozen_string_literal: true

require_relative 'lib/philiprehberger/queue_stack/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-queue_stack'
  spec.version       = Philiprehberger::QueueStack::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Thread-safe Queue and Stack with capacity limits and blocking operations'
  spec.description   = 'Thread-safe queue and stack data structures with configurable capacity ' \
                       'limits, blocking enqueue/dequeue with timeouts, and peek operations. ' \
                       'Uses Mutex and ConditionVariable for safe concurrent access.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-queue-stack'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
