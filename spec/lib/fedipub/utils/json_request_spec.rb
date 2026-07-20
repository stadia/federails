require 'rails_helper'

RSpec.describe Federails::Utils::JsonRequest do
  describe '.get_json' do
    context 'when status code is unexpected' do
      it 'raises an error' do
        VCR.use_cassette 'fediverse/request/get_404' do
          expect { described_class.get_json('http://example.com/something.json') }.to raise_error described_class::UnhandledResponseStatus
        end
      end
    end

    context 'when request is successful' do
      it 'returns a hash' do
        VCR.use_cassette 'fediverse/request/get_actor_200' do
          expect(described_class.get_json('https://mamot.fr/users/mtancoigne')).to be_a Hash
        end
      end
    end
  end
end
