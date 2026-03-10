# frozen_string_literal: true

module JsonStreamer
  # Oj SAJ (Simple API for JSON) handler for extracting a single top-level key from JSON
  # Properly handles nested hashes and arrays within the extracted value
  # Pushes the result to a queue and sets done=true once extraction is complete,
  # then acts as a no-op for all subsequent callbacks to let Oj finish cleanly.
  class SajHeaderExtractor
    attr_reader :result, :done

    def initialize(target_key:, queue:)
      @target_key = target_key
      @result = nil
      @builder = Builder.new
      @condition = HeaderCondition.new(target_key:)
      @queue = queue
      @done = false
    end

    def hash_start(key)
      return if @done

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
      return if @done
      return unless @condition.capturing?

      @builder.end_container
      @condition.container_ended(@builder)

      return unless @condition.extraction_complete?
      @queue.push(@result)
      @done = true
    end

    def array_start(key)
      return if @done

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
      return if @done
      return unless @condition.capturing?

      @builder.end_container
      @condition.container_ended(@builder)

      return unless @condition.extraction_complete?
      @queue.push(@result)
      @done = true
    end

    # Oj SAJ callback - receives value with key context
    # Signature: add_value(value, key, *_rest)
    def add_value(value, key, *_rest)
      return if @done

      if @condition.should_capture_value?(key)
        @result = value
        @condition.start_capturing
        @queue.push(@result)
        @done = true
      elsif @condition.capturing?
        @builder.add_value(value, key)
      end
    end
  end
end
