# frozen_string_literal: true

module JsonStreamer
  # HeaderCondition - determines when to capture a specific top-level key
  # Tracks whether we're at root level and whether we've found our target
  class HeaderCondition
    attr_reader :found

    def initialize(target_key:)
      @target_key = target_key
      @found = false
      @root_level = true
      @capturing = false
    end

    def should_capture_object?(key)
      @root_level && key == @target_key
    end

    def should_capture_array?(key)
      @root_level && key == @target_key
    end

    def should_capture_value?(key)
      @root_level && key == @target_key
    end

    def capturing?
      @capturing
    end

    def start_capturing
      @capturing = true
      @found = true
      @root_level = false
    end

    def container_ended(builder)
      return unless @capturing

      return unless builder.empty?
      @capturing = false
      @root_level = true
    end

    def extraction_complete?
      @found && !@capturing && @root_level
    end
  end
end
