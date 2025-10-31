# frozen_string_literal: true

module JsonStreamer
  # Oj SAJ (Simple API for JSON) handler for true streaming of large JSON arrays
  # Processes array items one at a time without building complete data structures in memory
  # Properly handles nested hashes and arrays within each item
  # Supports both nesting_level and key-based filtering
  class SajArrayHandler
    def initialize(yielder:, nesting_level: nil, key: nil)
      @yielder = yielder
      @builder = Builder.new
      @condition = Condition.new(target_level: nesting_level, target_key: key)
    end

    def hash_start(key)
      if @condition.should_start_item?(@builder)
        @builder.start_object
      elsif !@builder.empty?
        nested_hash = {}
        @builder.add_value(nested_hash, key)
        @builder.push(nested_hash)
      end
    end

    def hash_end(_key)
      return if @builder.empty?

      completed = @builder.end_container
      @yielder.yield(completed) if @condition.should_yield_item?(@builder)
    end

    def array_start(key)
      @condition.array_started(key)

      return if @builder.empty?
      nested_array = []
      @builder.add_value(nested_array, key)
      @builder.push(nested_array)
    end

    def array_end(key)
      @builder.end_container if !@builder.empty? && @builder.current_container.is_a?(Array)
      @condition.array_ended(key)
    end

    # Oj SAJ callback - receives value with key context
    # Signature: add_value(value, key, *_rest)
    def add_value(value, key, *_rest)
      @builder.add_value(value, key)
    end
  end
end
