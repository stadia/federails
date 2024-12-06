require 'rails_helper'

RSpec.describe Federails do
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
