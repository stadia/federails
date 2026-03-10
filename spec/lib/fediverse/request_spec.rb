require 'rails_helper'
require 'fediverse/request'

module Fediverse
  RSpec.describe Request do
    describe '.dereference' do
      context 'when value is a hash' do
        it 'returns the hash' do
          expect(described_class.dereference({})).to eq({})
        end
      end

      context 'when value is a string' do
        it 'returns a Hash' do
          VCR.use_cassette 'fediverse/request/get_actor_200' do
            expect(described_class.dereference('https://mamot.fr/users/mtancoigne')).to be_a Hash
          end
        end

        it 'falls back to the original JSON when JSON-LD compaction fails' do
          json = {
            '@context' => 'https://www.w3.org/ns/activitystreams',
            'id'       => 'https://example.com/actors/1',
            'type'     => 'Person',
          }
          allow(Federails::Utils::JsonRequest).to receive(:get_json).and_return(json)
          allow(JSON::LD::API).to receive(:compact).and_raise(
            JSON::LD::JsonLdError::ProtectedTermRedefinition,
            'protected term redefinition'
          )

          expect(described_class.dereference('https://example.com/actors/1')).to eq(json)
        end
      end
    end
  end
end
