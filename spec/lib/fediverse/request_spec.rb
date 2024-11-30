require 'rails_helper'
require 'fediverse/request'

module Fediverse
  RSpec.describe Request do
    describe '#get' do
      context 'when request fails' do
        it 'returns nil' do
          VCR.use_cassette 'fediverse/request/get_get_404' do
            expect(described_class.get('http://example.com/something.json')).to be_nil
          end
        end
      end

      context 'when request is successful' do
        it 'returns a hash' do
          VCR.use_cassette 'fediverse/request/get_get_200' do
            expect(described_class.get('https://mamot.fr/users/mtancoigne')).to be_a Hash
          end
        end
      end
    end

    describe '.dereference' do
      context 'when value is a hash' do
        it 'returns the hash' do
          expect(described_class.dereference({})).to eq({})
        end
      end

      context 'when value is a string' do
        it 'returns a Hash' do
          VCR.use_cassette 'fediverse/request/get_get_200' do
            expect(described_class.dereference('https://mamot.fr/users/mtancoigne')).to be_a Hash
          end
        end
      end
    end
  end
end
