# frozen_string_literal: true

require 'tempfile'
require 'oj'

Oj.mimic_JSON

RSpec.describe JsonStreamer do
  let(:temp_file) { Tempfile.new(['test', '.json']) }

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '.load' do
    context 'with small dataset' do
      let(:test_json_data) { items }
      let(:items) do
        [
          { 'id' => 1, 'name' => 'Alice' },
          { 'id' => 2, 'name' => 'Bob' },
          { 'id' => 3, 'name' => 'Charlie' },
        ]
      end

      before do
        temp_file.write(test_json_data.to_json)
        temp_file.rewind
      end

      context 'with top-level array (nesting_level: 1)' do
        it 'streams objects from JSON array' do
          result = described_class.load(temp_file.path, nesting_level: 1)

          expect(result).to be_a(Enumerator::Lazy)
          expect(result.to_a).to eq(items)
        end
      end

      context 'with array nested in key' do
        let(:test_json_data) { { 'status' => 'success', 'data' => items } }

        it 'extracts objects from specific key' do
          result = described_class.load(temp_file.path, key: 'data')

          expect(result.to_a).to eq(items)
        end
      end

      context 'with empty array' do
        let(:test_json_data) { [] }

        it 'returns empty result' do
          result = described_class.load(temp_file.path, nesting_level: 1)

          expect(result.to_a).to eq([])
        end
      end

      context 'with nested structures in array items' do
        let(:items) do
          [
            {
              'asin' => 'B001',
              'sales' => { 'amount' => 100.50, 'breakdown' => { 'retail' => 80.0, 'wholesale' => 20.5 } },
              'metrics' => { 'views' => 1000, 'clicks' => 50 },
            },
            {
              'asin' => 'B002',
              'sales' => { 'amount' => 250.75, 'breakdown' => { 'retail' => 200.0, 'wholesale' => 50.75 } },
              'metrics' => { 'views' => 2000, 'clicks' => 100 },
            },
          ]
        end
        let(:test_json_data) { { 'status' => 'success', 'salesData' => items } }

        it 'extracts items with deeply nested hashes' do
          result = described_class.load(temp_file.path, key: 'salesData').to_a

          expect(result).to eq(items)
        end
      end

      context 'with nested arrays in array items' do
        let(:items) do
          [
            {
              'tags' => %w[electronics featured],
              'variants' => [{ 'sku' => 'A-1', 'price' => 10.0 }, { 'sku' => 'A-2', 'price' => 15.0 }],
            },
            {
              'tags' => %w[clothing new],
              'variants' => [{ 'sku' => 'B-1', 'price' => 20.0 }],
            },
          ]
        end
        let(:test_json_data) { { 'status' => 'success', 'products' => items } }

        it 'extracts items with nested arrays' do
          result = described_class.load(temp_file.path, key: 'products').to_a

          expect(result).to eq(items)
        end
      end
    end

    context 'with large dataset' do
      before do
        temp_file.write('[')
        1000.times do |i|
          temp_file.write(',') if i > 0
          temp_file.write({ 'id' => i, 'value' => "item_#{i}" }.to_json)
        end
        temp_file.write(']')
        temp_file.rewind
      end

      it 'streams without loading entire file into memory' do
        result = described_class.load(temp_file.path, nesting_level: 1)

        expect(result.first(5).size).to eq(5)
        expect(result.first).to eq({ 'id' => 0, 'value' => 'item_0' })
      end

      it 'processes all items' do
        count = 0
        described_class.load(temp_file.path, nesting_level: 1).each { count += 1 }

        expect(count).to eq(1000)
      end
    end
  end

  describe '.extract_header' do
    before do
      temp_file.write(test_json_data.to_json)
      temp_file.rewind
    end

    context 'with simple top-level key' do
      let(:test_json_data) { { 'reportDate' => '2024-10-31', 'status' => 'complete', 'items' => [{ 'test' => 0 }] } }

      it 'extracts value for specified key' do
        result = described_class.extract_header(temp_file.path, key: 'reportDate')

        expect(result).to eq('2024-10-31')
      end
    end

    context 'with nested value' do
      let(:test_json_data) { { 'metadata' => { 'version' => '1.0', 'author' => 'system' }, 'data' => [] } }

      it 'extracts nested object' do
        result = described_class.extract_header(temp_file.path, key: 'metadata')

        expect(result).to eq({ 'version' => '1.0', 'author' => 'system' })
      end
    end

    context 'with array value' do
      let(:test_json_data) { { 'tags' => %w[tag1 tag2 tag3], 'name' => 'test' } }

      it 'extracts array value' do
        result = described_class.extract_header(temp_file.path, key: 'tags')

        expect(result).to eq(%w[tag1 tag2 tag3])
      end
    end

    context 'with non-existent key' do
      let(:test_json_data) { { 'name' => 'test', 'value' => 123 } }

      it 'returns nil' do
        result = described_class.extract_header(temp_file.path, key: 'missing')

        expect(result).to be_nil
      end
    end

    context 'with numeric value' do
      let(:test_json_data) { { 'count' => 42, 'name' => 'test' } }

      it 'extracts numeric value' do
        result = described_class.extract_header(temp_file.path, key: 'count')

        expect(result).to eq(42)
      end
    end

    context 'with deeply nested value' do
      let(:test_json_data) do
        {
          'reportSpecification' => {
            'reportType' => 'TEST',
            'reportOptions' => {
              'dateGranularity' => 'DAY',
              'filters' => { 'category' => 'electronics' },
            },
            'dataStartTime' => '2024-01-01',
          },
          'items' => [],
        }
      end

      it 'extracts deeply nested object structure' do
        result = described_class.extract_header(temp_file.path, key: 'reportSpecification')

        expect(result).to eq(test_json_data['reportSpecification'])
      end
    end

    context 'with nested array in extracted value' do
      let(:test_json_data) do
        {
          'config' => {
            'name' => 'Production',
            'marketplaceIds' => %w[A1F83G8C2ARO7P A13V1IB3VIYZZH],
            'settings' => {
              'timeout' => 30,
              'retries' => 3,
            },
          },
          'data' => [{ 'test' => 1 }],
        }
      end

      it 'extracts object with nested array and hash' do
        result = described_class.extract_header(temp_file.path, key: 'config')

        expect(result['name']).to eq('Production')
        expect(result['marketplaceIds']).to eq(%w[A1F83G8C2ARO7P A13V1IB3VIYZZH])
        expect(result['settings']).to eq({ 'timeout' => 30, 'retries' => 3 })
      end
    end
  end
end
