# frozen_string_literal: true

module JsonStreamer
  # Condition - determines when we're inside a target array and when to yield items
  # Handles both level-based (nesting_level) and key-based targeting
  class Condition
    def initialize(target_level: nil, target_key: nil)
      @target_level = target_level
      @target_key = target_key
      @array_depth = 0
      @inside_target = false
    end

    def array_started(key)
      @array_depth += 1
      @inside_target = true if target_matched?(key)
    end

    def array_ended(key)
      @inside_target = false if target_matched?(key)
      @array_depth -= 1
    end

    def inside_target?
      @inside_target
    end

    def should_start_item?(builder)
      @inside_target && builder.empty?
    end

    def should_yield_item?(builder)
      @inside_target && builder.empty?
    end

    private

    def target_matched?(key)
      (@target_key && key == @target_key) || (@target_level && @array_depth == @target_level)
    end
  end
end
