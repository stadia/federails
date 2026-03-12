require 'rails_helper'

RSpec.describe Federails do
  describe '#logger' do
    let(:original_logger) { Federails::Configuration.logger }

    after do
      described_class.configure do |config|
        config.logger = original_logger
      end
    end

    it 'returns the configured logger' do
      custom_logger = Logger.new($stdout)

      described_class.configure do |config|
        config.logger = custom_logger
      end

      expect(described_class.logger).to be custom_logger
    end
  end

  describe '#data_entity_handlers_for' do
    it 'returns a list of configuration Hash' do
      result = described_class.data_entity_handlers_for 'CustomNote'

      aggregate_failures do
        expect(result).to be_a Array
        expect(result.first).to be_a Hash
      end
    end
  end

  describe '#data_entity_handled_on' do
    it 'returns a configuration Hash' do
      result = described_class.data_entity_handled_on :articles

      expect(result).to be_a Hash
    end
  end
end
