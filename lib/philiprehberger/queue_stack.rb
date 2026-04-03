# frozen_string_literal: true

require_relative 'queue_stack/version'
require_relative 'queue_stack/queue'
require_relative 'queue_stack/stack'

module Philiprehberger
  module QueueStack
    class Error < StandardError; end
    class ClosedError < Error; end
  end
end
