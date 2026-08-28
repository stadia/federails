# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fedipub::DataTransformer::Note do
  let(:entity) { FactoryBot.create :comment }

  describe '.to_federation' do
    it 'includes public addressing on the object itself' do
      hash = described_class.to_federation(entity, content: 'hello')

      expect(hash['to']).to eq [Fediverse::Collection::PUBLIC]
      expect(hash['cc']).to eq [entity.fedipub_actor.followers_url]
    end

    it 'allows overriding the addressing' do
      hash = described_class.to_federation(entity, content: 'hello', to: ['https://example.com/actors/1'], cc: [])

      expect(hash['to']).to eq ['https://example.com/actors/1']
      expect(hash['cc']).to eq []
    end
  end
end
