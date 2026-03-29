require 'rails_helper'
require 'fediverse/linked_data_signature'

RSpec.describe Fediverse::LinkedDataSignature do
  let(:keypair) { OpenSSL::PKey::RSA.generate(2048) }
  let(:actor) { FactoryBot.create(:user).federails_actor }

  let(:document) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => 'https://remote.example/users/alice/statuses/1',
      'type' => 'Create',
      'actor' => actor.federated_url,
      'object' => {
        'type' => 'Note',
        'content' => 'Hello world'
      }
    }
  end

  before do
    actor.update_columns(public_key: keypair.public_key.to_pem, private_key: keypair.to_pem)
    # Stub normalize to avoid JSON-LD remote context fetching issues in tests
    allow(described_class).to receive(:normalize).and_wrap_original do |_method, document|
      document.to_json
    end
  end

  def sign_document(doc)
    options = {
      'creator' => "#{actor.federated_url}#main-key",
      'created' => Time.now.utc.iso8601
    }
    options_hash = described_class.send(:hash_options, options)
    document_hash = described_class.send(:hash_document, doc)
    to_sign = options_hash + document_hash
    signature_value = Base64.strict_encode64(keypair.sign(OpenSSL::Digest.new('SHA256'), to_sign))

    doc.merge('signature' => options.merge('type' => 'RsaSignature2017', 'signatureValue' => signature_value))
  end

  describe '.verify' do
    context 'with a valid signature' do
      it 'returns verified true with the actor' do
        signed = sign_document(document)
        allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(actor)

        result = described_class.verify(signed)

        expect(result[:verified]).to be true
        expect(result[:actor]).to eq(actor)
      end
    end

    context 'with a tampered document' do
      it 'returns verified false' do
        signed = sign_document(document)
        signed['object']['content'] = 'Tampered!'
        allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(actor)

        result = described_class.verify(signed)

        expect(result[:verified]).to be false
      end
    end

    context 'with no signature block' do
      it 'returns nil' do
        result = described_class.verify(document)

        expect(result).to be_nil
      end
    end

    context 'with no creator in signature' do
      it 'returns verified false with error' do
        doc = document.merge('signature' => { 'signatureValue' => 'abc' })

        result = described_class.verify(doc)

        expect(result[:verified]).to be false
        expect(result[:error]).to eq('No creator in signature')
      end
    end

    context 'when actor cannot be resolved' do
      it 'returns verified false with error' do
        signed = sign_document(document)
        allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(nil)

        result = described_class.verify(signed)

        expect(result[:verified]).to be false
        expect(result[:error]).to eq('Could not resolve signing actor')
      end
    end
  end
end
