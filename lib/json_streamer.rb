# frozen_string_literal: true

require 'oj'
require 'pathname'
require_relative "json_streamer/builder"
require_relative "json_streamer/condition"
require_relative "json_streamer/header_condition"
require_relative "json_streamer/saj_array_handler"
require_relative "json_streamer/saj_header_handler"
require_relative "json_streamer/version"

# JsonStreamer - Memory-efficient JSON file processing for large datasets
module JsonStreamer
  extend self

  class Error < StandardError; end

  class UnsupportedDateFile < StandardError; end

  # Internal exception used to signal producer thread to stop when consumer exits early
  class StopStream < StandardError; end

  # Sentinel object used to signal end-of-stream between producer thread and consumer enumerator
  STREAM_END = Object.new.freeze

  # Load a JSON file using streaming SAJ parser
  # Returns a lazy enumerator that yields objects from the JSON structure without
  # loading the entire file or array into memory at once
  #
  # @param data_file [String, Pathname] Path to the JSON file
  # @param nesting_level [Integer, nil] Capture array items at specific nesting depth (e.g., 1 for top-level array)
  # @param key [String, nil] Capture array from specific hash key
  # @return [Enumerator::Lazy] Lazy enumerator of parsed JSON objects
  def load(data_file, nesting_level: nil, key: nil) # rubocop:disable Metrics/MethodLength
    Enumerator.new do |yielder|
      queue = SizedQueue.new(100)
      producer = start_producer(data_file, nesting_level:, key:, queue:)

      begin
        loop do
          item = queue.pop
          break if item.equal?(STREAM_END)
          raise item if item.is_a?(Exception)
          yielder << item
        end
      ensure
        producer.raise(StopStream) rescue nil # rubocop:disable Style/RescueModifier
        queue.clear
        producer.join
      end
    end.lazy
  end

  # Extract a single top-level key from a JSON file using streaming parser
  # Parsing continues to completion but all callbacks become no-ops once the value is found
  #
  # @param data_file [String, Pathname] Path to the JSON file
  # @param key [String] The top-level key to extract
  # @return [Object, nil] The extracted value, or nil if the key is not present
  def extract_header(data_file, key:)
    queue = SizedQueue.new(1)
    producer = start_header_producer(data_file, key:, queue:)
    item = queue.pop
    producer.join
    return nil if item.equal?(STREAM_END)
    raise item if item.is_a?(Exception)

    item
  end

  private

  def ruby_file_to_str(data_file)
    case data_file
    when File then data_file.path || raise(UnsupportedDateFile, 'File without path is not supported')
    when Pathname then data_file.to_s
    when String then data_file
    else raise UnsupportedDateFile, "date_file should be String, File or Pathname"
    end
  end

  def start_header_producer(data_file, key:, queue:) # rubocop:disable Metrics/MethodLength
    Thread.new do
      handler = SajHeaderExtractor.new(target_key: key, queue:)
      parser = Oj::Parser.new(:saj)
      parser.handler = handler
      sent = false
      begin
        parser.file(ruby_file_to_str(data_file))
      rescue StandardError => e
        unless handler.done
          queue.push(e)
          sent = true
        end
      ensure
        queue.push(STREAM_END) unless handler.done || sent
      end
    end
  end

  def start_producer(data_file, nesting_level:, key:, queue:) # rubocop:disable Metrics/MethodLength
    Thread.new do
      stop_requested = false
      handler = SajArrayHandler.new(nesting_level:, key:, queue:)
      parser = Oj::Parser.new(:saj)
      parser.handler = handler
      begin
        parser.file(ruby_file_to_str(data_file))
      rescue StopStream
        stop_requested = true
      rescue StandardError => e
        queue.push(e)
      ensure
        queue.push(STREAM_END) unless stop_requested
      end
    end
  end
end
