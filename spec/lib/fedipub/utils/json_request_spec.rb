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
  end

  describe '#post' do
    let(:local_actor) { FactoryBot.create(:user).fedipub_actor }
    let(:faraday) { instance_double(Faraday::Connection) }
    let(:builder) { instance_double(Faraday::RackBuilder) }
    let(:response) { instance_double(Faraday::Response) }

    before do
      allow(faraday).to receive(:builder).and_return(builder)
      allow(builder).to receive(:build_response).and_return(response)
      allow(Fediverse::Signature::Rfc9421).to receive(:sign)
      allow(Fediverse::Signature::DraftCavage12).to receive(:sign)
    end

    it 'tries RFC9421 signing first' do # rubocop:disable RSpec/MultipleExpectations
      allow(response).to receive(:status).and_return(201)
      described_class.post(url: 'https://example.com', message: '{}', from: local_actor, connection: faraday)
      expect(builder).to have_received(:build_response).once
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
      expect(Fediverse::Signature::DraftCavage12).not_to have_received(:sign)
    end

    it 'tries draft-cavage-12 signing if RFC9421 attempt returns a 400' do # rubocop:disable RSpec/MultipleExpectations
      allow(response).to receive(:status).and_return(400)
      described_class.post(url: 'https://example.com', message: '{}', from: local_actor, connection: faraday)
      expect(builder).to have_received(:build_response).twice
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
      expect(Fediverse::Signature::DraftCavage12).to have_received(:sign).once
    end

    it 'tries draft-cavage-12 signing if RFC9421 attempt returns a 401' do # rubocop:disable RSpec/MultipleExpectations
      allow(response).to receive(:status).and_return(401)
      described_class.post(url: 'https://example.com', message: '{}', from: local_actor, connection: faraday)
      expect(builder).to have_received(:build_response).twice
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).once
      expect(Fediverse::Signature::DraftCavage12).to have_received(:sign).once
    end
  end

  describe '#signed_request' do
    let(:local_actor) { FactoryBot.create(:user).fedipub_actor }
    let(:distant_target_actor) { FactoryBot.create :distant_actor }
    let(:request) do
      described_class.send :signed_request,
                           url:     distant_target_actor.inbox_url,
                           from:    local_actor,
                           message: 'test'
    end

    it 'posts to inbox URL' do
      # Faraday::Request#path is badly named, it's the full URL without query params
      expect(request.path).to eq distant_target_actor.inbox_url
    end

    it 'sends correct activitypub content type' do
      expect(request.headers['Content-Type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
    end

    it 'accepts correct activitypub content type' do
      expect(request.headers['Accept']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams", application/activity+json, application/json;q=0.5'
    end
  end
end
