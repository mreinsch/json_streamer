# frozen_string_literal: true

require 'oj'
require_relative "json_streamer/builder"
require_relative "json_streamer/condition"
require_relative "json_streamer/header_condition"
require_relative "json_streamer/saj_array_handler"
require_relative "json_streamer/saj_header_handler"
require_relative "json_streamer/version"

# JsonStreamer - Memory-efficient JSON file processing for large datasets
module JsonStreamer
  class Error < StandardError; end

  # Load a JSON file using streaming SAJ parser
  # Returns a lazy enumerator that yields objects from the JSON structure without
  # loading the entire file or array into memory at once
  #
  # @param data_file [String, Pathname] Path to the JSON file
  # @param nesting_level [Integer, nil] Capture array items at specific nesting depth (e.g., 1 for top-level array)
  # @param key [String, nil] Capture array from specific hash key
  # @return [Enumerator::Lazy] Lazy enumerator of parsed JSON objects
  def self.load(data_file, nesting_level: nil, key: nil)
    Enumerator.new do |yielder|
      handler = SajArrayHandler.new(nesting_level:, key:, yielder:)
      parser = Oj::Parser.new(:saj)
      parser.handler = handler
      parser.file(data_file.to_s)
    end.lazy
  end

  # Extract a single top-level key from a JSON file using streaming parser
  # Avoids loading large arrays when extracting scalar header values
  #
  # @param data_file [String, Pathname] Path to the JSON file
  # @param key [String] The top-level key to extract
  # @return [Object] The extracted value (string, number, array, hash, etc.)
  def self.extract_header(data_file, key:)
    handler = SajHeaderExtractor.new(target_key: key)
    parser = Oj::Parser.new(:saj)
    parser.handler = handler
    parser.file(data_file.to_s)
    handler.result
  end
end
