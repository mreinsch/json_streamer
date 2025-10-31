# frozen_string_literal: true

module JsonStreamer
  # Oj SAJ (Simple API for JSON) handler for extracting a single top-level key from JSON
  # Properly handles nested hashes and arrays within the extracted value
  class SajHeaderExtractor
    attr_reader :result

    def initialize(target_key:)
      @target_key = target_key
      @result = nil
      @builder = Builder.new
      @condition = HeaderCondition.new(target_key:)
    end

    def found
      @condition.found
    end

    def hash_start(key)
      if @condition.should_capture_object?(key)
        @result = {}
        @condition.start_capturing
        @builder.push(@result)
      elsif @condition.capturing?
        nested_hash = {}
        @builder.add_value(nested_hash, key)
        @builder.push(nested_hash)
      end
    end

    def hash_end(_key)
      return unless @condition.capturing?

      @builder.end_container
      @condition.container_ended(@builder)
    end

    def array_start(key)
      if @condition.should_capture_array?(key)
        @result = []
        @condition.start_capturing
        @builder.push(@result)
      elsif @condition.capturing?
        nested_array = []
        @builder.add_value(nested_array, key)
        @builder.push(nested_array)
      end
    end

    def array_end(_key)
      return unless @condition.capturing?

      @builder.end_container
      @condition.container_ended(@builder)
    end

    # Oj SAJ callback - receives value with key context
    # Signature: add_value(value, key, *_rest)
    def add_value(value, key, *_rest)
      if @condition.should_capture_value?(key)
        @result = value
        @condition.start_capturing
      elsif @condition.capturing?
        @builder.add_value(value, key)
      end
    end
  end
end
