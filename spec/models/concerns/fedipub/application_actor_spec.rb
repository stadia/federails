require 'rails_helper'

module Fedipub
  RSpec.describe Actor, type: :model do
    it 'is created automatically on demand' do
      expect { described_class.application_actor }.to change(described_class, :count).by(1)
    end

    it 'is not recreated if already exists' do
      described_class.application_actor
      expect { described_class.application_actor }.not_to change(described_class, :count)
    end

    it 'has its own keypair' do
      expect(described_class.application_actor.public_key).to be_present
    end

    it 'has a valid federated url' do
      expect(described_class.application_actor.federated_url).to match(%r{http://localhost/federation/actors/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}})
    end
  end
end
