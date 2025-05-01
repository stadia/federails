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
      end
    end
  end
end
