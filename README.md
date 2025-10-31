# JsonStreamer

JsonStreamer - Memory-efficient JSON file processing for large datasets

This gem is inspired by https://github.com/thisismydesign/json-streamer.

This implementation is backed by [Oj](https://github.com/ohler55/oj) and provides streaming parsing of JSON files using Oj's SAJ (Simple API for JSON) parser.
Unlike traditional JSON parsers that load the entire document into memory, this implementation:

1. Reads files in chunks using Oj::Parser#file (internally buffered)
2. Processes events as they occur (hash_start, array_start, add_value, etc.)
3. Never builds complete data structures for the entire document
4. Yields individual array items one at a time through an Enumerator

Memory Efficiency Example:
- 40 MB JSON file with 50,000 items
- Traditional parsing: ~40 MB memory increase
- JsonStreamer: ~5 MB memory increase (12% of file size)

## Usage

```ruby
# Stream array items from {"items": [{...}, {...}]}
JsonStreamer.load('data.json', key: 'items').each do |item|
  process(item)  # Each item processed without loading all items
end

# Stream top-level array: [{...}, {...}]
JsonStreamer.load('data.json', nesting_level: 1).each { |item| ... }

# Extract header value without loading large nested arrays
report_date = JsonStreamer.extract_header('data.json', key: 'reportDate')
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mreinsch/json_streamer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
