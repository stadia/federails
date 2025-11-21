require 'rails_helper'

module Federails
  RSpec.describe Activity, type: :model do
    let(:alice) { FactoryBot.create :local_actor }
    let(:bob) { FactoryBot.create :local_actor }

    context 'when using default addressing' do
      it 'has public collection in to: field' do
        activity = described_class.create(actor: alice, entity: alice, action: 'Create')
        expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
      end

      it 'has actor followers collection in cc: field' do
        activity = described_class.create(actor: alice, entity: alice, action: 'Create')
        expect(activity.cc).to include alice.followers_url
      end

      it 'has entity followers collection in cc: field if it has one' do
        activity = described_class.create(actor: alice, entity: bob, action: 'Create')
        expect(activity.cc).to include bob.followers_url
      end
    end

    [:to, :cc].each do |attr|
      describe "serializing #{attr} field" do
        let(:addresses) { ['https://example.com/@abc123', 'https://example.social/@def456'] }
        let(:activity) { described_class.create!(:actor => alice, :entity => bob, :action => 'Create', attr => addresses) }

        it 'serializes and deserializes multiple addresses correctly' do
          a = described_class.find(activity.id)
          expect(a.send(attr)).to eq addresses
        end
      end
    end

    describe 'delivery' do
      context 'when activity creator is distant' do
        let(:distant_actor) { FactoryBot.create :distant_actor }

        it 'does not notify actor' do
          activity = described_class.new actor: distant_actor
          expect(activity.recipients).to eq []
        end
      end
    end
  end
end
