require 'rails_helper'

RSpec.describe Fedipub::Utils::JsonRequest do
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

    it 'signs the request if a sender is specified' do # rubocop:todo RSpec/ExampleLength
      sender = FactoryBot.create(:user).fedipub_actor
      allow(Fediverse::Signature::Rfc9421).to receive(:sign).and_call_original
      VCR.use_cassette 'fediverse/request/get_actor_200' do
        described_class.get_json('https://mamot.fr/users/mtancoigne', from: sender)
      end
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
    end
  end

  describe '#post' do
    let(:local_actor) { FactoryBot.create(:user).fedipub_actor }
    let(:faraday) { instance_double(Faraday::Connection) }
    let(:builder) { instance_double(Faraday::RackBuilder) }
    let(:response) { instance_double(Faraday::Response) }

    before do
      allow(described_class.instance).to receive(:connection).and_return(faraday)
      allow(faraday).to receive(:builder).and_return(builder)
      allow(faraday).to receive(:build_request)
      allow(builder).to receive(:build_response).and_return(response)
      allow(Fediverse::Signature::Rfc9421).to receive(:sign)
      allow(Fediverse::Signature::DraftCavage12).to receive(:sign)
    end

    it 'tries RFC9421 signing first' do # rubocop:disable RSpec/MultipleExpectations
      allow(response).to receive(:status).and_return(201)
      described_class.post(url: 'https://example.com', message: '{}', from: local_actor)
      expect(builder).to have_received(:build_response).once
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
      expect(Fediverse::Signature::DraftCavage12).not_to have_received(:sign)
    end

    it 'tries draft-cavage-12 signing if RFC9421 attempt returns a 400' do # rubocop:disable RSpec/MultipleExpectations
      allow(response).to receive(:status).and_return(400)
      described_class.post(url: 'https://example.com', message: '{}', from: local_actor)
      expect(builder).to have_received(:build_response).twice
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
      expect(Fediverse::Signature::DraftCavage12).to have_received(:sign).once
    end

    it 'tries draft-cavage-12 signing if RFC9421 attempt returns a 401' do # rubocop:disable RSpec/MultipleExpectations
      allow(response).to receive(:status).and_return(401)
      described_class.post(url: 'https://example.com', message: '{}', from: local_actor)
      expect(builder).to have_received(:build_response).twice
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
      expect(Fediverse::Signature::DraftCavage12).to have_received(:sign).once
    end
  end

  describe '#build_request' do
    context 'when POSTing' do
      let(:request) { described_class.instance.send :build_request, method: :post, url: 'https://fedipub.dev/inbox', message: 'test' }

      it 'sets correct method' do
        expect(request.http_method).to eq :post
      end

      it 'sets correct URL' do
        # Faraday::Request#path is badly named, it's the full URL without query params
        expect(request.path).to eq 'https://fedipub.dev/inbox'
      end

      it 'sends correct activitypub content type' do
        expect(request.headers['Content-Type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
      end

      it 'accepts correct activitypub content type' do
        expect(request.headers['Accept']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams", application/activity+json, application/json;q=0.5'
      end
    end

    context 'when providing extra headers' do
      let(:request) do
        described_class.instance.send :build_request, method: :post, url: 'https://fedipub.dev/inbox', message: 'test', headers: {
          'X-Clacks-Overhead' => 'GNU Terry Pratchett',
          'Content-Type'      => 'text/plain',
          'Accept'            => 'text/html',
        }
      end

      it 'adds arbitrary headers' do
        expect(request.headers['X-Clacks-Overhead']).to eq 'GNU Terry Pratchett'
      end

      it 'overrides accept' do
        expect(request.headers['Accept']).to eq 'text/html'
      end

      it 'overrides content type' do
        expect(request.headers['Content-Type']).to eq 'text/plain'
      end
    end

    context 'when providing query params' do
      let(:request) { described_class.instance.send :build_request, method: :get, url: 'https://fedipub.dev/inbox', params: { 'q' => 'test' } }

      it 'adds params to request' do
        expect(request.params['q']).to eq 'test'
      end
    end
  end
end
