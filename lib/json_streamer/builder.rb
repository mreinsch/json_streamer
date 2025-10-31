# frozen_string_literal: true

require 'forwardable'

module JsonStreamer
  # Builder - manages the stack of containers being built during JSON parsing
  # Separates the concern of object construction from condition checking
  class Builder
    extend Forwardable

    def_delegators :@stack, :empty?, :last, :pop

    def initialize
      @stack = []
    end

    def level
      @stack.size
    end

    def current_container
      @stack.last
    end

    def push(container)
      @stack << container
    end

    def start_object
      @stack << {}
    end

    def start_array
      @stack << []
    end

    def add_value(value, key)
      return if @stack.empty?

      container = @stack.last
      if container.is_a?(Hash) && key
        container[key] = value
      elsif container.is_a?(Array)
        container << value
      end
    end

    def end_container
      @stack.pop
    end
  end
end
