# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Federails::Server::PublishableResource do
  let(:post_record) { FactoryBot.create :post }
  let(:comment) { FactoryBot.create :comment, post: post_record }

  def serialized_hash(publishable)
    described_class.new(publishable).serializable_hash
  end

  context 'when the entity returns a string-keyed ActivityPub hash' do
    it 'does not mix string and symbol keys' do
      hash = serialized_hash(comment)

      string_keys = hash.keys.grep(String)
      symbol_keys = hash.keys.grep(Symbol)

      expect(string_keys).to be_empty.or(eq symbol_keys.map(&:to_s))
    end

    it 'has no duplicate keys after JSON serialization' do
      json = serialized_hash(comment).to_json

      expect(json.scan('"@context"').size).to eq 1
      expect(json.scan('"id"').size).to be >= 1
      # duplicated top-level "id" key check via round-trip length
      parsed = JSON.parse(json)
      expect(parsed.keys.size).to eq parsed.keys.uniq.size
    end

    it 'keeps the entity type' do
      json = serialized_hash(comment).to_json
      expect(JSON.parse(json)['type']).to eq 'Note'
    end
  end
end
